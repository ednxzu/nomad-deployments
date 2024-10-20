locals {
  stack_name = basename(path.cwd)
  jobs = {
    traefik = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    traefik = {
      keepalived_keepalived_env    = base64encode(file("${path.module}/job/config/keepalived/keepalived.env"))
      loadbalancer_traefik_env     = base64encode(file("${path.module}/job/config/loadbalancer/traefik.env"))
      loadbalancer_traefik_yml     = base64encode(file("${path.module}/job/config/loadbalancer/traefik.yml"))
      loadbalancer_ednz_ca_pem     = base64encode(file("${path.module}/job/config/loadbalancer/ednz_ca.pem"))
      authentik_authentik_env      = base64encode(file("${path.module}/job/config/authentik/authentik.env"))
      logging_sidecar_promtail_yml = base64encode(file("${path.module}/../_templates/logging-sidecar/promtail.yml"))
    }
  }

  volumes = {
    traefik-certs = {
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

  consul_kv = {
    "traefik/http/routers/consul/" = {
      "service"          = "consul"
      "middlewares"      = "internal-acl@consulcatalog"
      "entryPoints"      = "https"
      "tls/certResolver" = "cloudflare"
      "rule"             = "Host(`consul.ednz.fr`)"
    }
    "traefik/http/services/consul/" = {
      "loadBalancer/sticky/cookie"  = "{}"
      "loadBalancer/servers/01/url" = "https://hs1.ednz.fr:8501"
      "loadBalancer/servers/02/url" = "https://hs2.ednz.fr:8501"
      "loadBalancer/servers/03/url" = "https://hs3.ednz.fr:8501"
    }
    "traefik/http/routers/vault/" = {
      "service"          = "vault"
      "middlewares"      = "internal-acl@consulcatalog"
      "entryPoints"      = "https"
      "tls/certResolver" = "cloudflare"
      "rule"             = "Host(`vault.ednz.fr`)"
    }
    "traefik/http/services/vault/" = {
      "loadBalancer/sticky/cookie"  = "{}"
      "loadBalancer/servers/01/url" = "https://hs1.ednz.fr:8200"
      "loadBalancer/servers/02/url" = "https://hs2.ednz.fr:8200"
      "loadBalancer/servers/03/url" = "https://hs3.ednz.fr:8200"
    }
    "traefik/http/routers/nomad/" = {
      "service"          = "nomad"
      "middlewares"      = "internal-acl@consulcatalog"
      "entryPoints"      = "https"
      "tls/certResolver" = "cloudflare"
      "rule"             = "Host(`nomad.ednz.fr`)"
    }
    "traefik/http/services/nomad/" = {
      "loadBalancer/sticky/cookie"  = "{}"
      "loadBalancer/servers/01/url" = "https://hs1.ednz.fr:4646"
      "loadBalancer/servers/02/url" = "https://hs2.ednz.fr:4646"
      "loadBalancer/servers/03/url" = "https://hs3.ednz.fr:4646"
    }
    "traefik/http/routers/plex/" = {
      "service"          = "plex"
      "entryPoints"      = "https"
      "tls/certResolver" = "cloudflare"
      "rule"             = "Host(`plex.ednz.fr`)"
    }
    "traefik/http/services/plex/" = {
      "loadBalancer/sticky/cookie"  = "{}"
      "loadBalancer/servers/01/url" = "https://10.1.30.20:32400"
    }
  }

  consul_intentions = {}
}
