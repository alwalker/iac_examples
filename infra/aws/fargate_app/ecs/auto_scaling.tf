resource "aws_cloudwatch_metric_alarm" "service_cpu_utilization_high" {
  alarm_name          = "${var.env_name}-${var.name}-CPU-Utilization-High-${var.maximum_service_cpu_threshold}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = var.maximum_service_cpu_threshold

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = aws_ecs_service.main.name
  }

  alarm_actions = [aws_appautoscaling_policy.up.arn]

  tags = var.default_tags
}
resource "aws_cloudwatch_metric_alarm" "service_cpu_utilization_low" {
  alarm_name          = "${var.env_name}-${var.name}-CPU-Utilization-Low-${var.minimum_service_cpu_threshold}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = var.minimum_service_cpu_threshold

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = aws_ecs_service.main.name
  }

  alarm_actions = [aws_appautoscaling_policy.down.arn]

  tags = var.default_tags
}

resource "aws_appautoscaling_target" "main" {
  service_namespace  = "ecs"
  resource_id        = element(split(":", aws_ecs_service.main.id), length(split(":", aws_ecs_service.main.id)) - 1)
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.minimum_service_count
  max_capacity       = var.maximum_service_count
}
resource "aws_appautoscaling_policy" "up" {
  name        = "${var.env_name}-${var.name}-service-scale-up"
  policy_type = "StepScaling"

  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}
resource "aws_appautoscaling_policy" "down" {
  name        = "${var.env_name}-${var.name}-service-scale-down"
  policy_type = "StepScaling"

  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}
