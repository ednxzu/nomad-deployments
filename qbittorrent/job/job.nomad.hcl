job "qbittorrent" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "media"
  vault {
    policies = ["read_kv_hs"]
  }

  group "qbittorrent" {
    network {
      mode = "bridge"
      port "qbt-tcp-udp" {
        to = 6881
      }
    }

    service {
      name = "qbittorrent"
      port = 7080
      task = "qbittorrent"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.qbittorrent.entrypoints=https",
        "traefik.http.routers.qbittorrent.tls=true",
        "traefik.http.routers.qbittorrent.rule=Host(`download.ednz.fr`)",
        "traefik.http.routers.qbittorrent.tls.certresolver=cloudflare",
        "traefik.http.services.qbittorrent.loadbalancer.passhostheader=false",
        "traefik.http.routers.qbittorrent.middlewares=internal-acl@consulcatalog,authentik@consulcatalog"
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

    task "wireguard" {
      driver = "docker"
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }
      config {
        image = "linuxserver/wireguard:latest@sha256:d83e18ec0b430ef6f7151d32e49e9f07f49162cbca8db738eee28ad43999fdd6"
        ports = ["qbt-tcp-udp"]
        cap_add = [
          "NET_ADMIN"
        ]
        sysctl = {
          "net.ipv4.conf.all.src_valid_mark" = 1
        }
        mount {
          type   = "bind"
          source = "secrets/wg0.conf"
          target = "/config/wg0.conf"
        }
      }
      template {
        data        = base64decode(var.wireguard_wireguard_env)
        destination = "secrets/wireguard.env"
        env         = true
      }
      template {
        data        = base64decode(var.wireguard_wg0_conf)
        destination = "secrets/wg0.conf"
      }
      resources {
        cpu    = 128
        memory = 128
      }
    }

    task "qbittorrent" {
      driver = "docker"
      config {
        image        = "linuxserver/qbittorrent:latest@sha256:dc9e13d2edab18cc7c42367526182b2798f9f0f4c590559337f954fb4e3bdc35"
        network_mode = "container:wireguard-${NOMAD_ALLOC_ID}"
        cap_add = [
          "NET_ADMIN"
        ]
      }
      template {
        data        = base64decode(var.qbittorrent_qbittorrent_env)
        destination = "secrets/qbittorrent.env"
        env         = true
      }
      template {
        data        = base64decode(var.qbittorrent_qbittorrent_conf)
        destination = "local/qBittorrent.conf"
      }
      volume_mount {
        volume      = "qbittorrent-data"
        destination = "/config"
      }
      volume_mount {
        volume      = "nfs-media-downloads"
        destination = "/data"
      }
      resources {
        cpu        = 512
        memory     = 386
        memory_max = 768
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
      volume_mount {
        volume      = "qbittorrent-data"
        destination = "/opt/qbittorrent-logs"
        read_only   = true
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
        volume      = "qbittorrent-data"
        destination = "/backup-qbittorrent-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "qbittorrent-data" {
      type            = "csi"
      source          = "qbittorrent-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
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

variable "wireguard_wireguard_env" {
  type = string
}

variable "wireguard_wg0_conf" {
  type = string
}

variable "qbittorrent_qbittorrent_env" {
  type = string
}

variable "qbittorrent_qbittorrent_conf" {
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
