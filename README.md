# IaC Examples

## What This Is
This is a collection of examples using both different tech stacks as well as infrastructure providers to host [Outline.js](https://github.com/outline/outline). I chose Outline because it was a complex enough application that building it wasn't super trivial and it has several external dependencies (Redis, S3 compatible storage, PostgreSQL, and an OIDC provider) that all have different enough hosting offerings that will make infrastructure automation interesting. The goal is to use this project to both learn new things and provide a portfolio of my capabilities.

## Folder Layout
```
/
    /src - sub repo that is Outline.js
    /ops - misc files for making local dev work
    /infra - example hosting implementations
        /aws - Examples that primarily live in AWS
            /cicd - CICD components such as IAM roles, S3 buckets, and OCI repositories
            /infra - core infrastructure such as networking and databases as well as top level  objects like ECS/EKS clusters by IaC tool
            /fargate_app - hosting with serverless containers
            /iaas_app - traditional hosting with ASGs
```

## Setup Instructions
Any stack or provider specific instructions can be found in their respective folders but in general there are four steps. Also keep in mind this was built using A Cloud Guru's sandbox environments and my personnel NameCheap and GitHub/Lab accounts. Some adjustments may be needed to accommodate your environment. Primarily around DNS and CICD.

First, run the appropriate script in the ops directory to setup your provider. For example with AWS and Terraform this will provision an S3 bucket and some DynamoDB tables for state management.

Second, run the root configs/playbooks/etc found in the `infra/[provider]/infra/[stack]` and `infra/[provider]/cicd/` directories. This will provision your private network and DNS, all of Outline's dependencies, and all the extras needed to automate deployments, database migrations, etc. It will also generate another script in the ops root directory that you can setup an SSH tunnel to your new network.

Third, run the bastion script.

Lastly, run the root config/playbook/etc found in the `infra/[provider]/infra/[*_app]` directory for the desired application hosting technology.

You should now be able to go to the domain name specified in the config and login to Outline.

## A Note On Naming and Modules
While Outline and its required dependencies are the only things provisioned here I've tried to structure and name things such that they would be part of a team or organizational unit's larger infrastructure. For example Outline could be one of many tools deployed in a documentation team's Amazon account; or part of many things in a shared "devops" subscription in Azure. To that end the things under `/infra/[provider]` are name very generically and meant to represent what an infrastructure group or lone devops engineer might write. While what is in the specific hosting examples is what would live the actual application's repository. 

## A Note on CICD
The `cicd` sections of each provider here are largely not a reflection of how I approach CICD. They are simply tasks that are easily generated and better done somewhere besides my computer. 

## Track Progress
Check out the [Trello board](https://trello.com/b/9fzihbj7/iac-examples) for a roadmap and current progress.