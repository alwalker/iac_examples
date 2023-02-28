echo "127.0.0.1 prod.ciozfbnrwwpp.us-east-1.rds.amazonaws.com" >> /etc/hosts

ssh -N -v \
    -i /tmp/bastion_ssh_key \
    -L 5432:prod.ciozfbnrwwpp.us-east-1.rds.amazonaws.com:5432 \
    centos@3.80.39.252