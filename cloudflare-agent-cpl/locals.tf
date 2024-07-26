locals {
  jobs = {
    cloudflare-agent-cpl = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    cloudflare-agent-cpl = {
      cloudflare_agent_cloudflare_agent_env = base64encode(file("${path.module}/job/config/cloudflare-agent/cloudflare-agent.env"))
      logging_sidecar_promtail_yml          = base64encode(file("${path.module}/job/config/logging-sidecar/promtail.yml"))
    }
  }

  volumes = {}

  nfs_volumes = {}

  consul_kv = {}

  consul_intentions = {}
}
