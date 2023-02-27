echo "127.0.0.1 prod.cye9s51evhwc.us-east-1.rds.amazonaws.com" >> /etc/hosts

ssh -N -v \
    -i /tmp/bastion_ssh_key \
    -L 5432:prod.cye9s51evhwc.us-east-1.rds.amazonaws.com:5432 \
    centos@54.80.108.238