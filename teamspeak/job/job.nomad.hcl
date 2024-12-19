job "teamspeak" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 50
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "teamspeak" {
    network {
      mode = "bridge"
      port "teamspeak-voice" {
        to = 9987
      }
      port "teamspeak-file" {
        to = 30033
      }
      port "teamspeak-admin" {
        to = 10011
      }
    }

    service {
      name     = "teamspeak-voice"
      port     = "teamspeak-voice"
      provider = "nomad"
      tags = [
        "traefik.enable=true",
        "traefik.udp.routers.teamspeak-voice.entrypoints=teamspeak-voice",
        "traefik.udp.routers.teamspeak-voice.service=teamspeak-voice"
      ]
    }

    service {
      name     = "teamspeak-file"
      port     = "teamspeak-file"
      provider = "nomad"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.teamspeak-file.entrypoints=teamspeak-file",
        "traefik.tcp.routers.teamspeak-file.rule=HostSNI(`*`)",
        "traefik.tcp.routers.teamspeak-file.service=teamspeak-file",
        "traefik.tcp.routers.teamspeak-file.tls=false"
      ]
    }

    task "teamspeak" {
      driver = "docker"
      config {
        image = "ich777/teamspeak:latest@sha256:261520b08eea32a6ecad19d6fdd77ff071d408b5a47c6f65971da07f20c9fc86"
        ports = ["teamspeak-admin"]
      }
      template {
        data        = base64decode(var.teamspeak_teamspeak_env)
        destination = "secrets/teamspeak.env"
        env         = true
      }
      volume_mount {
        volume      = "teamspeak-data"
        destination = "/teamspeak"
      }
      resources {
        cpu    = 128
        memory = 256
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
        volume      = "teamspeak-data"
        destination = "/backup-teamspeak-data"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "teamspeak-data" {
      type            = "csi"
      source          = "teamspeak-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

  }
}

variable "teamspeak_teamspeak_env" {
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
