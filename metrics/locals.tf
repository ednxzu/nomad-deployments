locals {
  jobs = {
    metrics = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    metrics = {
      prometheus_prometheus_yml = base64encode(file("${path.module}/job/config/prometheus/prometheus.yml"))
      prometheus_ednz_ca_pem    = base64encode(file("${path.module}/job/config/prometheus/ednz_ca.pem"))
      loki_loki_yml             = base64encode(file("${path.module}/job/config/loki/loki.yml"))
    }
  }

  volumes = {
    prometheus-data = {
      plugin_id    = "ceph-csi-rbd"
      namespace    = "default"
      capacity_min = "5G"
      capacity_max = "5G"
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
    loki-data = {
      plugin_id    = "ceph-csi-rbd"
      namespace    = "default"
      capacity_min = "5G"
      capacity_max = "5G"
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
    traefik-to-prometheus = {
      source_name      = "traefik"
      destination_name = "prometheus"
      action           = "allow"
    }
    grafana-to-prometheus = {
      source_name      = "grafana"
      destination_name = "prometheus"
      action           = "allow"
    }
    grafana-to-loki = {
      source_name      = "grafana"
      destination_name = "loki"
      action           = "allow"
    }
    logging-sidecar-to-loki = {
      source_name      = "logging-sidecar"
      destination_name = "loki"
      action           = "allow"
    }
    crowdsec-api-to-loki = {
      source_name      = "crowdsec-api"
      destination_name = "loki"
      action           = "allow"
    }
  }
}
