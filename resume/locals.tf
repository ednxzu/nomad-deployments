locals {
  stack_name = basename(path.cwd)
  jobs = {
    resume = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {
    resume = {
      resume_resume_env            = base64encode(file("${path.module}/job/config/resume/resume.env"))
      logging_sidecar_promtail_yml = base64encode(file("${path.module}/../_templates/logging-sidecar/promtail.yml"))
    }
  }

  volumes = {}

  nfs_volumes = {}

  consul_kv = {}

  consul_intentions = {
    traefik-to-resume = {
      source_name      = "traefik"
      destination_name = "resume"
      action           = "allow"
    }
  }
}
