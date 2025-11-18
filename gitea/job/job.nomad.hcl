job "gitea" {
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
      name = "gitea-redis"
      port = 6379
      task = "redis"
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
      name = "gitea-mariadb"
      port = 3306
      task = "mariadb"
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

    task "mariadb" {
      driver = "docker"
      config {
        image = "linuxserver/mariadb:11.4.8"
      }
      template {
        data        = base64decode(var.mariadb_mariadb_env)
        destination = "secrets/mariadb.env"
        env         = true
      }
      volume_mount {
        volume      = "gitea-mariadb-data"
        destination = "/config"
      }
      resources {
        cpu    = 384
        memory = 1024
      }
    }

    task "redis" {
      driver = "docker"
      config {
        image = "redis:8.4"
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
        volume      = "gitea-redis-data"
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
        volume      = "gitea-data"
        destination = "/backup-gitea-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "gitea-data" {
      type            = "csi"
      source          = "gitea-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "gitea-mariadb-data" {
      type            = "csi"
      source          = "gitea-mariadb-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "gitea-redis-data" {
      type            = "csi"
      source          = "gitea-redis-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }

  group "gitea" {
    network {
      mode = "bridge"
      port "gitea-ssh" {
        to = 22
      }
    }

    service {
      name = "gitea"
      port = 3000
      task = "gitea"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.gitea.entrypoints=https",
        "traefik.http.routers.gitea.tls=true",
        "traefik.http.routers.gitea.rule=Host(`git.ednz.fr`)",
        "traefik.http.routers.gitea.tls.certresolver=cloudflare"
      ]
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "gitea-redis"
              local_bind_port  = 6379
            }
            upstreams {
              destination_name = "gitea-mariadb"
              local_bind_port  = 3306
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
      name = "gitea-ssh"
      port = "gitea-ssh"
      task = "gitea"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.gitea-ssh.entrypoints=gitea-ssh",
        "traefik.tcp.routers.gitea-ssh.rule=HostSNI(`*`)",
        "traefik.tcp.routers.gitea-ssh.priority=100",
        "traefik.tcp.routers.gitea-ssh.service=gitea-ssh",
        "traefik.tcp.routers.gitea-ssh.tls=false",
        "traefik.tcp.services.gitea-ssh.loadbalancer.server.port=${NOMAD_HOST_PORT_gitea_ssh}"
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

    task "gitea" {
      driver = "docker"
      config {
        image = "gitea/gitea:1.25"
      }
      template {
        data        = base64decode(var.gitea_gitea_env)
        destination = "secrets/gitea.env"
        env         = true
      }
      volume_mount {
        volume      = "gitea-data"
        destination = "/data"
      }
      resources {
        cpu    = 768
        memory = 1536
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

    volume "gitea-data" {
      type            = "csi"
      source          = "gitea-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }
  }
}

variable "gitea_gitea_env" {
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
