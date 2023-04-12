## Additional Setup Instructions
In order to deploy this ECS based solution there must first be an image for Outline.js in an ECR. This ECR along with a GitHub Actions workflow to populate it is created in the `infra/aws/cicd` config. Once you have applied this you can commit and push that new workflow then run it.

Similarly the database migrations must also be manually ran. After applying the config found here an additional workflow will be created that you can commit, push, and then run on GitHub. Once this is done the main ECS service should start running.

## Notes
Obviously these tasks would be better handled in a proper CICD workflow. The images should only be pushed after being built and tested. The migrations should either be run automatically with the deployment of the service itself or personally I'm a big fan of making your database migrations a separate "deployment" that has its own build and release workflow.