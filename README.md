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

## Some Interesting Branches

### aws-terraform-karpetner

I initially used `cluster-autoscaler` for the EKS implementation. After finishing I remembered Karpenter was a thing and tried to replace `cluster-autoscaler`.  This didn't go quite as well as expected for a couple of reasons. Primarily there were a lot of IAM related tasks that the Karpenter IRSA module didn't take care of that I was getting frustrated with having to add in or cobble together out of the outputs from the EKS module itself. Also, the A Cloud Guru sandboxes won't let you access some of the pricing API stuff that Karpenter needs to do determine what instance type to use.

Additionally after going thru this process I'm not convinced Karpenter is worth the effort. I don't care for the separation of provisioners and node templates even though they can't exist w/o each other. Combine this with what seemed like the inability to select different security groups for your nodes based on different criteria (an or condition for securityGroupSelector?) and that it also seemed like you were still going to have to maintain a "system" node pool for Karpenter itself, `external-dns`; and it just didn't seem like it was worth the effort.

All that being said I'm not 100% sure its impossible to implement, and I see the value in it for things like a super elastic and heterogeneous environments.  But its certainly passed the time box I've allowed myself for it and I already have a working solution. I've left my progress towards this goal in this branch.

### fedora_coreos_expirement

This is the broken remains of my attempt to drink all of the Redhat koolaid. It is an IAAS style solution but the VM was built using Fedora CoreOS with rootless Podman and systemd. I got this mostly working but couldn't ever get the logs going somewhere the Cloudwatch agent could find them. I also wasn't ever really happy with how migrations worked. But I did learn a bit more about systemd and selinux in the process.

I stopped because I had already spent two weeks on it and really wanted to move onto the EKS implementation. Also I don't think doing this entirely with immutable infrastructure solutions like Terraform and ASGs is the way to go. I think the better solution is using something like Terraform to spin up a pool of Fedora CoreOS nodes in an ASG with some basic healthchecks then using something like Ansible to add multiple apps to those nodes as well as healthchecks, routes, etc to an ALB. Otherwise I think you're missing out on the benefits of an immutable os and selinux and just doing a normal VM based solution but with extra steps and points of failure.

## Track Progress
Check out the [Trello board](https://trello.com/b/9fzihbj7/iac-examples) for a roadmap and current progress.