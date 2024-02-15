#variables that will be imported for each region/cluster
variable "region_aws" {}

variable "environment" {}
data "aws_availability_zones" "available" {}
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
  #Because we don't want this hardcoded we are retrieving hte VPC id from the remote state of the vpc module
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  #azs  = data.terraform_remote_state.vpc.outputs.az-available
  #We are retrieving the private db subnnets id from the remote state of the vpc moodule
  db_subnets = data.terraform_remote_state.vpc.outputs.db_subnets_ids
  db_sg_id = data.terraform_remote_state.sg.outputs.db_sg_id

  #iam role

  aurora-cluster-name = "fortis-aurora-${var.region_aws}-${var.environment}"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}


################################################################################
# RDS Aurora Module
################################################################################
resource "random_password" "master" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
#because I am cheap and I don't want extra costs  using servlerless so if it's not used we don't pay
module "aurora_postgresql" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name              = "${local.aurora-cluster-name}-postgresql"
  engine            = "aurora-mysql"
  engine_mode       = "serverless"
  storage_encrypted = true
  master_username   = "root"
  #port = 3306
  vpc_id               = local.vpc_id
  db_subnet_group_name = local.db_subnets

  #adding where we allow access from - let's keep it like this for now and later we can change it to the remtoe state output for comptue_subnets
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = ["10.0.0.0/16"]
    }
  }
  #security_group_name = local.db_sg_id
  manage_master_user_password = false
  master_password             = random_password.master.result

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  # enabled_cloudwatch_logs_exports = # NOT SUPPORTED

  scaling_configuration = {
    auto_pause               = true
    min_capacity             = 2
    max_capacity             = 16
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }


}



###########################
# Outputs
###########################

output "aurora_cluster" {
  value = module.aurora_postgresql.cluster_endpoint
}
