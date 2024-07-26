locals {
  jobs = {
    prowlarr = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    prowlarr = {
      prowlarr_prowlarr_env         = base64encode(file("${path.module}/job/config/prowlarr/prowlarr.env"))
      logging_sidecar_promtail_yml  = base64encode(file("${path.module}/../_templates/logging-sidecar/promtail.yml"))
      borg_sidecar_borg_sidecar_env = base64encode(file("${path.module}/job/config/borg-sidecar/borg-sidecar.env"))
      borg_sidecar_config_yaml      = base64encode(file("${path.module}/job/config/borg-sidecar/config.yaml"))
      borg_sidecar_crontab_txt      = base64encode(file("${path.module}/../_templates/borg-sidecar/crontab.txt"))
      borg_sidecar_id_borg          = base64encode(file("${path.module}/../_templates/borg-sidecar/id_borg"))
      borg_sidecar_known_hosts      = base64encode(file("${path.module}/../_templates/borg-sidecar/known_hosts"))
    }
  }

  volumes = {
    prowlarr-data = {
      plugin_id    = "ceph-csi-rbd"
      namespace    = "media"
      capacity_min = "1G"
      capacity_max = "2G"
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
    traefik-to-prowlarr = {
      source_name      = "traefik"
      destination_name = "prowlarr"
      action           = "allow"
    }
    prowlarr-to-sonarr = {
      source_name      = "prowlarr"
      destination_name = "sonarr"
      action           = "allow"
    }
    prowlarr-to-radarr = {
      source_name      = "prowlarr"
      destination_name = "radarr"
      action           = "allow"
    }
    prowlarr-to-flaresolverr = {
      source_name      = "prowlarr"
      destination_name = "flaresolverr"
      action           = "allow"
    }
  }
}
