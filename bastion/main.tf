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
  public_subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  sg_id_bastion = data.terraform_remote_state.sg.outputs.bastion_sg_id
}



#create the keypair to be used on the bastion host
resource "aws_key_pair" "mykeypair" {
  key_name   = "temp-key"
  public_key = file(var.PUBLIC_KEY)
}

resource "aws_instance" "bastion" {
  ami           = var.AMIS[var.region_aws]
  instance_type = "t2.micro"
  subnet_id     = local.public_subnets[1]
  vpc_security_group_ids = [local.sg_id_bastion]
  associate_public_ip_address = true
  #use the previously created keypair
  key_name = aws_key_pair.mykeypair.key_name
  tags = {
    Name = "fortis-bastion-${var.region_aws}-${var.environment}"
  }
}


###########################
# Outputs
###########################

output "bastion_host_public_ip" {
  value = aws_instance.bastion.public_ip  
}

output "bastion_host_dns" {
  value = aws_instance.bastion.public_dns  
}
