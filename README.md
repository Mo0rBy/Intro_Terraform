# Terraform
## What is Terraform?
Terraform is an infrastructure as code (IaC) tool that allows you to build, change, and version infrastructure safely and efficiently. This includes low-level components such as compute instances, storage, and networking, as well as high-level components such as DNS entries, SaaS features, etc. Terraform can manage both existing service providers and custom in-house solutions. *(Taken from HashiCorp website)*

---
- Create env var to secure AWS keys
- Restart terminal
- Create a file called main.tf
- Add the code to initialise terraform with provider AWS

```
provider "aws" {
    region = "eu-west-1"

}
```
- Let's run this code with `terraform init`

## Creating resources on AWS
- Let's start with launching and EC2 instance using the app AMI
- AMI ID > ``
- `sre_key.pem` file
- AWS keys set is already done *(environment variables)*
- public ip
- Type of the instance > `t2.micro`

---

Terraform commands:
`terraform init`
`terraform plan`
`terraform apply`

---
This `main.tf` has the image ID and other options hard-coded:

```
# Let's set up our cloud provider with Terraform

provider "aws" {
    region = "eu-west-1"
}

## Let's launch an EC2 instance using the app AMI
# Need to define all the information required to launch the instance
resource "aws_instance" "app_instance" {
    ami = "ami-04f364e11ef840257"
    instance_type ="t2.micro"
    associate_public_ip_address = true
    tags = {
        Name = "sre_will_terraform_app"
    }
}
```

---
### Full `main.tf` script
```
# # Let's set up our cloud provider with Terraform

provider "aws" {
    region = "eu-west-1"
}

######################
# Step 1 - Create a VPC with CIDR block
# Step 2 - Run terraform plan then terraform apply
# Step 3 - Get teh VPC ID from AWS or terraform logs, add the ID to the variable.terraform


######################

# Create a VPC

resource "aws_vpc" "sre_will_vpc_tf" {
    cidr_block = var.vpc_CIDR_block
    instance_tenancy = "default"

    tags = {
        Name = "sre_will_vpc_tf"
    }
}

# vpc_id created >> [id=vpc-0ead78dc96892a665]

# Create an Internet Gateway

resource "aws_internet_gateway" "sre_will_IG" {
    vpc_id = var.vpc_id

    tags = {
        Name = "sre_will_IG_tf"
    }
}

# Create a subnet

resource "aws_subnet" "sre_will_subnet_tf" {
    vpc_id = var.vpc_id
    cidr_block = var.subnet_CIDR_block
    map_public_ip_on_launch = true

    tags = {
        Name = "sre_will_subnet_tf"
    }
}

# Edit security group rules

resource "aws_security_group" "sre_will_app_group" {
    name = "sre_will_app_sg_tf"
    description = "sre_will_app_sg_tf"
    vpc_id = var.vpc_id

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
        cidr_blocks = [var.public_CIDR_block]
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

resource "aws_route" "r" {
    route_table_id = var.route_table_id
    destination_cidr_block = var.public_CIDR_block
    gateway_id = var.internet_gateway_id
}

## Let's launch an EC2 instance using the app AMI
# Need to define all the information required to launch the instance
resource "aws_instance" "app_instance" {
    ami = var.ami_id
    instance_type ="t2.micro"
    associate_public_ip_address = true
    vpc_security_group_ids = [
        var.app_security_group_id
    ]
    subnet_id = var.subnet_id

    tags = {
        Name = "sre_will_terraform_app"
    }

    key_name = var.aws_key_name

    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = var.aws_key_path
        host = "${self.associate_public_ip_address}"
    }

    provisioner "remote-exec" {
        inline = [
            "cd app",
            "pm2 kill",
            "pm2 start app.js"
        ]
    }
}
```