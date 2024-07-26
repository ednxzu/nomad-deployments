locals {
  jobs = {
    ceph-csi-fs-plugin-controller  = "${path.module}/job/ceph-fs/controller.nomad.hcl"
    ceph-csi-fs-plugin-nodes       = "${path.module}/job/ceph-fs/nodes.nomad.hcl"
    ceph-csi-rbd-plugin-controller = "${path.module}/job/ceph-rbd/controller.nomad.hcl"
    ceph-csi-rbd-plugin-nodes      = "${path.module}/job/ceph-rbd/nodes.nomad.hcl"
  }

  jobs_variables = {
    ceph-csi-fs-plugin-controller = {
      cephfs_controller_config_json = base64encode(file("${path.module}/job/ceph-fs/config/config.json"))
    }
    ceph-csi-fs-plugin-nodes = {
      cephfs_node_config_json = base64encode(file("${path.module}/job/ceph-fs/config/config.json"))
    }
    ceph-csi-rbd-plugin-controller = {
      ceph_controller_config_json = base64encode(file("${path.module}/job/ceph-rbd/config/config.json"))
    }
    ceph-csi-rbd-plugin-nodes = {
      ceph_node_config_json = base64encode(file("${path.module}/job/ceph-rbd/config/config.json"))
    }
  }

  volumes = {}

  nfs_volumes = {}

  consul_kv = {}

  consul_intentions = {}
}
