data "aws_ec2_instance_type_offerings" "valid_eks_node_availability_zones" {
  filter {
    name   = "instance-type"
    values = ["t3a.small"]
  }

  filter {
    name   = "location"
    values = var.vpc_availability_zones
  }

  location_type = "availability-zone"
}
data "aws_subnets" "valid_eks_node_subnets" {
  depends_on = [
    module.eks_node_subnets
  ]

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.valid_eks_node_availability_zones.locations
  }

  tags = {
    type = "eks-node"
  }
}
data "aws_subnet" "node_subnets" {
  # for_each = { for k,v in data.aws_subnets.valid_eks_node_subnets.ids : k => v.id }
  count = length(data.aws_subnets.valid_eks_node_subnets)

  id = data.aws_subnets.valid_eks_node_subnets.ids[count.index]
}

data "aws_ec2_instance_type_offerings" "valid_eks_control_plane_availability_zones" {
  filter {
    name   = "instance-type"
    values = ["t3a.small"]
  }

  filter {
    name   = "location"
    values = var.vpc_availability_zones
  }

  location_type = "availability-zone"
}
data "aws_subnets" "valid_eks_control_plane_subnets" {
  depends_on = [
    module.eks_control_plane_subnets
  ]

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.valid_eks_control_plane_availability_zones.locations
  }

  tags = {
    type = "eks-control-plane"
  }
}

resource "aws_security_group" "bastion_api_access" {
  name        = "${var.env_name}-eks-bastion-api-access"
  vpc_id      = var.vpc_id
  description = "Allow HTTPS in from the bastion"

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
  }

  tags = merge({ Name = "${var.env_name}-eks-bastion-access" }, var.default_tags)
}
resource "aws_security_group" "coredns" {
  name        = "${var.env_name}-eks-coredns"
  vpc_id      = var.vpc_id
  description = "Allow DNS requests from other nodes"

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [for sn in data.aws_subnet.node_subnets : sn.cidr_block]
  }
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [for sn in data.aws_subnet.node_subnets : sn.cidr_block]
  }

  tags = merge({ Name = "${var.env_name}-eks-bastion-access" }, var.default_tags)
}

module "vpc_cni_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "vpc_cni"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = var.default_tags
}

module "eks_ssh_key" {
  source = "../../../terraform_modules/ssh_key_pair_with_secret"

  name = "${var.env_name}-eks"

  tags = var.default_tags
}

resource "aws_iam_policy" "apps_ecr_access" {
  name = "ecr-eks-access"
  path = "/"

  policy = <<-EOJ
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "ecr:BatchCheckLayerAvailability",
                  "ecr:BatchGetImage",
                  "ecr:GetDownloadUrlForLayer",
                  "ecr:GetAuthorizationToken"
              ],
              "Resource": "*"
          }
      ]
  }
  EOJ
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.13.0"

  cluster_name                   = var.env_name
  cluster_version                = var.kubernetes_version
  cluster_endpoint_public_access = false

  cluster_ip_family = "ipv4"

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id                                = var.vpc_id
  subnet_ids                            = data.aws_subnets.valid_eks_node_subnets.ids
  control_plane_subnet_ids              = data.aws_subnets.valid_eks_control_plane_subnets.ids
  cluster_additional_security_group_ids = [aws_security_group.bastion_api_access.id]

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3a.medium"]

    iam_role_attach_cni_policy = true

    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "disabled"
    }

    node_security_group_additional_rules = {
      ingress_allow_access_from_control_plane = {
        type                          = "ingress"
        protocol                      = "tcp"
        from_port                     = 9443
        to_port                       = 9443
        source_cluster_security_group = true
        description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
      }
      bastion_ssh_access = {
        type                     = "ingress"
        protocol                 = "tcp"
        from_port                = var.ssh_port
        to_port                  = var.ssh_port
        source_security_group_id = var.bastion_security_group_id
        description              = "Allow access from control plane to webhook port of AWS load balancer controller"
      }
    }
  }

  eks_managed_node_groups = {
    system = {
      name            = "system"
      use_name_prefix = true

      subnet_ids = data.aws_subnets.valid_eks_node_subnets.ids

      min_size = 0
      max_size = 2

      force_update_version = true
      instance_types       = ["t3a.small"]

      labels = {
        purpose = "system"
      }
      # taints = [
      #   {
      #     key    = "dedicated"
      #     value  = "apps"
      #     effect = "NO_SCHEDULE"
      #   }
      # ]

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      tags = {
        EKS-node-pool-name = "apps"
      }
    }

    apps = {
      name            = "apps"
      use_name_prefix = true

      subnet_ids = data.aws_subnets.valid_eks_node_subnets.ids

      min_size = 0
      max_size = 7

      capacity_type        = "SPOT"
      force_update_version = true
      instance_types       = ["t3a.medium"]

      labels = {
        purpose = "apps"
      }
      taints = [
        {
          key    = "dedicated"
          value  = "apps"
          effect = "NO_SCHEDULE"
        }
      ]

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      iam_role_additional_policies = {
        testme = aws_iam_policy.apps_ecr_access.arn
      }

      vpc_security_group_ids = [var.outline_security_group_id]

      tags = {
        EKS-node-pool-name = "apps"
      }
    }
  }

  tags = var.default_tags
}
