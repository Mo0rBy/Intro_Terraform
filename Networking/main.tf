# Let's set up our cloud provider with Terraform

provider "aws" {
    region = "eu-west-1"
}

# Create a VPC

resource "aws_vpc" "sre_will_vpc_tf" {
    cidr_block = var.vpc_CIDR_block
    instance_tenancy = "default"
    enable_dns_hostnames = true

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

    ###
    availability_zone_id = "euw1-az1" # Needed for load-balancing task
    # Requires at least 2 subnets on different availability zones
    ###

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

    ## Old provisioner went here

}

# Create private subnet (for db instance)

resource "aws_subnet" "sre_will_private_subnet_tf" {
    vpc_id = aws_vpc.sre_will_vpc_tf.id
    cidr_block = var.private_subnet_CIDR_block
    map_public_ip_on_launch = true

    ###
    availability_zone_id = "euw1-az2" # Needed for load-balancing task
    # Requires at least 2 subnets on different availability zones
    ###

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
    associate_public_ip_address = true
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

#########################


# resource "null_resource" "app_provision" {
#     triggers = {
#         instance_ids = [
#             "${aws_instance.app_instance.id}"
#         ]
#     }

#     connection {
#         type = "ssh"
#         user = "ubuntu"
#         private_key = file(var.aws_key_path)
#         host = aws_instance.app_instance.public_ip
#     }

#     provisioner "remote-exec" {
#         inline = [
#             "sudo sed '/DB_HOST/c DB_HOST=mongodb://${aws_instance.db_instance.public_ip}:27017/posts",
#             "sudo pm2 kill",
#             "cd app",
#             "npm install",
#             "node seed/seeds.js",
#             "pm2 start app.js"
#         ]
#     }
# }

### Sharukh says that configuration management is usually done on Ansible
### Using ANsible to configure the instances is better than doing these shell commands in Terraform

########//Load Balancing + Auto Scaling\\########

# Create a launch template

resource "aws_launch_template" "app_template" {
    name = "sre_will_app_launch_template"
    image_id = var.app_ami_id
    instance_type ="t2.micro"
    vpc_security_group_ids = [
        aws_security_group.sre_will_app_group.id
    ]

    key_name = var.aws_key_name
}

# Create a lunch configuration

resource "aws_launch_configuration" "app_launch_configuration" {
    name = "sre_will_app_launch_configuration"
    image_id = var.app_ami_id
    instance_type = "t2.micro"
}

# Create an application load balancer

resource "aws_lb" "sre_will_LB_tf" {
    name = "sre-will-LB-tf"
    internal = false
    load_balancer_type = "application"
    subnets = [
        aws_subnet.sre_will_public_subnet_tf.id,
        aws_subnet.sre_will_private_subnet_tf.id
    ]
    # security_groups = # What SG do you use??

    tags = {
        Name = "sre_will_loadbalancer_tf"
    }
}

# Create an instance target group

resource "aws_lb_target_group" "sre_will_app_TG_tf" {
    name = "sre-will-app-TG-tf"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.sre_will_vpc_tf.id
    # target_type = instance (by default)

    tags = {
        Name = "sre_will_targetgroup_tf"
    }
}

# Create a listener

resource "aws_lb_listener" "sre_will_listener" {
    load_balancer_arn = aws_lb.sre_will_LB_tf.arn
    port = 80
    protocol = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.sre_will_app_TG_tf.arn
    }
}

resource "aws_lb_target_group_attachment" "sre_will_app_TG_attachment" {
    target_group_arn = aws_lb_target_group.sre_will_app_TG_tf.arn
    target_id = aws_instance.app_instance.id
    port = 80
}

# Create an Auto Scaling group (from launch template)

# resource "aws_autoscaling_group" "sre_will_ASG_tf" {
#     name = "sre_will_app_ASG_tf"

#     min_size = 1
#     desired_capacity = 1
#     max_size = 3

#     availability_zones = [
#         aws_subnet.sre_will_public_subnet_tf.availability_zone_id,
#         aws_subnet.sre_will_private_subnet_tf.availability_zone_id
#     ]

#     launch_template {
#         id = aws_launch_template.app_template.id
#         version = "$Latest"
#     }
# }

# Create an Auto Scaling group (from launch configuration)

resource "aws_autoscaling_group" "sre_will_ASG_tf" {
    name = "sre_will_ASF_tf"

    min_size = 1
    desired_capacity = 1
    max_size = 3

    vpc_zone_identifier = [
        aws_subnet.sre_will_public_subnet_tf.id,
        aws_subnet.sre_will_private_subnet_tf.id
    ]

    launch_configuration = aws_launch_configuration.app_launch_configuration.name
}

resource "aws_autoscaling_policy" "app_ASG_policy" {
    name = "sre_will_app_ASG_policy"
    policy_type = "TargetTrackingScaling"
    estimated_instance_warmup = 100
    # Use "cooldown" or "estimated_instance_warmup"
    # Error: cooldown is only used by "SimpleScaling"
    autoscaling_group_name = aws_autoscaling_group.sre_will_ASG_tf.name

    target_tracking_configuration {
        predefined_metric_specification {
            predefined_metric_type = "ASGAverageCPUUtilization"
            # Need to make sure to use valid options here
            # Think the syntax is
            ## ASG for auto scaling group metrics, ALB for load balancing metrics
            ## Name of metric with no spaces
        }
        target_value = 50.0
    }
}