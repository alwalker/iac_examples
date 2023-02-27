resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_secretsmanager_secret" "ssh_key" {
  name = "${var.name}-ssh-private-key"
  force_overwrite_replica_secret = true
  recovery_window_in_days = 0

  tags = var.default_tags
}
resource "aws_secretsmanager_secret_version" "ssh_key" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = tls_private_key.ssh_key.private_key_openssh
}
resource "aws_key_pair" "main" {
  key_name   = var.name
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = var.default_tags
}

# data "aws_ami" "main" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = [var.ami_name]
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   owners = ["self"]
# }

data "aws_ami" "main" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Stream 8*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_placement_group" "main" {
  name     = var.name
  strategy = "spread"

  tags = var.default_tags
}

data "template_file" "cw_agent_setup_script" {
  template = file("${path.module}/setup_cw_agent.sh")

  vars = {
    env = var.env_name
    cicd_bucket_name = var.cicd_bucket_name
  }
}

resource "aws_launch_template" "main" {
  name                    = var.name
  disable_api_termination = false
  ebs_optimized           = true
  image_id                = data.aws_ami.main.id
  instance_type           = var.instance_size
  key_name                = aws_key_pair.main.id
  vpc_security_group_ids  = var.security_group_ids
  # user_data               = base64encode(data.template_file.cw_agent_setup_script.rendered)

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
    }
  }

  iam_instance_profile {
    arn = var.iam_profile_arn
  }

  placement {
    group_name = aws_placement_group.main.id
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge({Name = var.name}, var.default_tags)
  }

  tags = var.default_tags
}

resource "aws_autoscaling_group" "main" {
  name                      = "${var.name}-${aws_launch_template.main.latest_version}"
  max_size                  = var.max_instance_count
  min_size                  = var.min_instance_count
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = "ELB"
  wait_for_elb_capacity     = 1
  desired_capacity          = var.base_instance_count
  force_delete              = false
  placement_group           = aws_placement_group.main.id
  vpc_zone_identifier       = var.private_subnets
  target_group_arns         = var.target_groups

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  depends_on = [aws_cloudwatch_log_group.main]
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name              = var.name
  retention_in_days = "30"
  # kms_key_id        = var.cw_kms_key_id

  tags = var.default_tags
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
