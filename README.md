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
