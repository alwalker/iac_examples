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

## A Note On Naming and Modules
While Outline and its required dependencies are the only things provisioned here I've tried to structure and name things such that they would be part of a team or organizational unit's larger infrastructure. For example Outline could be one of many tools deployed in a documentation team's Amazon account; or part of many things in a shared "devops" subscription in Azure. To that end the things under `/infra/[provider]` are name very generically and meant to represent what an infrastructure group or lone devops engineer might write. While what is in the specific hosting examples is what would live the actual application's repository. 

## Track Progress
Check out the [Trello board](https://trello.com/b/9fzihbj7/iac-examples) for a roadmap and current progress.