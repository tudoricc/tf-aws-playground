#variables that will be imported for each region/cluster
variable "region_aws" {}
variable "compute_subnets" {}

variable "environment" {}
variable "public_subnets" {}
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
#module variables
locals {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  compute_subnets = data.terraform_remote_state.vpc.outputs.compute_subnets_ids
  public_subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  default_sg_id = data.terraform_remote_state.vpc.outputs.default_sg_id
}

#let's only add a single public IP to allow traffic on to the ELB
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}



#we can wrap this in a module but leaving it like this for now
resource "aws_security_group" "lb" {
  name        = "fortis-elb-security-group-${var.environment}"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 8080
    #now add the CIDR blocks allowed to only be our public IP
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bastion" {
  name        = "fortis-bastion-security-group-${var.environment}"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    #now add the CIDR blocks allowed to only be our public IP
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "compute" {
  name        = "fortis-compute-security-group-${var.environment}"
  vpc_id      = local.vpc_id
  description = "security group for private that allows ssh and all egress traffic"
 

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    security_groups =  [ aws_security_group.bastion.id ]

  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database" {
  name        = "fortis-db-security-group-${var.environment}"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    security_groups =  [ aws_security_group.compute.id ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



###########################
# Outputs
###########################

output "db_sg_id" {
  value = aws_security_group.database.id
}

output "lb_sg_id" {
  value = aws_security_group.lb.id
}

output "compute_sg_id" {
  value = aws_security_group.compute.id
}
output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}