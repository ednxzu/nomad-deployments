locals {
  jobs = {
    hashistack-backup = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    hashistack-backup = {
      consul_backup_consul_backup_env = base64encode(file("${path.module}/job/config/consul-backup/consul-backup.env"))
      nomad_backup_nomad_backup_env   = base64encode(file("${path.module}/job/config/nomad-backup/nomad-backup.env"))
      vault_backup_vault_backup_env   = base64encode(file("${path.module}/job/config/vault-backup/vault-backup.env"))
      borg_sidecar_borg_sidecar_env   = base64encode(file("${path.module}/job/config/borg-sidecar/borg-sidecar.env"))
      borg_sidecar_config_yaml        = base64encode(file("${path.module}/job/config/borg-sidecar/config.yaml"))
      borg_sidecar_crontab_txt        = base64encode(file("${path.module}/../_templates/borg-sidecar/crontab.txt"))
      borg_sidecar_id_borg            = base64encode(file("${path.module}/../_templates/borg-sidecar/id_borg"))
      borg_sidecar_known_hosts        = base64encode(file("${path.module}/../_templates/borg-sidecar/known_hosts"))
    }
  }

  volumes = {
    hashistack-backup-data = {
      plugin_id    = "ceph-csi-rbd"
      namespace    = "maintenance"
      capacity_min = "954 MiB"
      capacity_max = "954 MiB"
      capability = {
        access_mode     = "single-node-writer"
        attachment_mode = "file-system"
      }
      secrets = {
        userID  = module.credentials_ceph_csi_rbd.ceph_csi_rbd_user_id
        userKey = module.credentials_ceph_csi_rbd.ceph_csi_rbd_user_key
      }
      parameters = {
        clusterID     = module.credentials_ceph_csi_rbd.ceph_csi_cluster_id
        pool          = "nomad"
        imageFeatures = "layering"
      }
    }
  }

  nfs_volumes = {}

  consul_kv = {}

  consul_intentions = {}
}
