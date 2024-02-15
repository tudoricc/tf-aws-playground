#variables that will be imported for each region/cluster
variable "region_aws" {}

variable "environment" {}



variable "PRIVATE_KEY" {
  default = "temp-key"
}

variable "PUBLIC_KEY" {
  default = "temp-key.pub"
}
variable "AMIS" {
  type = map(string)
  default = {
    us-east-1 = "ami-13be557e"
    us-west-2 = "ami-06b94666"
    eu-west-1 = "ami-844e0bf7"
  }
}


# Configure the AWS Provider
provider "aws" {
  region = var.region_aws
}
# we created the vpc in another tf module so we can use the data from the remote state here rather than hardcoding it
data "terraform_remote_state" "vpc" {
  backend = "local"

 config = {
    path = "${path.module}/../vpc/terraform.tfstate"
  }
}

#let's refference the tfstate for the SG create previously
data "terraform_remote_state" "sg" {
  backend = "local"

 config = {
    path = "${path.module}/../sg/terraform.tfstate"
  }
}
#module variables
locals {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  compute_subnets_ids = data.terraform_remote_state.vpc.outputs.compute_subnets_ids
  public_subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  sg_id_compute = data.terraform_remote_state.sg.outputs.compute_sg_id
  sg_id_lb = data.terraform_remote_state.sg.outputs.lb_sg_id
}


#create keypair - we'll use the same one as before
#create the keypair to be used on the bastion host
resource "aws_key_pair" "mykeypair" {
  key_name   = "temp-compute-key"
  public_key = file(var.PUBLIC_KEY)
}

#for the sake of this exercise let's create a single ec2 instance,
#we can look at creating an ASG with this module: https://github.com/terraform-aws-modules/terraform-aws-autoscaling
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "fortis-compute-instance-${var.region_aws}-${var.environment}"

  instance_type          = "t2.micro"
  key_name               = aws_key_pair.mykeypair.key_name
  monitoring             = true
  vpc_security_group_ids = [local.sg_id_compute]
  subnet_id              = local.compute_subnets_ids[1]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


#and now the ELB:
module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 2.0"

  name = "fortis-elb-${var.region_aws}-${var.environment}"

  subnets         = local.public_subnets
  security_groups = [local.sg_id_lb]
  internal        = false
  #in order for 443 to work you will need an ssl certificate created. 
  # as this is a testing exercise I will use another port to not have to add aditional charges to my acc
  listener = [
    {
      instance_port     = 8080
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    }
  ]

  health_check = {
    target              = "HTTP:8080/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }



  // ELB attachments
  number_of_instances = 2
  instances           = [module.ec2_instance.id]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

###########################
# Outputs
###########################

output "compute_hots_private_dns" {
  value = module.ec2_instance.private_dns  
}
output "lb_dns_public"{
  value = module.elb_http.this_elb_dns_name
}
