job "flaresolverr" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "media"
  vault {
    policies = ["read_kv_hs"]
  }

  group "flaresolverr" {
    network {
      mode = "bridge"
    }

    service {
      name = "flaresolverr"
      port = 8191
      task = "flaresolverr"
      tags = [
        "traefik.enable=false",
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

    task "flaresolverr" {
      driver = "docker"
      config {
        image = "ghcr.io/flaresolverr/flaresolverr:v3.4.4"
      }
      template {
        data        = base64decode(var.flaresolverr_flaresolverr_env)
        destination = "secrets/flaresolverr.env"
        env         = true
      }
      resources {
        cpu    = 128
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

variable "flaresolverr_flaresolverr_env" {
  type = string
}

variable "logging_sidecar_promtail_yml" {
  type = string
}
