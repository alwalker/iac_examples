resource "aws_security_group" "bastion" {
  name        = "${var.env_name}-bastion"
  vpc_id      = module.vpc.vpc_id
  description = "Allow SSH in from the world"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.default_tags
}

resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "ED25519"
}
resource "aws_secretsmanager_secret" "bastion_ssh_private_key" {
  name = "bastion-ssh-private-key"
  force_overwrite_replica_secret = true

  tags = var.default_tags
}
resource "aws_secretsmanager_secret_version" "bastion_ssh_private_key" {
  secret_id     = aws_secretsmanager_secret.bastion_ssh_private_key.id
  secret_string = tls_private_key.bastion_ssh_key.private_key_openssh
}
resource "aws_key_pair" "bastion" {
  key_name   = "${var.env_name}-bastion-key"
  public_key = trimspace(tls_private_key.bastion_ssh_key.public_key_openssh)

  tags = var.default_tags
}

data "aws_ami" "centos-stream" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Stream ${var.centos_stream_version}*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["125523088429"]
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.centos-stream.id
  instance_type               = "t3a.nano"
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = module.vpc.public_subnets[0]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true
  user_data                   = <<-EOT
  #!/usr/bin/bash -xe
  dnf install -y atop screen postgresql tree nc bind-utils curl wget lsof zip unzip
  EOT

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge({ Name = "${var.env_name}-bastion" }, var.default_tags)
}

resource "aws_route53_record" "bastion" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "${var.env_name}-bastion"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.bastion.public_ip]
}
