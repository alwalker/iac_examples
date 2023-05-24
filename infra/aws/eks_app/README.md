## Additional Setup Instructions
In order to deploy this EKS based solution there must first be an image for Outline.js in an ECR. This ECR along with a GitHub Actions workflow to populate it is created in the `infra/aws/cicd` config. Once you have applied this you can commit and push that new workflow then run it.

## Notes
Obviously this task would be better handled in a proper CICD workflow. The images should only be pushed after being built and tested.