# AWS and Terraform
This consists of a single Terraform module that will provision everything needed for Outline itself that would normally be considered "shared" infrastructure (A VPC, RDS, Redis, etc) as well as all any multi application hosting options like ECS/EKS.

The root config will contain instantiations of this module to create any number of environments. 

This folder also contains a script called `setup_new_environment` that needs to be run after a new "A Cloud Guru" sandbox is created. It will provision the necessary S3 bucket and DynamoDB tables for Terraform state storage.