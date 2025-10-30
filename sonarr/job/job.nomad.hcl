job "sonarr" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "media"
  vault {
    policies = ["read_kv_hs"]
  }

  group "sonarr" {
    network {
      mode = "bridge"
    }

    service {
      name = "sonarr"
      port = 8989
      task = "sonarr"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.sonarr.entrypoints=https",
        "traefik.http.routers.sonarr.tls=true",
        "traefik.http.routers.sonarr.rule=Host(`sonarr.ednz.fr`)",
        "traefik.http.routers.sonarr.tls.certresolver=cloudflare",
        "traefik.http.routers.sonarr.middlewares=internal-acl@consulcatalog,authentik@consulcatalog"
      ]
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "prowlarr"
              local_bind_port  = 9696
            }
            upstreams {
              destination_name = "qbittorrent"
              local_bind_port  = 8080
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

    task "sonarr" {
      driver = "docker"
      config {
        image = "linuxserver/sonarr:develop@sha256:20dcec9a594682bc1d4f2b56959bf8b1c0607492f7853ce41108e4ddb08c4c35"
      }
      template {
        data        = base64decode(var.sonarr_sonarr_env)
        destination = "secrets/sonarr.env"
        env         = true
      }
      volume_mount {
        volume      = "sonarr-data"
        destination = "/config"
      }
      volume_mount {
        volume      = "nfs-media-tv"
        destination = "/tv"
      }
      volume_mount {
        volume      = "nfs-media-downloads"
        destination = "/data"
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
        volume      = "sonarr-data"
        destination = "/backup-sonarr-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "sonarr-data" {
      type            = "csi"
      source          = "sonarr-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "nfs-media-tv" {
      type            = "csi"
      source          = "nfs-media-tv"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "nfs-media-downloads" {
      type            = "csi"
      source          = "nfs-media-downloads"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }
  }
}

variable "sonarr_sonarr_env" {
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
