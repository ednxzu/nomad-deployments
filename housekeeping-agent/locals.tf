locals {
  stack_name = basename(path.cwd)
  jobs = {
    housekeeping-agent = "${path.module}/job/job.nomad.hcl"
  }

  jobs_variables = {}

  volumes = {}

  nfs_volumes = {}

  consul_kv = {}

  consul_intentions = {}
}
