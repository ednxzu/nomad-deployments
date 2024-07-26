locals {
  jobs = {
    nextcloud = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    nextcloud = {
      nextcloud_nextcloud_env       = base64encode(file("${path.module}/job/config/nextcloud/nextcloud.env"))
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
    nextcloud-config = {
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
    nextcloud-mariadb-data = {
      plugin_id    = "ceph-csi-rbd"
      namespace    = "default"
      capacity_min = "10G"
      capacity_max = "20G"
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
    nextcloud-redis-data = {
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

  nfs_volumes = {
    nextcloud-data = {
      plugin_id = "nfs-csi"
      namespace = "default"
      capability = {
        access_mode     = "multi-node-multi-writer"
        attachment_mode = "file-system"
      }
      context = {
        server           = "10.1.30.20"
        share            = "/mnt/user/datastore3"
        mountPermissions = "0"
      }
      mount_options = {
        fs_type     = "nfs"
        mount_flags = ["_netdev", "vers=4", "nolock", "soft", "rw", "rsize=8192", "wsize=8192"]
      }
    }
  }

  consul_kv = {}

  consul_intentions = {
    traefik-to-nextcloud = {
      source_name      = "traefik"
      destination_name = "nextcloud"
      action           = "allow"
    }
    nextcloud-to-lldap = {
      source_name      = "nextcloud"
      destination_name = "lldap-api"
      action           = "allow"
    }
  }
}
