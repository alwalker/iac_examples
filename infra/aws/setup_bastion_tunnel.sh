echo "127.0.0.1 3.80.159.169" >> /etc/hosts

ssh -N -v \
    -i /tmp/bastion_ssh_key \
    -L 5432:prod.c11ghxbc31cc.us-east-1.rds.amazonaws.com:5432 \
    centos@3.80.159.169