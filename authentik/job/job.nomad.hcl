job "authentik" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "authentik" {
    network {
      mode = "bridge"
      port "authentik-exporter" {
        to = 9300
      }
      port "authentik-worker-exporter" {
        to = 9300
      }
    }

    service {
      name = "authentik"
      port = 9000
      task = "authentik"
      tags = [
        "traefik.enable=true",
        # authentik router setup
        "traefik.http.routers.authentik.entrypoints=https",
        "traefik.http.routers.authentik.tls=true",
        "traefik.http.routers.authentik.rule=Host(`auth.ednz.fr`) || HostRegexp(`{subdomain:[a-z0-9]+}.ednz.fr`) && PathPrefix(`/outpost.goauthentik.io/`)",
        "traefik.http.routers.authentik.tls.certresolver=cloudflare",
        # middleware definition
        "traefik.http.middlewares.authentik.forwardauth.address=http://localhost:9000/outpost.goauthentik.io/auth/traefik",
        "traefik.http.middlewares.authentik.forwardauth.trustForwardHeader=true",
        "traefik.http.middlewares.authentik.forwardauth.authResponseHeaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid,X-authentik-jwt,X-authentik-meta-jwks,X-authentik-meta-outpost,X-authentik-meta-provider,X-authentik-meta-app,X-authentik-meta-version",
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
      name = "authentik-exporter"
      port = "authentik-exporter"
      task = "authentik"
      tags = [
        "fr.ednz_cloud.prometheus.enable=true",
        "fr.ednz_cloud.prometheus.metrics_path=/metrics",
        "fr.ednz_cloud.prometheus.scrape_interval=15s",
      ]
    }

    service {
      name = "authentik-worker"
      port = 9000
      task = "authentik-worker"
      tags = [
        "traefik.enable=false",
      ]
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "lldap-api"
              local_bind_port  = 3890
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
      name = "authentik-worker-exporter"
      port = "authentik-worker-exporter"
      task = "authentik-worker"
      tags = [
        "fr.ednz_cloud.prometheus.enable=true",
        "fr.ednz_cloud.prometheus.metrics_path=/metrics",
        "fr.ednz_cloud.prometheus.scrape_interval=15s",
      ]
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

    task "authentik" {
      driver = "docker"
      config {
        image   = "ghcr.io/goauthentik/server:2025.10.0"
        command = "server"
        mount {
          type   = "bind"
          target = "/var/run/docker.sock"
          source = "/var/run/docker.sock"
        }
      }
      template {
        data        = base64decode(var.authentik_server_env)
        destination = "secrets/server.env"
        env         = true
      }
      volume_mount {
        volume      = "authentik-media-data"
        destination = "/media"
      }
      volume_mount {
        volume      = "authentik-templates-data"
        destination = "/templates"
      }
      resources {
        cpu    = 500
        memory = 1536
      }
    }

    task "authentik-worker" {
      driver = "docker"
      config {
        image   = "ghcr.io/goauthentik/server:2025.10.0"
        command = "worker"
        mount {
          type   = "bind"
          target = "/var/run/docker.sock"
          source = "/var/run/docker.sock"
        }
      }
      template {
        data        = base64decode(var.authentik_worker_client_env)
        destination = "secrets/client.env"
        env         = true
      }
      volume_mount {
        volume      = "authentik-media-data"
        destination = "/media"
      }
      volume_mount {
        volume      = "authentik-templates-data"
        destination = "/templates"
      }
      volume_mount {
        volume      = "authentik-certs-data"
        destination = "/certs"
      }
      resources {
        cpu        = 500
        memory     = 512
        memory_max = 1024
      }
    }

    task "redis" {
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "redis:8.2"
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
        volume      = "authentik-redis-data"
        destination = "/data"
      }
      resources {
        cpu    = 64
        memory = 128
      }
    }

    task "postgres" {
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "postgres:18.0"
      }
      template {
        data        = base64decode(var.postgres_postgres_env)
        destination = "secrets/postgres.env"
        env         = true
      }
      volume_mount {
        volume      = "authentik-postgres-data"
        destination = "/var/lib/postgresql/data"
      }
      resources {
        cpu    = 300
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
        volume      = "authentik-media-data"
        destination = "/backup-authentik-media-data"
      }
      volume_mount {
        volume      = "authentik-certs-data"
        destination = "/backup-authentik-certs-data"
      }
      volume_mount {
        volume      = "authentik-templates-data"
        destination = "/backup-authentik-templates-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "authentik-media-data" {
      type            = "csi"
      source          = "authentik-media-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "authentik-certs-data" {
      type            = "csi"
      source          = "authentik-certs-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "authentik-templates-data" {
      type            = "csi"
      source          = "authentik-templates-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "authentik-postgres-data" {
      type            = "csi"
      source          = "authentik-postgres-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "authentik-redis-data" {
      type            = "csi"
      source          = "authentik-redis-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }
}

variable "authentik_server_env" {
  type = string
}

variable "authentik_worker_client_env" {
  type = string
}

variable "redis_redis_env" {
  type = string
}

variable "postgres_postgres_env" {
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
