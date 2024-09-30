job "lldap" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "lldap" {
    network {
      mode = "bridge"
    }

    service {
      name = "lldap-webui"
      port = 17170
      task = "lldap"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.lldap.entrypoints=https",
        "traefik.http.routers.lldap.tls=true",
        "traefik.http.routers.lldap.rule=Host(`ldap.ednz.fr`)",
        "traefik.http.routers.lldap.tls.certresolver=cloudflare",
        "traefik.http.routers.lldap.middlewares=internal-acl@consulcatalog"
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
      name = "lldap-api"
      port = 3890
      task = "lldap"
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

    task "lldap" {
      driver = "docker"
      config {
        image = "ghcr.io/lldap/lldap:latest@sha256:ffcd02d33cc2911789f64b1e5c30b963fb9219e1f4b291b113b043a9218c755a"
      }
      template {
        data        = base64decode(var.lldap_lldap_env)
        destination = "secrets/lldap.env"
        env         = true
      }
      volume_mount {
        volume      = "lldap-data"
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
        volume      = "lldap-mariadb-data"
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
        volume      = "lldap-data"
        destination = "/backup-lldap-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "lldap-data" {
      type            = "csi"
      source          = "lldap-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "lldap-mariadb-data" {
      type            = "csi"
      source          = "lldap-mariadb-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }
}

variable "lldap_lldap_env" {
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
