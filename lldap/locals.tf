locals {
  jobs = {
    lldap = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    lldap = {
      lldap_lldap_env               = base64encode(file("${path.module}/job/config/lldap/lldap.env"))
      mariadb_mariadb_env           = base64encode(file("${path.module}/job/config/mariadb/mariadb.env"))
      logging_sidecar_promtail_yml  = base64encode(file("${path.module}/../_templates/logging-sidecar/promtail.yml"))
      borg_sidecar_borg_sidecar_env = base64encode(file("${path.module}/job/config/borg-sidecar/borg-sidecar.env"))
      borg_sidecar_config_yaml      = base64encode(file("${path.module}/job/config/borg-sidecar/config.yaml"))
      borg_sidecar_crontab_txt      = base64encode(file("${path.module}/../_templates/borg-sidecar/crontab.txt"))
      borg_sidecar_id_borg          = base64encode(file("${path.module}/../_templates/borg-sidecar/id_borg"))
      borg_sidecar_known_hosts      = base64encode(file("${path.module}/../_templates/borg-sidecar/known_hosts"))
    }
  }

  volumes = {
    lldap-data = {
      plugin_id    = "ceph-csi-rbd"
      namespace    = "default"
      capacity_min = "1G"
      capacity_max = "1G"
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
    lldap-mariadb-data = {
      plugin_id    = "ceph-csi-rbd"
      namespace    = "default"
      capacity_min = "1G"
      capacity_max = "1G"
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

  consul_intentions = {
    traefik-to-lldap-webui = {
      source_name      = "traefik"
      destination_name = "lldap-webui"
      action           = "allow"
    }
  }
}
