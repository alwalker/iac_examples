set -e

HTML_FILE=$(mktemp)

wget "https://www.centos.org/download/aws-images/" -O $HTML_FILE;

AMI_ID=$(xmllint --html --xpath \
    '//*[@id="download-mirror"]/tbody/tr[td[normalize-space(text())="'"$AWS_REGION"'"] and td[normalize-space(text())="CentOS Stream '"$VERSION"'"] and td[normalize-space(text())="'"${ARCHITECTURE:=x86_64}"'"]]/td[4]/text()' \
    $HTML_FILE)

echo '{"id": "'"$AMI_ID"'"}'