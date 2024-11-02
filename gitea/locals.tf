locals {
  stack_name = basename(path.cwd)
  jobs = {
    # gitea = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    gitea = {
      gitea_gitea_env               = base64encode(file("${path.module}/job/config/gitea/gitea.env"))
      mariadb_mariadb_env           = base64encode(file("${path.module}/job/config/mariadb/mariadb.env"))
      redis_redis_env               = base64encode(file("${path.module}/job/config/redis/redis.env"))
      logging_sidecar_promtail_yml  = base64encode(file("${path.module}/../_templates/logging-sidecar/promtail.yml"))
      borg_sidecar_borg_sidecar_env = base64encode(file("${path.module}/job/config/borg-sidecar/borg-sidecar.env"))
      borg_sidecar_config_yaml      = base64encode(file("${path.module}/job/config/borg-sidecar/config.yaml"))
      borg_sidecar_crontab_txt      = base64encode(file("${path.module}/../_templates/borg-sidecar/crontab.txt"))
      borg_sidecar_id_borg          = base64encode(file("${path.module}/../_templates/borg-sidecar/id_borg"))
      borg_sidecar_known_hosts      = base64encode(file("${path.module}/../_templates/borg-sidecar/known_hosts"))
    }
  }

  volumes = {
    gitea-data = {
      type         = "csi"
      plugin_id    = "ceph-csi-fs"
      namespace    = "default"
      capacity_min = "40G"
      capacity_max = "80G"
      capability = {
        access_mode     = "multi-node-multi-writer"
        attachment_mode = "file-system"
      }
      secrets = {
        adminID  = module.credentials_ceph_csi_fs.ceph_csi_fs_admin_id
        adminKey = module.credentials_ceph_csi_fs.ceph_csi_fs_admin_key
      }
      parameters = {
        clusterID = module.credentials_ceph_csi_rbd.ceph_csi_cluster_id
        fsName    = "nomadfs"
      }
    }
    gitea-mariadb-data = {
      plugin_id    = "ceph-csi-rbd"
      namespace    = "default"
      capacity_min = "20G"
      capacity_max = "40G"
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
    gitea-redis-data = {
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
    traefik-to-gitea = {
      source_name      = "traefik"
      destination_name = "gitea"
      action           = "allow"
    }
    gitea-to-redis = {
      source_name      = "gitea"
      destination_name = "gitea-redis"
      action           = "allow"
    }
    gitea-to-mariadb = {
      source_name      = "gitea"
      destination_name = "gitea-mariadb"
      action           = "allow"
    }
  }
}
