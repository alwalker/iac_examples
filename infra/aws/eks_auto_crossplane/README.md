# EKS Auto Mode And Crossplane

This was supposed to be a short script that spun up EKS with `eksctl` and the new "auto mode" feature then used Crossplane to provision S3, Redis, and RDS. However, this quickly devolved into something that just wasn't worth the effort. 

## EKS Auto Mode

I didn't really get auto mode at first, what's the point of one lining cluster creation when there's still so much work you have to do after? Then I spent nine months helping a client "modernize" their DevOps practices around a whole bunch of ElasticBeanstalk deployments and for the first time got to see a production workflow of nothing but CloudFormation and shell scripting. It's not for me, but I now appreciate this workflow and how it can be *very* productive for a small group of people; and that lines up with what I'm trying to accomplish here.

This still kind of falls apart quickly though. Like everything else in this repo this was done in an ACloudGuru sandbox AWS Account. These only allow you to use a limited number of small instance types. So simply doing `eksctl create cluster --enable-auto-mode` won't work because it provisions the system node pool with ludicrously large C instance types. Fixing this requires you to create a custom configuration out of the gate or your sandbox will be terminated. doing this requires creating a role, attaching three policies to that role, setting and EKS access policy, and creating an access entry alone on the AWS side; and additionally two more Karpenter objects in your cluster to define a new node class and pool. So your simple shell commands to create a cluster immediately balloon into several bash commands (the route I chose) or even more CloudFormation that's not managed via `eksctl`.

While doing this you'll quickly discover (at least as of this writing) that the documentation for auto mode isn't the best. Thankfully it is well designed in that all it really appears to do is apply some existing CloudFormation templates and install Karpenter on your cluster. However, you'll find things like the spec for the `NodeClass` object requiring an IAM role name but the example given shows an ARN and all the instance tags they show break things unless you perform [extra steps](https://medium.com/@kazioyazi/nodeclaim-has-error-error-getting-launch-template-configs-in-eks-auto-mode-46edca067fba) not in the documentation 

None of this is the end of the world, and you can see a BASH script that will do it all for you here, but why would you do this instead of Terraform and a Helm chart with all your desired Karpenter config? Unless you are super comfortable with CloudFormation and slinging *loads* of your favorite shell scripting language I can not not recommend this approach enough. The Terraform module for EKS isn't the best but its way more manageable than this.

And you're gonna want Terraform anyways because...

## Crossplane

...is a dumpster fire. This whole idea came around after working with a client for several months to build out their "platform" in GKE using Crossplane. That too was eventually abandoned for Terraform.

### YAML

It's not just that Crossplane is a lot of YAML, and that YAML is way worse to deal with than HCL in my opinion; it's that it's bad YAML. The patch and transform style of building Composition Templates is the worst. All of the operations look exactly the same because they're just a YAML object with a couple of properties, regardless of whether you're combing strings, matching regular expressions, or just copying values off your claim. And you have dozens of them in the same file. This creates one homogeneous mess of YAML that can't be visually parsed.

We went down this path at a client for a while because at the time the only alternative we saw was using Go templates (and at that point why not just use Helm charts?). We wound up switching to them anyways after they hired a full time DevOps engineer who was dyslexic and literally couldn't read the patch and transform compositions. 

The last thing I'll say on this is you can see an example here of the patch and transform equivalent of the S3 Terraform module at `infra/aws/terraform_modules/outline_s3_bucket/s3.tf` and its more than double the number of lines. 

### KCL

It's neat, and definitely better than patch and transform; but inlining it into your YAML objects is a terrible experience unless there is some magic editor out there I'm not aware of that can do syntax highlighting and auto formatting for both YAML and KCL together. This only alternative is building and hosting an OCI artifact for each KCL "step" you have. This will obviously get out of hand fast and is a terrible idea for any small team to try and attempt. 

There's also almost no examples for anything related to Crossplane in KCL, so get ready to spend half your time passing YAML from the Upbound site into your LLM of choice to get it to transform it into mostly usable KCL.

It too, thanks to the addition of having to micro manage each object's metadata, is comically bloated compared to it's HCL equivalent. The Redis example you can see here is nearly three times the amount of YAML and KCL than HCL and doesn't even work.

Lastly at the time of writing there was no easy/documented way to access EnvironmentConfigs from KCL either. This was a bummer as I thought having one global object accessible from any composition template would be a much nicer alternative to outputting an entire Terraform module and doing the state lookup dance.

### Everything Else

Troubleshooting Crossplane is a lot of work. You already have to make too many different objects in your cluster just to create a cloud resource and then those exploded into claims, versions, etc once applied. This results in a lot of back and forth checking status and events on objects to troubleshoot a single cloud resource. This could be mitigated by a robust observability solution, but again the idea here was easy solution for a small team.

This isn't demonstrable here but propagating results up layers of composite types (claiming a composite that also makes claims) takes time. Depending on how your dependencies work this can take tens of minutes to deploy just a few resources. The worst case I saw was ten minutes per level of composition, aka every `depends_on` clause on a Terraform resource that couldn't be processed asynchronously would add ten minutes to your apply.

The microservices design of the providers and the general nature of kubernetes means you quickly wind up assaulting both your cloud API and any other kubernetes clusters with a non trivial amount of network traffic just for status updates.

There's an awkward relationship between Crossplane the tool and the various providers. Unlike Terraform where both the tool itself and its providers are owned by the same org Crossplane is a CNCF project while the providers are owned by Upbound. The final straw with the client mentioned earlier was Upbound changing their policies to only provide the bleeding edge artifacts for Crossplane and all the providers stating if you wanted anything older you'd have to build it yourself or pay them for support. Like most of the complaints already made here, doable, but not what you want for a simple solution.

## Thoughts

This was supposed to be a quick and easy solution, a bit of BASH and a bunch of YAML written over a few beers over a couple of weekends to demonstrate a more "cloud native" solution compared to the other examples in the repo and also preserve some of the knowledge gained from work. It turned out to be an example of why Terraform has such a strong position in the market. Doing the simplest thing with either of these tools quickly balloons into a giant pile of effort. Combine that with the end result being less readable and maintainable than Terraform and the juice just wasn't worth the squeeze.

Oh, also I found out both that both [Kro](https://github.com/kro-run/kro) exists and AWS, GCP, and Azure all have their own library of Kubernetes objects for creating cloud resources. That was truly the final nail in the coffin.

Oh, also also; Crossplane just uses Terraform under the hood to do the actual provisioning of cloud resources.
