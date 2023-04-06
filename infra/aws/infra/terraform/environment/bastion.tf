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

module "bastion_ssh_key" {
  source = "../../../terraform_modules/ssh_key_pair_with_secret"

  name = "${var.env_name}-bastion"

  tags = var.default_tags
}

# data "aws_ami" "centos-stream" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["CentOS Stream ${var.centos_stream_version}*"]
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }

#   owners = ["125523088429"]
# }

data "aws_region" "current" {}
module "bastion_ami" {
  source = "../../../terraform_modules/centos_ami"

  region = data.aws_region.current.name
  centos_version_number = 9
}


resource "aws_instance" "bastion" {
  ami                         = module.bastion_ami.id #data.aws_ami.centos-stream.id
  instance_type               = "t3a.medium"
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = module.vpc.public_subnets[0]
  key_name                    = module.bastion_ssh_key.aws_key_pair.key_name
  associate_public_ip_address = true
  user_data_replace_on_change = true
  user_data                   = <<-EOT
  #!/usr/bin/bash -xe
  dnf config-manager --set-enabled crb
  dnf install -y epel-release epel-next-release
  dnf install -y podman vim atop screen postgresql tree nc bind-utils curl wget lsof zip unzip
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
