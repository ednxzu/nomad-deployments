job "resume" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "resume" {
    network {
      mode = "bridge"
    }

    count = 2
    update {
      max_parallel = 1
      canary       = 1
      health_check = "task_states"
      auto_promote = true
    }

    service {
      name = "resume"
      port = 8080
      task = "resume"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.resume.entrypoints=https",
        "traefik.http.routers.resume.tls=true",
        "traefik.http.routers.resume.rule=Host(`bertrand.ednz.fr`)",
        "traefik.http.routers.resume.tls.certresolver=cloudflare"
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

    task "resume" {
      driver = "docker"
      config {
        image = "git.ednz.fr/ednz-cloud/resume:latest"
      }
      template {
        data        = base64decode(var.resume_resume_env)
        destination = "secrets/resume.env"
        env         = true
      }
      resources {
        cpu    = 50
        memory = 64
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

variable "resume_resume_env" {
  type = string
}

variable "logging_sidecar_promtail_yml" {
  type = string
}
