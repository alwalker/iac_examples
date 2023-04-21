DYNAMODB_KEY="AttributeName=LockID,KeyType=HASH"
DYNAMODB_ATT="AttributeName=LockID,AttributeType=S"

aws s3api create-bucket --bucket awsiac-devops

aws dynamodb create-table --table-name terraform-states-infra --attribute-definitions $DYNAMODB_ATT --key-schema $DYNAMODB_KEY --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
aws dynamodb create-table --table-name terraform-states-infra-prod-kubernetes --attribute-definitions $DYNAMODB_ATT --key-schema $DYNAMODB_KEY --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
aws dynamodb create-table --table-name terraform-states-outline-prod --attribute-definitions $DYNAMODB_ATT --key-schema $DYNAMODB_KEY --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
aws dynamodb create-table --table-name terraform-states-cicd --attribute-definitions $DYNAMODB_ATT --key-schema $DYNAMODB_KEY --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
aws dynamodb create-table --table-name terraform-states-outline-fargate-prod --attribute-definitions $DYNAMODB_ATT --key-schema $DYNAMODB_KEY --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
