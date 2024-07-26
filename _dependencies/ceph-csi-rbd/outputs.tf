output "ceph_csi_cluster_id" {
  value     = data.vault_kv_secret_v2.hashistack_ceph_cluster_id.data["id"]
  sensitive = true
}

output "ceph_csi_rbd_user_id" {
  value     = data.vault_kv_secret_v2.hashistack_ceph_csi_rbd.data["userID"]
  sensitive = true
}

output "ceph_csi_rbd_user_key" {
  value     = data.vault_kv_secret_v2.hashistack_ceph_csi_rbd.data["userKey"]
  sensitive = true
}
