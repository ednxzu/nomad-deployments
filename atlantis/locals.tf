locals {
  jobs = {
    atlantis = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    atlantis = {
      atlantis_atlantis_env         = base64encode(file("${path.module}/job/config/atlantis/atlantis.env"))
      atlantis_config_yaml          = base64encode(file("${path.module}/job/config/atlantis/config.yaml"))
      atlantis_ednz_ca_pem          = base64encode(file("${path.module}/job/config/atlantis/ednz_ca.pem"))
      bootstrap_bootstrap_env       = base64encode(file("${path.module}/job/config/bootstrap/bootstrap.env"))
      bootstrap_entrypoint_sh       = base64encode(file("${path.module}/job/config/bootstrap/entrypoint.sh"))
      logging_sidecar_promtail_yml  = base64encode(file("${path.module}/../_templates/logging-sidecar/promtail.yml"))
    }
  }

  volumes = {}

  nfs_volumes = {}

  consul_kv = {}

  consul_intentions = {
    traefik-to-atlantis = {
      source_name      = "traefik"
      destination_name = "atlantis"
      action           = "allow"
    }
  }
}
