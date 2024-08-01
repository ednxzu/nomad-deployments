locals {
  stack_name = basename(path.cwd)
  jobs = {
    flaresolverr = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    flaresolverr = {
      flaresolverr_flaresolverr_env = base64encode(file("${path.module}/job/config/flaresolverr/flaresolverr.env"))
      logging_sidecar_promtail_yml  = base64encode(file("${path.module}/job/config/logging-sidecar/promtail.yml"))
    }
  }

  volumes = {}

  nfs_volumes = {}

  consul_kv = {}

  consul_intentions = {}
}
