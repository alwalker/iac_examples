module "karpenter_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                          = "karpenter_controller"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_id = var.eks_cluster_name
  karpenter_controller_node_iam_role_arns = [
    var.eks_default_node_group_iam_role_arn
  ]

  oidc_providers = {
    main = {
      provider_arn               = var.eks_oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "helm_release" "karpenter" {
  depends_on = [
    module.karpenter_irsa
  ]

  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "v0.27.5"

  values = [
    <<-EOY
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter_irsa.iam_role_arn}
    EOY
  ]

  set {
    name  = "settings.aws.clusterName"
    value = var.eks_cluster_name
  }
  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = "eks-${var.eks_default_node_group_guid}"
  }
  set {
    name  = "settings.aws.interruptionQueueName"
    value = var.eks_cluster_name
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "500m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }
}

# resource "kubernetes_manifest" "provisioner_system" {
#   manifest = {
#     "apiVersion" = "karpenter.sh/v1alpha5"
#     "kind"       = "Provisioner"
#     "metadata" = {
#       "name" = "system"
#     }
#     "spec" = {
#       "limits" = {
#         "resources" = {
#           "cpu" = 16
#         }
#       }
#       "providerRef" = {
#         "name" = "system"
#       }
#       "requirements" = [
#         {
#           "key"      = "karpenter.sh/capacity-type"
#           "operator" = "In"
#           "values" = [
#             "spot",
#           ]
#         },
#         {
#           "key"      = "karpenter.k8s.aws/instance-category"
#           "operator" = "In"
#           "values" = [
#             "t",
#           ]
#         },
#         {
#           "key"      = "karpenter.k8s.aws/instance-cpu"
#           "operator" = "In"
#           "values" = [
#             "2",
#           ]
#         },
#         {
#           "key"      = "karpenter.k8s.aws/instance-generation"
#           "operator" = "In"
#           "values" = [
#             "2",
#             "3",
#           ]
#         },
#         {
#           "key"      = "kubernetes.io/os"
#           "operator" = "In"
#           "values" = [
#             "linux",
#           ]
#         },
#         {
#           "key"      = "kubernetes.io/arch"
#           "operator" = "In"
#           "values" = [
#             "amd64",
#           ]
#         },
#       ]
#       "ttlSecondsAfterEmpty" = 30
#     }
#   }
# }

# resource "kubernetes_manifest" "awsnodetemplate_system" {
#   manifest = {
#     "apiVersion" = "karpenter.k8s.aws/v1alpha1"
#     "kind"       = "AWSNodeTemplate"
#     "metadata" = {
#       "name" = "system"
#     }
#     "spec" = {
#       "securityGroupSelector" = {
#         "kubernetes.io/cluster/prod" = "prod-node"
#       }
#       "subnetSelector" = {
#         "type" = "eks-node"
#       }
#       "tags" = "${var.default_tags}"
#     }
#   }
# }

resource "kubernetes_manifest" "provisioner_apps" {
  manifest = {
    "apiVersion" = "karpenter.sh/v1alpha5"
    "kind"       = "Provisioner"
    "metadata" = {
      "name" = "apps"
    }
    "spec" = {
      "labels" = {
        "purpose" = "apps"
      }
      "limits" = {
        "resources" = {
          "cpu" = 16
        }
      }
      "providerRef" = {
        "name" = "apps"
      }
      "requirements" = [
        {
          "key"      = "karpenter.sh/capacity-type"
          "operator" = "In"
          "values" = [
            "spot",
          ]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-category"
          "operator" = "In"
          "values" = [
            "t",
          ]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-cpu"
          "operator" = "In"
          "values" = [
            "2",
          ]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-generation"
          "operator" = "In"
          "values" = [
            "2",
            "3",
          ]
        },
        {
          "key"      = "kubernetes.io/os"
          "operator" = "In"
          "values" = [
            "linux",
          ]
        },
        {
          "key"      = "kubernetes.io/arch"
          "operator" = "In"
          "values" = [
            "amd64",
          ]
        },
      ]
      "taints" = [
        {
          "effect" = "NoSchedule"
          "key"    = "dedicated"
          "value"  = "apps"
        },
      ]
      "ttlSecondsAfterEmpty" = 30
    }
  }
}

resource "kubernetes_manifest" "awsnodetemplate_apps" {
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1alpha1"
    "kind"       = "AWSNodeTemplate"
    "metadata" = {
      "name" = "apps"
    }
    "spec" = {
      "securityGroupSelector" = {
        "karpenter.sh" = "true"
      }
      "subnetSelector" = {
        "type" = "eks-node"
      }
      "tags" = "${var.default_tags}"
    }
  }
}
