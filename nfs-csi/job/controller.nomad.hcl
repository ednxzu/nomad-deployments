job "nfs-csi-plugin-controller" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 60
  namespace   = "storage"

  group "controller" {
    task "plugin" {
      driver = "docker"
      config {
        image        = "registry.k8s.io/sig-storage/nfsplugin:v4.8.0"
        network_mode = "host"
        args = [
          "--v=5",
          "--nodeid=${attr.unique.hostname}",
          "--endpoint=unix:///csi/csi.sock",
          "--drivername=nfs.csi.k8s.io"
        ]
      }
      csi_plugin {
        id        = "nfs-csi"
        type      = "controller"
        mount_dir = "/csi"
      }
      resources {
        memory = 32
        cpu    = 100
      }
    }
  }
}
