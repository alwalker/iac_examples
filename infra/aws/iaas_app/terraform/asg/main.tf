module "ssh_key" {
  source = "../../../terraform_modules/ssh_key_pair_with_secret"

  name = "${var.env_name}-${var.name}"
  tags = var.default_tags
}

data "aws_ami" "main" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"]
}

resource "aws_placement_group" "main" {
  name     = "${var.env_name}-${var.name}"
  strategy = "spread"

  tags = var.default_tags

  lifecycle {
    ignore_changes = [
      partition_count,
      spread_level
    ]
  }
}

locals {
  cloud_init_script = <<-EOF
  #!/usr/bin/bash -xe
  echo -n "${var.env_name}" | sudo -u outline tee /opt/outline/env_name
  sudo -iu outline bash /opt/outline/get_configs.sh
  echo "balls"
  EOF
}

data "aws_ec2_instance_type_offerings" "valid_availability_zones" {
  filter {
    name   = "instance-type"
    values = [var.instance_size]
  }

  filter {
    name   = "location"
    values = var.availability_zones
  }

  location_type = "availability-zone"
}
data "aws_subnets" "valid_subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.valid_availability_zones.locations
  }

  tags = {
    type = "private"
  }
}

resource "aws_launch_configuration" "main" {
  image_id      = data.aws_ami.main.id
  instance_type = var.instance_size

  associate_public_ip_address = false
  ebs_optimized               = true
  enable_monitoring           = true
  iam_instance_profile        = var.iam_profile_name
  key_name                    = module.ssh_key.aws_key_pair.id
  name_prefix                 = "${var.env_name}-${var.name}-"
  security_groups             = var.security_group_ids
  user_data_base64            = base64encode(local.cloud_init_script)

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.root_volume_size

  }
}

resource "aws_autoscaling_group" "main" {
  name                      = aws_launch_configuration.main.name
  max_size                  = var.max_instance_count
  min_size                  = var.min_instance_count
  health_check_grace_period = var.health_check_grace_period
  launch_configuration      = aws_launch_configuration.main.id
  health_check_type         = "ELB"
  target_group_arns         = var.target_group_arns
  wait_for_elb_capacity     = 1
  wait_for_capacity_timeout = "10m"
  desired_capacity          = var.base_instance_count
  force_delete              = false
  placement_group           = aws_placement_group.main.id
  vpc_zone_identifier       = data.aws_subnets.valid_subnets.ids

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_cloudwatch_metric_alarm" "asg_cpu_utilization_high" {
  alarm_name          = "${var.name}-CPU-Utilization-High-${var.asg_cpu_max_threshold}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.asg_cpu_max_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.asg_scale_up.arn]

  tags = var.default_tags
}
resource "aws_cloudwatch_metric_alarm" "asg_cpu_utilization_low" {
  alarm_name          = "${var.name}-CPU-Utilization-Low-${var.asg_cpu_min_threshold}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.asg_cpu_min_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.asg_scale_down.arn]

  tags = var.default_tags
}
resource "aws_autoscaling_policy" "asg_scale_up" {
  name                   = "${var.name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.main.name
}
resource "aws_autoscaling_policy" "asg_scale_down" {
  name                   = "${var.name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.main.name
}
