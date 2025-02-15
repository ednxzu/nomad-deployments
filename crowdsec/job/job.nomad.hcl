job "crowdsec" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "crowdsec" {
    network {
      mode = "bridge"
      port "prometheus-exporter" {
        to = 6060
      }
    }

    service {
      name = "crowdsec-api"
      port = 8080
      task = "crowdsec-api"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "loki"
              local_bind_port  = 3101
            }
          }
        }
      }
    }

    service {
      name = "crowdsec-bouncer-traefik"
      port = 8081
      task = "crowdsec-bouncer-traefik"
      connect {
        sidecar_service {}
      }
    }

    service {
      name = "crowdsec-exporter"
      port = "prometheus-exporter"
      task = "crowdsec-api"
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
      }
    }

    task "crowdsec-api" {
      driver = "docker"
      config {
        image = "crowdsecurity/crowdsec:v1.6.5"
        mount {
          type   = "bind"
          source = "local/acquis-loki.yaml"
          target = "/etc/crowdsec/acquis.d/acquis-loki.yaml"
        }
        mount {
          type   = "bind"
          source = "local/config.yaml"
          target = "/etc/crowdsec/config.yaml"
        }
      }
      template {
        data        = base64decode(var.crowdsec_api_crowdsec_api_env)
        destination = "secrets/crowdsec-api.env"
        env         = true
      }
      template {
        data        = base64decode(var.crowdsec_api_config_yaml)
        destination = "local/config.yaml"
        change_mode = "noop"
      }
      template {
        data        = base64decode(var.crowdsec_api_acquis_loki_yaml)
        destination = "local/acquis-loki.yaml"
      }
      volume_mount {
        volume      = "crowdsec-api-config"
        destination = "/etc/crowdsec"
      }
      volume_mount {
        volume      = "crowdsec-api-data"
        destination = "/var/lib/crowdsec/data"
      }
      resources {
        cpu    = 256
        memory = 512
      }
    }

    task "crowdsec-bouncer-traefik" {
      driver = "docker"
      config {
        image = "fbonalair/traefik-crowdsec-bouncer:0.5"
      }
      template {
        data        = base64decode(var.crowdsec_bouncer_traefik_crowdsec_bouncer_traefik_env)
        destination = "secrets/crowdsec-bouncer-traefik.env"
        env         = true
      }
      resources {
        cpu    = 256
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
        cpu    = 100
        memory = 128
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
        volume      = "crowdsec-api-config"
        destination = "/backup-crowdsec-api-config"
      }
      volume_mount {
        volume      = "crowdsec-api-data"
        destination = "/backup-crowdsec-api-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "crowdsec-api-config" {
      type            = "csi"
      source          = "crowdsec-api-config"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "crowdsec-api-data" {
      type            = "csi"
      source          = "crowdsec-api-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }
}

variable "crowdsec_api_crowdsec_api_env" {
  type = string
}

variable "crowdsec_api_config_yaml" {
  type = string
}

variable "crowdsec_api_acquis_loki_yaml" {
  type = string
}

variable "crowdsec_bouncer_traefik_crowdsec_bouncer_traefik_env" {
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
