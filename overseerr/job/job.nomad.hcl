job "overseerr" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "media"
  vault {
    policies = ["read_kv_hs"]
  }

  group "overseerr" {
    network {
      mode = "bridge"
    }

    service {
      name = "overseerr"
      port = 5055
      task = "overseerr"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.overseerr.entrypoints=https",
        "traefik.http.routers.overseerr.tls=true",
        "traefik.http.routers.overseerr.rule=Host(`requests.ednz.fr`)",
        "traefik.http.routers.overseerr.tls.certresolver=cloudflare"
      ]
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "radarr"
              local_bind_port  = 7878
            }
            upstreams {
              destination_name = "sonarr"
              local_bind_port  = 8989
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

    task "overseerr" {
      driver = "docker"
      config {
        image = "linuxserver/overseerr@sha256:24c902e4091f442aae63931663e4eaf95bb2c8a345a66936c2f6b81b281a4c3b"
      }
      template {
        data        = base64decode(var.overseerr_overseerr_env)
        destination = "secrets/overseerr.env"
        env         = true
      }
      volume_mount {
        volume      = "overseerr-data"
        destination = "/config"
      }
      resources {
        cpu        = 256
        memory     = 256
        memory_max = 512
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

    task "borg-sidecar" {
      lifecycle {
        hook    = "poststart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "ghcr.io/borgmatic-collective/borgmatic:latest"
        mount {
          type     = "bind"
          source   = "local/config.yaml"
          target   = "/etc/borgmatic.d/config.yaml"
          readonly = true
        }
        mount {
          type     = "bind"
          source   = "local/crontab.txt"
          target   = "/etc/borgmatic.d/crontab.txt"
          readonly = true
        }
        mount {
          type     = "bind"
          source   = "local/id_borg"
          target   = "/root/.ssh/id_borg"
          readonly = true
        }
        mount {
          type     = "bind"
          source   = "local/known_hosts"
          target   = "/root/.ssh/known_hosts"
          readonly = true
        }
      }
      template {
        data        = base64decode(var.borg_sidecar_borg_sidecar_env)
        destination = "local/borg-sidecar.env"
        env         = true
      }
      template {
        data        = base64decode(var.borg_sidecar_config_yaml)
        change_mode = "noop"
        destination = "local/config.yaml"
      }
      template {
        data        = base64decode(var.borg_sidecar_crontab_txt)
        change_mode = "noop"
        destination = "local/crontab.txt"
      }
      template {
        data        = base64decode(var.borg_sidecar_id_borg)
        perms       = "0600"
        change_mode = "noop"
        destination = "local/id_borg"
      }
      template {
        data        = base64decode(var.borg_sidecar_known_hosts)
        change_mode = "noop"
        destination = "local/known_hosts"
      }
      volume_mount {
        volume      = "overseerr-data"
        destination = "/backup-overseerr-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "overseerr-data" {
      type            = "csi"
      source          = "overseerr-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }
}

variable "overseerr_overseerr_env" {
  type = string
}

variable "logging_sidecar_promtail_yml" {
  type = string
}

variable "borg_sidecar_borg_sidecar_env" {
  type = string
}

variable "borg_sidecar_config_yaml" {
  type = string
}

variable "borg_sidecar_crontab_txt" {
  type = string
}

variable "borg_sidecar_id_borg" {
  type = string
}

variable "borg_sidecar_known_hosts" {
  type = string
}
