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