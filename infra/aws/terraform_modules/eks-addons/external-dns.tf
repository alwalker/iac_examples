module "vpc_external_dns_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                  = "external-dns"
  attach_external_dns_policy = true
  external_dns_hosted_zone_arns = [
    var.dns_zone_arn
  ]

  oidc_providers = {
    main = {
      provider_arn               = var.eks_oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  tags = var.default_tags
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}
resource "kubernetes_manifest" "serviceaccount_external_dns" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/name" = "external-dns"
          "app.kubernetes.io/managed-by" = "terraform"
      }
      "annotations" = {
        "eks.amazonaws.com/role-arn" = tostring(try(module.vpc_external_dns_irsa.iam_role_arn, ""))
      }
      "name"      = "external-dns"
      "namespace" = "external-dns"
    }
  }
}
resource "kubernetes_manifest" "clusterrole_external_dns" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/name" = "external-dns"
        "app.kubernetes.io/managed-by" = "terraform"
      }
      "name" = "external-dns"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "services",
          "pods",
          "nodes",
          "endpoints"
        ]
        "verbs" = [
          "get",
          "watch",
          "list",
        ]
      },
      {
        "apiGroups" = [
          "extensions",
          "networking.k8s.io",
        ]
        "resources" = [
          "ingresses",
        ]
        "verbs" = [
          "get",
          "watch",
          "list",
        ]
      },
    ]
  }
}
resource "kubernetes_manifest" "clusterrolebinding_external_dns_viewer" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/name" = "external-dns"
        "app.kubernetes.io/managed-by" = "terraform"
      }
      "name" = "external-dns-viewer"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "ClusterRole"
      "name"     = "external-dns"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "external-dns"
        "namespace" = "external-dns"
      },
    ]
  }
}
resource "kubernetes_manifest" "deployment_external_dns" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/name" = "external-dns"
        "app.kubernetes.io/managed-by" = "terraform"
      }
      "name"      = "external-dns"
      "namespace" = "external-dns"
    }
    "spec" = {
      "selector" = {
        "matchLabels" = {
          "app.kubernetes.io/name" = "external-dns"
        }
      }
      "strategy" = {
        "type" = "Recreate"
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app.kubernetes.io/name" = "external-dns"
          }
        }
        "spec" = {
          "containers" = [
            {
              "args" = [
                "--source=service",
                "--source=ingress",
                "--domain-filter=${var.dns_zone_name}",
                "--provider=aws",
                "--aws-zone-type=public",
                "--registry=txt",
                "--txt-owner-id=external-dns",
              ]
              "env" = [
                {
                  "name"  = "AWS_DEFAULT_REGION"
                  "value" = "${var.aws_region_name}"
                },
              ]
              "image" = "registry.k8s.io/external-dns/external-dns:v0.13.4"
              "name"  = "external-dns"
            },
          ]
          "serviceAccountName" = "external-dns"
        }
      }
    }
  }
}

resource "helm_release" "nginx" {
  name       = "nginx"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"

  values = [
    <<-EOY
    service:
      type: NodePort
    ingress:
        enabled: true
        hostname: nginx.iac-examples.com
        ingressClassName: alb
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/load-balancer-name: ${var.env_name}
          alb.ingress.kubernetes.io/group.name: ${var.env_name}
          alb.ingress.kubernetes.io/certificate-arn : ${var.acm_cert_arn}
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
          alb.ingress.kubernetes.io/ssl-redirect: '443'
    nodeSelector:
        purpose: apps
    tolerations:
        - key: dedicated
          operator: Equal
          value: apps
          effect: NoSchedule
    EOY
  ]
}