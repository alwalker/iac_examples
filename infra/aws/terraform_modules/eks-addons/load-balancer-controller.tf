module "vpc_ingress_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.eks_oidc_provider_arn
      namespace_service_accounts = ["kube-system:load-balancer-controller"]
    }
  }

  tags = var.default_tags
}

resource "helm_release" "load-balancer-controller" {
  depends_on = [
    module.vpc_ingress_irsa
  ]

  name       = "load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [
    <<-EOY
    clusterName: ${var.eks_cluster_name}
    serviceAccount:
        name: load-balancer-controller
        annotations:
            eks.amazonaws.com/role-arn: ${module.vpc_ingress_irsa.iam_role_arn}
    EOY
  ]
}
