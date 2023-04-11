set -e

#update base image
echo "Updating base image..."
dnf clean all
dnf makecache
dnf update -yq --refresh
echo "Done"

#install helpful tools
echo "Installing epel, epel-next, and debugging tools..."
dnf config-manager --set-enabled crb
dnf install -yq epel-release epel-next-release
dnf install -yq jq podman vim atop screen postgresql tree nc bind-utils curl wget lsof zip unzip
echo "Done"

#setup awscli
echo "Setup AWS CLI..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
ln -s /usr/local/bin/aws /usr/bin/aws
rm -rf aws
rm -f awscliv2.zip
echo "Done"

#setup user
echo "Creating outline user..."
useradd -c "Outline User" -s /bin/bash -m outline
echo "Done"

#setup local files
echo "Setting up local files and directoriers..."

mkdir /var/log/outline
chmod 700 /var/log/outline
chown outline:outline /var/log/outline

mkdir -p /opt/outline/logs
cat << 'EOF' > /opt/outline/get_configs.sh
AWS_ENV_NAME=$(cat /opt/outline/env_name)
/usr/bin/aws s3 cp s3://iac-examples-cicd/outline-$AWS_ENV_NAME-env /opt/outline/env
/usr/bin/aws s3 cp s3://iac-examples-cicd/cloudwatch-$AWS_ENV_NAME.json /opt/outline/cloudwatch.json
EOF
cat << 'EOF' > /opt/outline/daily-job.sh
/usr/bin/curl $URL/api/cron.daily?token=$UTILS_SECRET
EOF
mkdir /opt/outline/source
aws s3 cp s3://iac-examples-cicd/source.zip /opt/outline/source.zip
unzip -q /opt/outline/source.zip -d /opt/outline/source
chown -R outline:outline /opt/outline

echo "Done"

#Setup Node.js and build Outline
echo "Installing Node.js and building Outline.js..."

dnf module install -yq nodejs:18/common
curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
dnf install -y yarn

sudo -i -u outline << EOF
cd /opt/outline/source
yarn install
yarn build
EOF

echo "Done"

#Setup systemd service and logging
echo "Setting up systemd service..."

cat << EOF > /usr/lib/systemd/system/outline.service
[Unit]
Description=Outline.js

[Service]
User=outline
Restart=on-failure
RestartSec=30
StandardOutput=append:/var/log/outline/logs.log
StandardError=append:/var/log/outline/logs.log
EnvironmentFile=/opt/outline/env
WorkingDirectory=/opt/outline/source
ExecStartPre=/usr/bin/bash /opt/outline/get_configs.sh
ExecStartPre=/usr/bin/yarn db:migrate
ExecStart=/usr/bin/yarn start

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /usr/lib/systemd/system/outline-daily-job.service
[Unit]
Description=Outline.js Daily Job
Wants=outline-daily-job.timer

[Service]
User=outline
Type=oneshot
StandardOutput=append:/var/log/outline/daily-job-logs.log
StandardError=append:/var/log/outline/daily-job-logs.log
EnvironmentFile=/opt/outline/env
WorkingDirectory=/opt/outline/source
ExecStartPre=/usr/bin/bash /opt/outline/get_configs.sh
ExecStart=/usr/bin/bash /opt/outline/daily-job.sh

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /usr/lib/systemd/system/outline-daily-job.timer
[Unit]
Description=Outline.js Daily Job Timer
Requires=outline-daily-job.service

[Timer]
Unit=outline-daily-job.service
OnCalendar=*-*-* 00:15:30

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable outline.service
systemctl enable outline-daily-job.timer

sudo -u outline touch /home/outline/logrotate-state
cat << EOF > /home/outline/logrotate.conf
"/var/log/outline/*.log" {
  maxsize 100M
  hourly
  missingok
  rotate 8
  compress
  notifempty
  nocreate
}
EOF
sudo -i -u outline << EOF
(crontab -l ; echo "15 * * * * /usr/sbin/logrotate /home/outline/logrotate.conf --state /home/outline/logrotate-state") | crontab -
EOF

echo "Done"

#setup cloudwatch agent
echo "Setting up cloudwatch..."

wget --quiet "https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"
rpm -U amazon-cloudwatch-agent.rpm
rm amazon-cloudwatch-agent.rpm

mkdir /etc/systemd/system/amazon-cloudwatch-agent.service.d
chmod 754 /etc/systemd/system/amazon-cloudwatch-agent.service.d
cat << EOF > /etc/systemd/system/amazon-cloudwatch-agent.service.d/local.conf
[Unit]
After=outline.service

[Service]
ExecStartPre=/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/outline/cloudwatch.json
EOF

systemctl enable amazon-cloudwatch-agent

echo "Done"
