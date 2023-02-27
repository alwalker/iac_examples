packer {
  required_plugins {
    amazon = {
      version = "~> 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "outline" {
  profile = "default"
  region  = "us-east-1"

  ami_name              = "outline"
  ami_description       = "Image for running Outline.js wiki"
  force_deregister      = true
  force_delete_snapshot = true

  instance_type               = "t3a.medium"
  associate_public_ip_address = true
  iam_instance_profile        = "packer"
  subnet_id                   = "subnet-0d8b9418058373385"
  vpc_id                      = "vpc-0c731dee694a26dbc"

  ssh_interface = "public_ip"
  ssh_username  = "centos"

  source_ami_filter {
    filters = {
      name                = "CentOS Stream 8*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture = "x86_64"
    }
    most_recent = true
    owners      = ["125523088429"]
  }

  tags = {
    Name = "Outline"
  }
}

build {
  name = "outline"
  sources = [
    "source.amazon-ebs.outline"
  ]

  provisioner "shell" {
    script = "build_ami.sh"
    execute_command = "echo 'packer' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }
}