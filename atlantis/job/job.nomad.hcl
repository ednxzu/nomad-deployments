job "atlantis" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "core"
  vault {
    policies = ["administrator"]
  }

  group "atlantis" {
    network {
      mode = "bridge"
    }

    service {
      name = "atlantis"
      port = 4141
      task = "atlantis"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.atlantis.entrypoints=https",
        "traefik.http.routers.atlantis.tls=true",
        "traefik.http.routers.atlantis.rule=Host(`atlantis.ednz.fr`)",
        "traefik.http.routers.atlantis.tls.certresolver=cloudflare",
        "traefik.http.routers.atlantis.middlewares=internal-acl@consulcatalog" # authentik@consulcatalog
      ]
      connect {
        sidecar_service {}
        sidecar_task {
          resources {
            cpu        = 125
            memory     = 64
            memory_max = 128
          }
        }
      }
    }

    service {
      name = "logging-sidecar"
      port = 9080
      task = "logging-sidecar"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "loki"
              local_bind_port  = 3100
            }
          }
        }
        sidecar_task {
          resources {
            cpu        = 125
            memory     = 64
            memory_max = 128
          }
        }
      }
    }

    task "bootstrap" {
      driver = "docker"
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      config {
        image      = "alpine:3.23"
        entrypoint = ["${NOMAD_TASK_DIR}/entrypoint.sh"]
      }
      template {
        data        = base64decode(var.bootstrap_bootstrap_env)
        destination = "secrets/bootstrap.env"
        env         = true
      }
      template {
        data        = base64decode(var.bootstrap_entrypoint_sh)
        destination = "local/entrypoint.sh"
        perms       = "755"
      }
      resources {
        cpu    = 128
        memory = 256
      }
    }

    task "atlantis" {
      driver = "docker"
      config {
        image   = "ghcr.io/runatlantis/atlantis:v0.39.0"
        command = "server"
        args = [
          "--atlantis-url=${ATLANTIS_URL}",
          "--gitea-base-url=https://git.ednz.fr",
          "--gitea-user=${GITEA_USERNAME}",
          "--gitea-token=${GITEA_TOKEN}",
          "--gitea-webhook-secret=${GITEA_WEBHOOK_SECRET}",
          "--gitea-page-size=30",
          "--repo-allowlist=${GITEA_REPO_ALLOWLIST}",
          "--repo-config=/secrets/repos.yaml"
        ]
      }
      template {
        data        = base64decode(var.atlantis_atlantis_env)
        destination = "secrets/atlantis.env"
        env         = true
      }
      template {
        data        = base64decode(var.atlantis_repos_yaml)
        destination = "secrets/repos.yaml"
      }
      template {
        data        = base64decode(var.atlantis_ednz_ca_pem)
        destination = "secrets/ednz_ca.pem"
      }
      resources {
        cpu    = 256
        memory = 512
      }
    }

    task "logging-sidecar" {
      lifecycle {
        hook    = "poststart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "grafana/promtail:latest"
        args = [
          "-config.file=/etc/promtail/promtail.yml"
        ]
        mount {
          type   = "bind"
          source = "secrets/promtail.yml"
          target = "/etc/promtail/promtail.yml"
        }
        mount {
          type     = "bind"
          source   = "/opt/nomad/alloc/${NOMAD_ALLOC_ID}/alloc/logs"
          target   = "/opt/logs"
          readonly = true
        }
      }
      template {
        data        = base64decode(var.logging_sidecar_promtail_yml)
        destination = "secrets/promtail.yml"
      }
      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }
}

variable "atlantis_atlantis_env" {
  type = string
}

variable "atlantis_repos_yaml" {
  type = string
}

variable "atlantis_ednz_ca_pem" {
  type = string
}

variable "bootstrap_bootstrap_env" {
  type = string
}

variable "bootstrap_entrypoint_sh" {
  type = string
}

variable "logging_sidecar_promtail_yml" {
  type = string
}
