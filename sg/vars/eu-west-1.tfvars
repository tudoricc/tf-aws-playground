region_aws = "eu-west-1"

#Below we will define the private subnets that we will use
#For now we will only create a single "compute" subnet
compute_subnets =  ["10.0.1.0/24"]
#same applies for the sql subnet
db_subnets = ["10.0.10.0/24"]

azs = ["eu-west-1a","eu-west-1b","eu-west-1c"]
environment = "dev"
public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]