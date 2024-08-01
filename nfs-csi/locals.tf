locals {
  stack_name = basename(path.cwd)
  jobs = {
    nfs-csi-plugin-controller = "${path.module}/job/controller.nomad.hcl"
    nfs-csi-plugin-nodes      = "${path.module}/job/nodes.nomad.hcl"
  }

  jobs_variables = {}

  volumes = {}

  nfs_volumes = {}

  consul_kv = {}

  consul_intentions = {}
}
