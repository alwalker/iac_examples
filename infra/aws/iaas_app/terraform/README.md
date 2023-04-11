## Additional Setup Instructions
Since an AMI must exist before an Autoscaling Group can be created there are multiple steps to getting Outline.js deployed in this solution.

First, use Terraform to create the minimum config required to run the application and also generate a Packer file.

```
terraform apply -target local_file.packer_file
```

Next, use Packer to generate the AMI.

```
packer init outline.pkr.hcl
packer build outline.pkr.hcl
```

Lastly, apply the rest of the Terraform config to stand up the ASG and the rest of the infrastructure.

```
terraform apply
```

## Notes
There is a commented out `aws_instance` in `infra/aws/iaas_app/terraform/main.tf` that is has all the configuration needed to test the AMI built by packer.

Obviously these tasks should be separated and the AMI should be built in a CICD pipeline after all tests have succeed. But, the goal here is show off different infrastructure as code techniques not necessarily CICD/devops solutions. To that end I have decided for now to simply combine these all into one Terraform root config.
