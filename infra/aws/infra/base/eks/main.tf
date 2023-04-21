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

resource "aws_security_group" "eks" {
  name        = "${var.env_name}-eks-bastion-access"
  vpc_id      = var.vpc_id
  description = "Allow SSH and HTTPS in from the bastion"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = var.ssh_port
    to_port         = var.ssh_port
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
  }
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
  }

  tags = merge({ Name = "${var.env_name}-eks-bastion-access" }, var.default_tags)
}

module "eks_ssh_key" {
  source = "../../../terraform_modules/ssh_key_pair_with_secret"

  name = "${var.env_name}-eks"

  tags = var.default_tags
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

  vpc_id                   = var.vpc_id
  subnet_ids               = data.aws_subnets.valid_eks_node_subnets.ids          #[for s in module.eks_node_subnets[*].self : s.id]
  control_plane_subnet_ids = data.aws_subnets.valid_eks_control_plane_subnets.ids #[for s in module.eks_control_plane_subnets[*].self : s.id]

  cluster_additional_security_group_ids = [aws_security_group.eks.id]

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3a.small"]

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
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
    }
  }

  eks_managed_node_groups = {
    # Default node group - as provided by AWS EKS
    default_node_group = {
      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      use_custom_launch_template = false

      disk_size = 50

      # Remote access cannot be specified with a launch template
      remote_access = {
        ec2_ssh_key               = module.eks_ssh_key.aws_key_pair.key_name
        source_security_group_ids = [aws_security_group.eks.id]
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

      tags = {
        EKS-node-pool-name = "apps"
      }
    }
  }

  tags = var.default_tags
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
