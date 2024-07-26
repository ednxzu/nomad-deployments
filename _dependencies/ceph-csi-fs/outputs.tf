output "ceph_csi_cluster_id" {
  value     = data.vault_kv_secret_v2.hashistack_ceph_cluster_id.data["id"]
  sensitive = true
}

output "ceph_csi_fs_admin_id" {
  value     = data.vault_kv_secret_v2.hashistack_ceph_csi_fs.data["adminID"]
  sensitive = true
}

output "ceph_csi_fs_admin_key" {
  value     = data.vault_kv_secret_v2.hashistack_ceph_csi_fs.data["adminKey"]
  sensitive = true
}
