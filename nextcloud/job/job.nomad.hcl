job "nextcloud" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "nextcloud" {
    network {
      mode = "bridge"
    }

    service {
      name = "nextcloud"
      port = 80
      task = "nextcloud"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nextcloud.entrypoints=https",
        "traefik.http.routers.nextcloud.tls=true",
        "traefik.http.routers.nextcloud.rule=Host(`drive.ednz.fr`)",
        "traefik.http.routers.nextcloud.middlewares=nextcloud_redirectregex,nextcloud_headers",
        "traefik.http.routers.nextcloud.tls.certresolver=cloudflare",
        "traefik.http.services.nextcloud.loadbalancer.server.scheme=https",
        "traefik.http.services.nextcloud.loadbalancer.passhostheader=true",
        "traefik.http.middlewares.nextcloud_redirectregex.redirectregex.permanent=true",
        "traefik.http.middlewares.nextcloud_redirectregex.redirectregex.regex='https://(.*)/.well-known/(?:card|cal)dav'",
        "traefik.http.middlewares.nextcloud_redirectregex.redirectregex.replacement='https://$${1}/remote.php/dav'",
        "traefik.http.middlewares.nextcloud_headers.headers.referrerPolicy=no-referrer",
        "traefik.http.middlewares.nextcloud_headers.headers.SSLRedirect=true",
        "traefik.http.middlewares.nextcloud_headers.headers.STSSeconds=315360000",
        "traefik.http.middlewares.nextcloud_headers.headers.browserXSSFilter=true",
        "traefik.http.middlewares.nextcloud_headers.headers.contentTypeNosniff=true",
        "traefik.http.middlewares.nextcloud_headers.headers.forceSTSHeader=true",
        "traefik.http.middlewares.nextcloud_headers.headers.STSIncludeSubdomains=true",
        "traefik.http.middlewares.nextcloud_headers.headers.STSPreload=true",
        "traefik.http.middlewares.nextcloud_headers.headers.customFrameOptionsValue=SAMEORIGIN",
      ]
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "lldap-api"
              local_bind_port  = 3890
            }
            upstreams {
              destination_name = "smtp"
              local_bind_port  = 25
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

    task "nextcloud" {
      driver = "docker"
      config {
        image = "nextcloud:30"
      }
      template {
        data        = base64decode(var.nextcloud_nextcloud_env)
        destination = "secrets/nextcloud.env"
        env         = true
      }
      volume_mount {
        volume      = "nextcloud-config"
        destination = "/var/www/html"
      }
      volume_mount {
        volume      = "nextcloud-data"
        destination = "/data"
      }
      resources {
        cpu    = 512
        memory = 1024
      }
    }

    task "nextcloud_cron" {
      lifecycle {
        hook    = "poststart"
        sidecar = true
      }
      driver = "docker"
      config {
        image      = "nextcloud:30"
        entrypoint = ["/cron.sh"]
      }
      template {
        data        = base64decode(var.nextcloud_nextcloud_env)
        destination = "secrets/nextcloud.env"
        env         = true
      }
      volume_mount {
        volume      = "nextcloud-config"
        destination = "/var/www/html"
      }
      volume_mount {
        volume      = "nextcloud-data"
        destination = "/data"
      }
      resources {
        cpu    = 512
        memory = 512
      }
    }

    task "mariadb" {
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "linuxserver/mariadb:10.11.10"
      }
      template {
        data        = base64decode(var.mariadb_mariadb_env)
        destination = "secrets/mariadb.env"
        env         = true
      }
      volume_mount {
        volume      = "nextcloud-mariadb-data"
        destination = "/config"
      }
      resources {
        cpu    = 128
        memory = 512
      }
    }

    task "redis" {
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "redis:7.4"
        args = [
          "--requirepass $${REDIS_PASSWORD}",
        ]
      }
      template {
        data        = base64decode(var.redis_redis_env)
        destination = "secrets/redis.env"
        env         = true
      }
      volume_mount {
        volume      = "nextcloud-redis-data"
        destination = "/data"
      }
      resources {
        cpu    = 64
        memory = 128
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
        volume      = "nextcloud-config"
        destination = "/backup-nextcloud-config"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "nextcloud-config" {
      type            = "csi"
      source          = "nextcloud-config"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "nextcloud-data" {
      type            = "csi"
      source          = "nextcloud-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "nextcloud-mariadb-data" {
      type            = "csi"
      source          = "nextcloud-mariadb-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "nextcloud-redis-data" {
      type            = "csi"
      source          = "nextcloud-redis-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

  }
}

variable "nextcloud_nextcloud_env" {
  type = string
}

variable "mariadb_mariadb_env" {
  type = string
}

variable "redis_redis_env" {
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
