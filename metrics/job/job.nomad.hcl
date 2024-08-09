job "metrics" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "metrics" {
    network {
      mode = "bridge"
    }

    service {
      name = "prometheus"
      port = 9090
      task = "prometheus"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.entrypoints=https",
        "traefik.http.routers.prometheus.tls=true",
        "traefik.http.routers.prometheus.rule=Host(`prometheus.ednz.fr`)",
        "traefik.http.routers.prometheus.tls.certresolver=cloudflare",
        "traefik.http.routers.prometheus.middlewares=internal-acl@consulcatalog"
      ]
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
      name = "loki"
      port = 3100
      task = "loki"
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

    task "prometheus" {
      driver = "docker"
      config {
        image = "prom/prometheus:v2.54.0"
        args = [
          "--config.file=/secrets/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.console.libraries=/etc/prometheus/console_libraries",
          "--web.console.templates=/etc/prometheus/consoles",
          "--web.enable-lifecycle",
          "--storage.tsdb.retention.time=7d",
        ]
      }
      template {
        data        = base64decode(var.prometheus_prometheus_yml)
        destination = "secrets/prometheus.yml"
      }
      template {
        data        = base64decode(var.prometheus_ednz_ca_pem)
        destination = "secrets/ednz_ca.pem"
      }
      volume_mount {
        volume      = "prometheus-data"
        destination = "/prometheus"
      }
      resources {
        cpu    = 256
        memory = 512
      }
    }

    task "loki" {
      driver = "docker"
      config {
        image = "grafana/loki:latest@sha256:22caa5cdd21d227145acf3cca49db63898152ba470744e2b6962eed7c3469f9e"
        args = [
          "-config.file=/etc/loki/loki.yml"
        ]
        mount {
          type   = "bind"
          source = "secrets/loki.yml"
          target = "/etc/loki/loki.yml"
        }
      }
      template {
        data        = base64decode(var.loki_loki_yml)
        destination = "secrets/loki.yml"
      }
      volume_mount {
        volume      = "loki-data"
        destination = "/tmp/loki"
      }
      resources {
        cpu    = 256
        memory = 512
      }
    }

    volume "prometheus-data" {
      type            = "csi"
      source          = "prometheus-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "loki-data" {
      type            = "csi"
      source          = "loki-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }
}

variable "prometheus_prometheus_yml" {
  type = string
}

variable "prometheus_ednz_ca_pem" {
  type = string
}

variable "loki_loki_yml" {
  type = string
}
