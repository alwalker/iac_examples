resource "aws_security_group" "outline" {
  name        = "${var.env_name}-outline"
  vpc_id      = module.vpc.vpc_id
  description = "Allow HTTP in from load balancer"

  tags = merge(
    { "karpenter.sh" = true },
    var.default_tags
  )
}