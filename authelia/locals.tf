locals {
  stack_name = basename(path.cwd)
  jobs       = {}
  # jobs = {
  #   authelia = "${path.module}/job/job.nomad.hcl"
  # }

  jobs_variables = {}
  # jobs_variables = {
  #   authelia = {
  #     authelia_authelia_env         = base64encode(file("${path.module}/job/config/authelia/authelia.env"))
  #     authelia_configuration_yml    = base64encode(file("${path.module}/job/config/authelia/configuration.yml"))
  #     authelia_acl_yml              = base64encode(file("${path.module}/job/config/authelia/acl.yml"))
  #     authelia_oidc_yml             = base64encode(file("${path.module}/job/config/authelia/oidc.yml"))
  #     authelia_oidc_private_key     = base64encode(file("${path.module}/job/config/authelia/oidc_private_key"))
  #     mariadb_mariadb_env           = base64encode(file("${path.module}/job/config/mariadb/mariadb.env"))
  #     redis_redis_env               = base64encode(file("${path.module}/job/config/redis/redis.env"))
  #     logging_sidecar_promtail_yml  = base64encode(file("${path.module}/../_templates/logging-sidecar/promtail.yml"))
  #     borg_sidecar_borg_sidecar_env = base64encode(file("${path.module}/job/config/borg-sidecar/borg-sidecar.env"))
  #     borg_sidecar_config_yaml      = base64encode(file("${path.module}/job/config/borg-sidecar/config.yaml"))
  #     borg_sidecar_crontab_txt      = base64encode(file("${path.module}/../_templates/borg-sidecar/crontab.txt"))
  #     borg_sidecar_id_borg          = base64encode(file("${path.module}/../_templates/borg-sidecar/id_borg"))
  #     borg_sidecar_known_hosts      = base64encode(file("${path.module}/../_templates/borg-sidecar/known_hosts"))
  #   }
  # }

  volumes = {
    authelia-mariadb-data = {
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
    authelia-redis-data = {
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
    traefik-to-authelia = {
      source_name      = "traefik"
      destination_name = "authelia"
      action           = "allow"
    }
    authelia-to-lldap = {
      source_name      = "authelia"
      destination_name = "lldap-api"
      action           = "allow"
    }
    authelia-to-redis = {
      source_name      = "authelia"
      destination_name = "authelia-redis"
      action           = "allow"
    }
    authelia-to-mariadb = {
      source_name      = "authelia"
      destination_name = "authelia-mariadb"
      action           = "allow"
    }
  }
}
