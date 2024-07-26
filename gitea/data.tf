module "credentials_ceph_csi_rbd" {
  source = "../_dependencies/ceph-csi-rbd"
}

module "credentials_ceph_csi_fs" {
  source = "../_dependencies/ceph-csi-fs"
}
