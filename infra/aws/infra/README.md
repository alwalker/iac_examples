# AWS and Terraform

This consists of a single Terraform module that will provision everything needed for Outline itself that would normally be considered "shared" infrastructure (A VPC, RDS, Redis, etc) as well as all any multi application hosting options like ECS/EKS.

The root config will contain instantiations of this module to create any number of environments.

# To EKS or not EKS

There is a local variable in the base root config called `enable_eks` that you can use to control whether or not to create an EKS cluster, all of its additional networking resources, and how the ALB is configured. If you chose to create an EKS cluster you will also want to apply the corresponding root config for that environments add ons. This will install external-dns, cluster autoscaler, metrics server, and the load balancer controller. These are in a separate root config because Terraform doesn't handle providers very well when their inputs are created in the same root config that they are used in.