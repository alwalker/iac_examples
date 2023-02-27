set -e

#update base image
dnf update -y --refresh

#install helpful tools
dnf install -y epel-release
dnf install -y vim screen atop tree nc bind-utils curl jq lsof unzip wget podman

#setup awscli
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
ln -s /usr/local/bin/aws /usr/bin/aws
rm -rf aws
rm -f awscliv2.zip


#setup user
useradd -c "Outline User" -s /bin/bash -m outline

#setup configs
mkdir /opt/configs
# echo "REPLACE ME" > /opt/configs/env
aws s3 cp s3://alwiac-cicd2/outline-prod-env /opt/configs/env
chown -R outline:outline /opt/configs

#create pod
cd /tmp #podman tries to do things in whatever directory you run the command in
sudo -u outline podman create \
    --name outline \
    --pull missing \
    --env-file /opt/configs/env \
    --publish 6100:3000 \
    docker.io/outlinewiki/outline:latest

#setup outline systemd unit
sudo -u outline mkdir -p /home/outline/.config/systemd/user
sudo -u outline podman generate systemd --restart-policy=on-failure outline > /home/outline/.config/systemd/user/outline.service
systemctl --user -M outline@ daemon-reload
systemctl --user -M outline@ enable outline.service

#setup cloudwatch agent
wget --quiet "https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"
rpm -U amazon-cloudwatch-agent.rpm
rm amazon-cloudwatch-agent.rpm
