job "vaultwarden" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "vaultwarden" {
    network {
      mode = "bridge"
    }

    service {
      name = "vaultwarden"
      port = 80
      task = "vaultwarden"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vaultwarden.entrypoints=https",
        "traefik.http.routers.vaultwarden.tls=true",
        "traefik.http.routers.vaultwarden.rule=Host(`pw.ednz.fr`)",
        "traefik.http.routers.vaultwarden.tls.certresolver=cloudflare",
        "traefik.http.routers.vaultwarden-admin.entrypoints=https",
        "traefik.http.routers.vaultwarden-admin.tls=true",
        "traefik.http.routers.vaultwarden-admin.rule=Host(`pw.ednz.fr`) && PathPrefix(`/admin`)",
        "traefik.http.routers.vaultwarden-admin.middlewares=internal-acl@consulcatalog"
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

    task "vaultwarden" {
      driver = "docker"
      config {
        image = "vaultwarden/server:1.32.2"
      }
      template {
        data        = base64decode(var.vaultwarden_vaultwarden_env)
        destination = "secrets/vaultwarden.env"
        env         = true
      }
      volume_mount {
        volume      = "vaultwarden-data"
        destination = "/data"
      }
      resources {
        cpu    = 128
        memory = 256
      }
    }

    task "mariadb" {
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "linuxserver/mariadb:10.11.8"
      }
      template {
        data        = base64decode(var.mariadb_mariadb_env)
        destination = "secrets/mariadb.env"
        env         = true
      }
      volume_mount {
        volume      = "vaultwarden-mariadb-data"
        destination = "/config"
      }
      resources {
        cpu    = 128
        memory = 256
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
        volume      = "vaultwarden-data"
        destination = "/backup-vaultwarden-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "vaultwarden-data" {
      type            = "csi"
      source          = "vaultwarden-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "vaultwarden-mariadb-data" {
      type            = "csi"
      source          = "vaultwarden-mariadb-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }
}

variable "vaultwarden_vaultwarden_env" {
  type = string
}

variable "mariadb_mariadb_env" {
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
