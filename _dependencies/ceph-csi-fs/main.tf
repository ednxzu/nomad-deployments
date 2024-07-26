terraform {
  required_version = ">= 1.0.0"

  required_providers {
    vault = {
      source = "hashicorp/vault"
    }
  }
}

locals {
  secret_engine           = "kv_hs"
  cluster_id_secret_path  = "hashistack/ceph/cluster_info/cluster_id"
  ceph_csi_fs_secret_path = "hashistack/ceph/cluster_info/csi_fs"
}

data "vault_kv_secret_v2" "hashistack_ceph_cluster_id" {
  mount = local.secret_engine
  name  = local.cluster_id_secret_path
}

data "vault_kv_secret_v2" "hashistack_ceph_csi_fs" {
  mount = local.secret_engine
  name  = local.ceph_csi_fs_secret_path
}
