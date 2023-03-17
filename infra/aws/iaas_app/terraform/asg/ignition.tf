terraform {
  required_providers {
    ignition = {
      source  = "community-terraform-providers/ignition"
      version = "2.1.3"
    }
  }
}

module "coreos_ssh_key" {
  source = "../../../terraform_modules/ssh_key_pair_with_secret"

  name = "${var.env_name}-${var.name}-coreos"
  tags = var.default_tags
}
data "ignition_user" "core" {
  name                = "core"
  ssh_authorized_keys = [module.coreos_ssh_key.key.public_key_openssh]
}

data "ignition_user" "outline" {
  name                = "outline"
  uid                 = 1001
}

resource "random_id" "secret_key" {
  byte_length = 32
}
resource "random_id" "util_secret_key" {
  byte_length = 32
}
data "ignition_file" "env" {
  path      = "/opt/outline/env"
  overwrite = true
  mode      = 448
  uid       = 1001
  gid       = 1001

  content {
    content = <<-EOT
    NODE_ENV=production
    SECRET_KEY=${random_id.secret_key.hex}
    UTILS_SECRET=${random_id.util_secret_key.hex}
    DATABASE_URL=postgres://${var.database_username}:${var.database_password}@${var.database_host}:5432/outline
    DATABASE_CONNECTION_POOL_MIN=1
    DATABASE_CONNECTION_POOL_MAX=5
    REDIS_URL=redis://${var.redis_host}
    URL=${var.outline_url}
    PORT=${var.port}
    FORCE_HTTPS=false
    AWS_S3_UPLOAD_BUCKET_NAME=ar.bucket_name
    OIDC_CLIENT_ID=ar.oidc_client_id
    OIDC_CLIENT_SECRET=ar.oidc_client_secret
    OIDC_AUTH_URI=ar.oidc_auth_url
    OIDC_TOKEN_URI=ar.oidc_token_uri
    OIDC_USERINFO_URI=ar.oidc_userinfo_uri
    OIDC_USERNAME_CLAIM=email
    EOT
  }
}

data "ignition_file" "ecr_login_script" {
  path      = "/opt/outline/ecr_login.sh"
  overwrite = true
  mode      = 448
  uid       = 1001
  gid       = 1001

  content {
    content = <<-EOT
    /bin/podman run --rm docker.io/amazon/aws-cli:latest ecr get-login-password \
    | podman login --username AWS --password-stdin ${var.outline_registry_domain}
    EOT
  }
}

data "ignition_file" "migrations_quadlet" {
  path      = "/home/outline/.config/containers/systemd/outline-migrations.container"
  overwrite = true
  mode      = 448
  uid       = 1001
  gid       = 1001

  content {
    content = <<-EOT
    [Unit]
    Description=Outline.js Migrations

    [Service]
    User=outline
    Environment=REGISTRY_AUTH_FILE=/opt/outline/ecr_auth
    ExecStartPre=-/usr/bin/bash /opt/outline/ecr_login.sh

    [Container]
    Image=${var.outline_container_image_uri}
    EnvironmentFile=/opt/outline/env
    Exec=yarn db:migrate

    [Install]
    WantedBy=multi-user.target
    EOT
  }
}

data "ignition_systemd_unit" "setup_system" {
  name    = "setup-system-for-outline.service"
  enabled = true

  content = <<-EOT
  [Unit]
  Description=Setup System for Outline.js
  Wants=network-online.target
  OnSuccess=setup-user-for-outline.service

  [Service]
  RemainAfterExit=no
  Type=oneshot
  ExecStart=/usr/bin/loginctl enable-linger outline
  ExecStartPost=/usr/bin/systemctl disable setup-system-for-outline.service
  ExecStartPost=/usr/bin/sleep 5

  [Install]
  WantedBy=multi-user.target
  EOT
}

data "ignition_systemd_unit" "setup_user" {
  name    = "setup-user-for-outline.service"
  enabled = false

  content = <<-EOT
  [Unit]
  Description=Setup user for Outline.js
  Wants=network-online.target

  [Service]
  User=outline
  RemainAfterExit=no
  Type=oneshot
  Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus
  Environment=XDG_RUNTIME_DIR=/run/user/1001
  ExecStart=/usr/bin/systemctl --user daemon-reload

  [Install]
  WantedBy=multi-user.target
  EOT
}

# data "ignition_systemd_unit" "migrations" {
#   name    = "outline-migrations.service"
#   enabled = false

#   content = <<-EOT
#   [Unit]
#   Description=Outline.js Migrations
#   Wants=network-online.target
#   OnSuccess=outline.service
#   RequiresMountsFor=/tmp/containers-user-1001/containers

#   [Service]
#   User=outline
#   RemainAfterExit=no
#   Type=forking
#   PIDFile=/tmp/outline-migrations-conmon.pid
#   Environment=PODMAN_SYSTEMD_UNIT=%n
#   ExecStartPre=-/usr/bin/bash /opt/outline/ecr_login.sh
#   ExecStartPre=-/bin/podman kill outline-migrations
#   ExecStartPre=-/bin/podman rm outline-migrations
#   ExecStartPre=/bin/podman pull ${var.outline_container_image_uri}
#   ExecStart=/bin/podman run --name outline-migrations --conmon-pidfile /tmp/outline-migrations-conmon.pid --env-file /opt/outline/env ${var.outline_container_image_uri} yarn db:migrate

#   [Install]
#   WantedBy=multi-user.target
#   EOT
# }

# data "ignition_systemd_unit" "main" {
#   name    = "outline.service"
#   enabled = false

#   content = <<-EOT
#   [Unit]
#   Description=Outline.js

#   [Service]
#   User=outline
#   Type=forking
#   PIDFile=/tmp/outline-conmon.pid
#   Environment=PODMAN_SYSTEMD_UNIT=%n
#   ExecStartPre=-/usr/bin/bash /opt/outline/ecr_login.sh
#   ExecStartPre=-/bin/podman kill outline
#   ExecStartPre=-/bin/podman rm outline
#   ExecStartPre=/bin/podman pull ${var.outline_container_image_uri}
#   ExecStart=/bin/podman run --name outline --conmon-pidfile /tmp/outline-conmon.pid --env-file /opt/outline/env --publish ${var.port}:${var.port} ${var.outline_container_image_uri}

#   [Install]
#   WantedBy=multi-user.target
#   EOT
# }

data "ignition_config" "main" {
  users = [
    data.ignition_user.core.rendered,
    data.ignition_user.outline.rendered
  ]
  files = [
    data.ignition_file.env.rendered,
    data.ignition_file.ecr_login_script.rendered,
    data.ignition_file.migrations_quadlet.rendered
  ]
  systemd = [
    data.ignition_systemd_unit.setup_system.rendered,
    data.ignition_systemd_unit.setup_user.rendered
  ]
}
