job "ceph-csi-fs-plugin-controller" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 60
  namespace   = "storage"
  vault {
    policies = ["read_kv_hs"]
  }

  group "controller" {
    network {
      port "metrics" {}
    }

    service {
      name = "ceph-csi-fs-controller-exporter"
      port = "metrics"
      tags = ["prometheus"]
    }

    task "cephfs-controller" {
      driver = "docker"
      config {
        image = "quay.io/cephcsi/cephcsi:v3.10.2"
        network_mode = "host"
        volumes = [
          "./local/config.json:/etc/ceph-csi-config/config.json",
          "/lib/modules:/lib/modules"
        ]
        mount {
          type     = "bind"
          source   = "secrets"
          target   = "/tmp/csi/keys"
          readonly = false
        }
        args = [
          "--type=cephfs",
          "--controllerserver=true",
          "--drivername=cephfs.csi.ceph.com",
          "--endpoint=unix://csi/csi.sock",
          "--nodeid=${node.unique.name}",
          "--instanceid=${node.unique.name}-controller",
          "--pidlimit=-1",
          "--logtostderr=true",
          "--v=5",
          "--metricsport=${NOMAD_PORT_metrics}"
        ]
        privileged = true
        ports = ["metrics"]
      }
      template {
        data        = base64decode(var.cephfs_controller_config_json)
        destination = "${NOMAD_TASK_DIR}/config.json"
        change_mode = "restart"
      }
      csi_plugin {
        id        = "ceph-csi-fs"
        type      = "controller"
        mount_dir = "/csi"
      }
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}

variable "cephfs_controller_config_json" {
  type = string
}
