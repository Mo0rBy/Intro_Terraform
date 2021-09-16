# Let's set up our cloud provider with Terraform

provider "aws" {
    region = "eu-west-1"
}

# Create a VPC

resource "aws_vpc" "sre_will_vpc_tf" {
    cidr_block = var.vpc_CIDR_block
    instance_tenancy = "default"

    tags = {
        Name = "sre_will_vpc_tf"
    }
}

# Create an Internet Gateway

resource "aws_internet_gateway" "sre_will_IG" {
    vpc_id = aws_vpc.sre_will_vpc_tf.id

    tags = {
        Name = "sre_will_IG_tf"
    }
}

# Create a public subnet (for app instance)

resource "aws_subnet" "sre_will_public_subnet_tf" {
    vpc_id = aws_vpc.sre_will_vpc_tf.id
    cidr_block = var.public_subnet_CIDR_block
    map_public_ip_on_launch = true

    tags = {
        Name = "sre_will_public_subnet_tf"
    }
}

# Create security group for app instance

resource "aws_security_group" "sre_will_app_group" {
    name = "sre_will_app_sg_tf"
    description = "sre_will_app_sg_tf"
    vpc_id = aws_vpc.sre_will_vpc_tf.id

    # HTTP port, global access
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = [var.public_CIDR_block]
    }

    # SSH port, (set to 0.0.0.0/0 for global access)
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.private_ip]
    }

    # Port 3000 for reverse proxy
    ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = [var.public_CIDR_block]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [var.public_CIDR_block]
    }

    tags = {
        Name = "sre_will_app_sg_tf"
    }
}

# Edit the route table (thats created with the VPC)
## Adding the route to the internet gateway

resource "aws_route" "sre_will_route_table" {
    route_table_id = aws_vpc.sre_will_vpc_tf.default_route_table_id
    destination_cidr_block = var.public_CIDR_block
    gateway_id = aws_internet_gateway.sre_will_IG.id

}

# Let's launch an EC2 instance using the app AMI
## Need to define all the information required to launch the instance

resource "aws_instance" "app_instance" {
    ami = var.app_ami_id
    instance_type ="t2.micro"
    associate_public_ip_address = true
    vpc_security_group_ids = [
        aws_security_group.sre_will_app_group.id
    ]
    subnet_id = aws_subnet.sre_will_public_subnet_tf.id

    tags = {
        Name = "sre_will_terraform_app"
    }

    key_name = var.aws_key_name

    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = file(var.aws_key_path)
        host = aws_instance.app_instance.public_ip
    }

    provisioner "remote-exec" {
        inline = [
            "sudo mkdir testdir"
        ]
    }
}

# Create private subnet (for db instance)

resource "aws_subnet" "sre_will_private_subnet_tf" {
    vpc_id = aws_vpc.sre_will_vpc_tf.id
    cidr_block = var.private_subnet_CIDR_block
    map_public_ip_on_launch = true
    tags = {
        Name = "sre_will_private_subnet_tf"
    }
}

# Create security group for db instance

resource "aws_security_group" "sre_will_db_group" {
    name = "sre_will_db_sg_tf"
    description = "sre_will_db_sg_tf"
    vpc_id = aws_vpc.sre_will_vpc_tf.id

    # SSH port
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.private_ip]
    }

    # Port 27017 for DB
    ingress {
        from_port = 27017
        to_port = 27017
        protocol = "tcp"
        cidr_blocks = ["${aws_instance.app_instance.public_ip}/32"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [var.public_CIDR_block]
    }

    tags = {
        Name = "sre_will_db_sg_tf"
    }
}

resource "aws_instance" "db_instance" {
    ami = var.db_ami_id
    instance_type = "t2.micro"
    associate_public_ip_address = false
    vpc_security_group_ids = [
        aws_security_group.sre_will_db_group.id
    ]
    subnet_id = aws_subnet.sre_will_private_subnet_tf.id

    tags = {
        Name = "sre_will_terraform_db"
    }

    key_name = var.aws_key_name

    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = var.aws_key_path
        host = aws_instance.db_instance.public_ip
    }
}


## Need to finish configuring the db instance
## How to SSH into instance subnet is private and instance has no public IP??
## Does "connection" section of instance definition still work??


## Was getting infinite loop on SSH connection for app instance
## Error was >>

## interrupted - last error: dial tcp: lookup true: no such host

## Changed host variable in connection{}
## >> host = aws_instance.app_instance.public_ip

## New error for provisioner "remote-exec" {} >>

## aws_instance.app_instance (remote-exec): sudo: unable to resolve host ip-10-105-1-151

## Either enableDnsHostname in VPC configuration
## https://stackoverflow.com/questions/33441873/aws-error-sudo-unable-to-resolve-host-ip-10-0-xx-xx
## Or add dns hostname to /etc/hosts
## https://stackoverflow.com/questions/37517630/aws-linux-sudo-unable-to-resolve-host