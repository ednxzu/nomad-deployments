locals {
  stack_name = basename(path.cwd)
  jobs = {
    sonarr = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    sonarr = {
      sonarr_sonarr_env             = base64encode(file("${path.module}/job/config/sonarr/sonarr.env"))
      logging_sidecar_promtail_yml  = base64encode(file("${path.module}/../_templates/logging-sidecar/promtail.yml"))
      borg_sidecar_borg_sidecar_env = base64encode(file("${path.module}/job/config/borg-sidecar/borg-sidecar.env"))
      borg_sidecar_config_yaml      = base64encode(file("${path.module}/job/config/borg-sidecar/config.yaml"))
      borg_sidecar_crontab_txt      = base64encode(file("${path.module}/../_templates/borg-sidecar/crontab.txt"))
      borg_sidecar_id_borg          = base64encode(file("${path.module}/../_templates/borg-sidecar/id_borg"))
      borg_sidecar_known_hosts      = base64encode(file("${path.module}/../_templates/borg-sidecar/known_hosts"))
    }
  }

  volumes = {
    sonarr-data = {
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

  nfs_volumes = {
    nfs-media-tv = {
      plugin_id = "nfs-csi"
      namespace = "media"
      capability = {
        access_mode     = "multi-node-multi-writer"
        attachment_mode = "file-system"
      }
      context = {
        server           = "10.1.30.20"
        share            = "/mnt/user/datastore1/media/tv"
        mountPermissions = "0"
      }
      mount_options = {
        fs_type     = "nfs"
        mount_flags = ["_netdev", "nolock", "soft", "rw", "rsize=8192", "wsize=8192"]
      }
    }
  }

  consul_kv = {}

  consul_intentions = {
    traefik-to-sonarr = {
      source_name      = "traefik"
      destination_name = "sonarr"
      action           = "allow"
    }
    sonarr-to-prowlarr = {
      source_name      = "sonarr"
      destination_name = "prowlarr"
      action           = "allow"
    }
    sonarr-to-qbittorent = {
      source_name      = "sonarr"
      destination_name = "qbittorrent"
      action           = "allow"
    }
  }
}
