# tf-aws-playground
This repository contains terraform code for creating an infrastructure according to [requirement.pdf](https://github.com/tudoricc/tf-aws-playground/blob/main/requirement.pdf)

## Requirements:

<details>
<summary>Requirements</summary>
- Terraform: [download page](https://developer.hashicorp.com/terraform/downloads)
- Access to an AWS Account
- Admin User
- Remote State (TBA)
</details>

## Layout decision breakdown

Each component is broken down in a separate module,rather than having a single TF module where you have all the logic for creating everything I broke it down in multiple modules,each containing  the following files: 
- main.tf - the file that creates all the resources
- provider.tf - the provider file
- var/eu-west-1.tfvars (the region variables file where I am creating that resource)

<details>
<summary>TLDR</summary>
Why break everything when you can break only 1 component?
</details>


## Repository Overview
<details>
<summary>Repository Structure</summary>

```text
.
├── bastion
│   ├── bastion-created.png
│   ├── main.tf
│   ├── provider.tf
│   ├── temp-key
│   ├── temp-key.pub
│   └── vars
│       └── eu-west-1.tfvars
├── compute
│   ├── main.tf
│   ├── provider.tf
│   ├── ssh-to-comptue.png
│   ├── temp-key
│   ├── temp-key.pub
│   └── vars
│       └── eu-west-1.tfvars
├── database
│   ├── aurora-cluster.png
│   ├── main.tf
│   ├── provider.tf
│   └── vars
│       └── eu-west-1.tfvars
├── README.md
├── requirement.pdf
├── sg
│   ├── main.tf
│   └── vars
│       └── eu-west-1.tfvars
└── vpc
    ├── main.tf
    ├── provider.tf
    └── vars
        └── eu-west-1.tfvars

```
</details>


## Breakdown of modules
The terraform modules can be run in a random order as long as the core modules are first run.

Core modules represent the backbone on which all the other resources are deployed on:
- vpc - you need a network where you create all the other resources
- sg - you need security groups to attach to the instances and elb you create


As a rule of thumb: as long as you have a vpc the other modules do not rely on eachother and are created in the previously mentioned vpc


### vpc 
Creates the Network layout to be used in this exercise and prints to outputs variables that are used along the exercise

### sg 
Creates the Security groups and the rules to be used for the compute hosts/ELB/Bastion

### bastion
Creates the bastion host: the entry host for the network

### compute
Creates the EC2 instances and attaches it to a new ELB

### database
Creates an aurora serverless cluster that can be used by the compute servers



## How to run any module
```
#go in the directory of module you want to run
cd <<MODULE-DIRECTORY>>

#download submodules and initializes the tf part
terraform init
# Check to see what would happen,
terraform plan --var-file="./vars/<cluster>.tfvars"
# Create resources
terraform apply --var-file="./vars/<cluster>.tfvars"

```