resource "random_id" "secret_key" {
  byte_length = 32
}
resource "random_id" "util_secret_key" {
  byte_length = 32
}

resource "helm_release" "main" {
  depends_on = [
    aws_iam_role_policy_attachment.main
  ]

  name             = "outline"
  namespace        = "${local.env_name}-outline"
  create_namespace = true
  chart            = "../helm_chart/outline"
  wait             = false

  values = [
    <<-EOY
    image:
      repository: ${data.terraform_remote_state.cicd.outputs.outline_ecr_uri}
      tag: latest
    service:
      port: ${local.outline_port}
      type: NodePort
    ingress:
      className: alb
      annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/load-balancer-name: ${local.env_name}
        alb.ingress.kubernetes.io/group.name: ${local.env_name}
        alb.ingress.kubernetes.io/certificate-arn : ${data.terraform_remote_state.infra.outputs.prod.acm_cert_arn}
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
        alb.ingress.kubernetes.io/ssl-redirect: '443'
      hosts:
        - host: ${local.outline_dns_name}
          paths:
            - path: /
              pathType: Prefix
    nodeSelector:
        purpose: apps
    tolerations:
        - key: dedicated
          operator: Equal
          value: apps
          effect: NoSchedule
    cleanupJobSchedule: "0 2 * * *"
    config:
      secretKey: ${random_id.secret_key.hex}
      utilitySecretKey: ${random_id.util_secret_key.hex}
      databaseURL: postgres://${module.database.username}:${module.database.password}@${data.terraform_remote_state.infra.outputs.prod.database.address}:5432/outline
      redisURL: ${data.terraform_remote_state.infra.outputs.prod.redis.cache_nodes[0].address}
      baseURL: https://${local.outline_dns_name}
      port: ${local.outline_port}
      s3BucketName: ${aws_s3_bucket.main.id}
      oidcClientId: ${module.cognito_client.self.id}
      oidcClientSecret: ${module.cognito_client.self.client_secret}
      oidcAuthURI: ${data.terraform_remote_state.infra.outputs.prod.cognito.oauth_info["authorization_endpoint"]}
      oidcTokenURI: ${data.terraform_remote_state.infra.outputs.prod.cognito.oauth_info["token_endpoint"]}
      oidcUserInfoURI: ${data.terraform_remote_state.infra.outputs.prod.cognito.oauth_info["userinfo_endpoint"]}
      oidcUserNameClaim: email
    EOY
  ]
}