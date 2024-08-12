job "cloudflare-agent" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "cloudflare-agent" {
    network {
      mode = "bridge"
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
            cpu    = 125
            memory = 64
            memory_max = 128
          }
        }
      }
    }

    task "cloudflare-agent" {
      driver = "docker"
      config {
        image = "favonia/cloudflare-ddns:latest@sha256:03133f7889a9945d58beb1cfe82e1a9e17ba3e2e5ce4fdd3a81e0fdd213e3f11"
      }
      template {
        data        = base64decode(var.cloudflare_agent_cloudflare_agent_env)
        destination = "secrets/cloudflare-agent.env"
        env         = true
      }
      resources {
        cpu    = 64
        memory = 32
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
        cpu    = 100
        memory = 64
        memory_max = 128
      }
    }
  }
}

variable "cloudflare_agent_cloudflare_agent_env" {
  type = string
}

variable "logging_sidecar_promtail_yml" {
  type = string
}
