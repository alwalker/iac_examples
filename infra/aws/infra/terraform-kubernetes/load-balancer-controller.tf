module "vpc_ingress_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.infra.outputs.eks.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.default_tags
}

resource "helm_release" "load-balancer-controller" {
  depends_on = [
    module.vpc_ingress_irsa
  ]

  name       = "load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "serviceAccount.name"
    value = "load-balancer-controller"
  }
  set {
    name = "clusterName"
    value = data.terraform_remote_state.infra.outputs.eks.eks.cluster_name
  }
}

resource "helm_release" "nginx" {
  name       = "nginx"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"

  values = [
    <<-EOY
    ingress:
        enabled: true
        hostname: balls.com
        ingressClassName: alb
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
