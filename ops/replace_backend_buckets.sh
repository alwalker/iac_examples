find /workspace/infra/aws/ -name main.tf \
| xargs sed --separate -r 's/bucket\s+= \"awsiac-devops\"/bucket = "awsiac-devops2"/g'