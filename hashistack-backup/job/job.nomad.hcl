job "hashistack-backup" {
  datacenters = ["gre1"]
  type        = "batch"
  priority    = 90
  namespace   = "maintenance"
  vault {
    policies = ["read_kv_hs"]
  }

  periodic {
    cron      = "@daily"
    time_zone = "Europe/Paris"
  }

  group "hashistack-backup" {
    task "consul-backup" {
      driver = "exec"
      config {
        pid_mode = "host"
        ipc_mode = "host"
        command  = "/usr/bin/consul"
        args     = ["snapshot", "save", "/backup/consul.bkp"]
      }
      template {
        data        = base64decode(var.consul_backup_consul_backup_env)
        destination = "local/consul-backup.env"
        env         = true
      }
      volume_mount {
        volume      = "hashistack-backup-data"
        destination = "/backup"
      }
    }

    task "nomad-backup" {
      driver = "exec"
      config {
        pid_mode = "host"
        ipc_mode = "host"
        command  = "/usr/bin/nomad"
        args     = ["operator", "snapshot", "save", "/backup/nomad.bkp"]
      }
      template {
        data        = base64decode(var.nomad_backup_nomad_backup_env)
        destination = "local/nomad-backup.env"
        env         = true
      }
      volume_mount {
        volume      = "hashistack-backup-data"
        destination = "/backup"
      }
    }

    task "vault-backup" {
      driver = "exec"
      config {
        pid_mode = "host"
        ipc_mode = "host"
        command  = "/usr/bin/vault"
        args     = ["operator", "raft", "snapshot", "save", "/backup/vault.bkp"]
      }
      template {
        data        = base64decode(var.vault_backup_vault_backup_env)
        destination = "local/vault-backup.env"
        env         = true
      }
      volume_mount {
        volume      = "hashistack-backup-data"
        destination = "/backup"
      }
    }

    task "hashistack-cleanup" {
      driver = "exec"
      lifecycle {
        hook = "prestart"
      }
      config {
        pid_mode = "host"
        ipc_mode = "host"
        command  = "/usr/bin/rm"
        args     = ["-rf", "/backup/nomad.bkp", "||", "true"]
      }
      volume_mount {
        volume      = "hashistack-backup-data"
        destination = "/backup"
      }
    }

    task "borg-sidecar" {
      lifecycle {
        hook    = "poststop"
        sidecar = true
      }
      driver = "docker"
      config {
        image      = "ghcr.io/borgmatic-collective/borgmatic:1.8.13"
        entrypoint = ["borgmatic"]
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
        volume      = "hashistack-backup-data"
        destination = "/backup"
      }
      resources {
        cpu        = 200
        memory     = 20
        memory_max = 128
      }
    }

    volume "hashistack-backup-data" {
      type            = "csi"
      source          = "hashistack-backup-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }
}

variable "consul_backup_consul_backup_env" {
  type = string
}

variable "nomad_backup_nomad_backup_env" {
  type = string
}

variable "vault_backup_vault_backup_env" {
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
