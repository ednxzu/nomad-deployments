job "authelia" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "databases" {
    network {
      mode = "bridge"
    }

    service {
      name = "authelia-redis"
      port = 6379
      task = "redis"
      connect {
        sidecar_service {}
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
      name = "authelia-mariadb"
      port = 3306
      task = "mariadb"
      connect {
        sidecar_service {}
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

    task "mariadb" {
      driver = "docker"
      config {
        image = "linuxserver/mariadb:latest"
      }
      template {
        data        = base64decode(var.mariadb_mariadb_env)
        destination = "secrets/mariadb.env"
        env         = true
      }
      volume_mount {
        volume      = "authelia-mariadb-data"
        destination = "/config"
      }
      resources {
        cpu    = 128
        memory = 256
      }
    }

    task "redis" {
      driver = "docker"
      config {
        image = "redis:alpine"
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
        volume      = "authelia-redis-data"
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
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "authelia-mariadb-data" {
      type            = "csi"
      source          = "authelia-mariadb-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "authelia-redis-data" {
      type            = "csi"
      source          = "authelia-redis-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }

  group "authelia" {
    network {
      mode = "bridge"
    }

    count = 2
    update {
      max_parallel = 1
      canary = 1
      health_check = "task_states"
      auto_promote = true
    }

    service {
      name = "authelia"
      port = 9091
      task = "authelia"
      tags = [
        "traefik.enable=true",
        # authelia router setup
        "traefik.http.routers.authelia.entrypoints=https",
        "traefik.http.routers.authelia.tls=true",
        "traefik.http.routers.authelia.rule=Host(`auth.ednz.fr`)",
        "traefik.http.routers.authelia.tls.certresolver=cloudflare",
        # middleware definition
        "traefik.http.middlewares.authelia.forwardauth.address=http://localhost:9091/api/verify?rd=https://auth.ednz.fr/",
        "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true",
        "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User, Remote-Groups, Remote-Name, Remote-Email",
      ]
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "lldap-api"
              local_bind_port  = 3890
            }
            upstreams {
              destination_name = "authelia-redis"
              local_bind_port  = 6379
            }
            upstreams {
              destination_name = "authelia-mariadb"
              local_bind_port  = 3306
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

    task "authelia" {
      driver = "docker"
      config {
        image   = "authelia/authelia:latest"
        command = "authelia"
        args = [
          "--config=/secrets/configuration.yml",
          "--config=/secrets/acl.yml",
          "--config=/secrets/oidc.yml"
        ]
      }
      template {
        data        = base64decode(var.authelia_authelia_env)
        destination = "secrets/authelia.env"
        env         = true
      }
      template {
        data        = base64decode(var.authelia_configuration_yml)
        destination = "secrets/configuration.yml"
      }
      template {
        data        = base64decode(var.authelia_acl_yml)
        destination = "secrets/acl.yml"
      }
      template {
        data        = base64decode(var.authelia_oidc_yml)
        destination = "secrets/oidc.yml"
      }
      template {
        data        = base64decode(var.authelia_oidc_private_key)
        destination = "secrets/oidc_private_key"
      }
      resources {
        cpu    = 256
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
        cpu    = 100
        memory = 64
        memory_max = 128
      }
    }
  }
}

variable "authelia_authelia_env" {
  type = string
}

variable "authelia_configuration_yml" {
  type = string
}

variable "authelia_acl_yml" {
  type = string
}

variable "authelia_oidc_yml" {
  type = string
}

variable "authelia_oidc_private_key" {
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
