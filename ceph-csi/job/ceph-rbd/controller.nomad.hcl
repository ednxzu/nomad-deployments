job "ceph-csi-rbd-plugin-controller" {
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
      name = "ceph-csi-rbd-controller-exporter"
      port = "metrics"
      tags = ["prometheus"]
    }

    task "ceph-controller" {
      driver = "docker"
      config {
        image        = "quay.io/cephcsi/cephcsi:v3.10.2"
        network_mode = "host"
        volumes = [
          "./local/config.json:/etc/ceph-csi-config/config.json"
        ]
        mount {
          type     = "bind"
          source   = "secrets"
          target   = "/tmp/csi/keys"
          readonly = false
        }
        args = [
          "--type=rbd",
          "--controllerserver=true",
          "--drivername=rbd.csi.ceph.com",
          "--endpoint=unix://csi/csi.sock",
          "--nodeid=${node.unique.name}",
          "--instanceid=${node.unique.name}-controller",
          "--pidlimit=-1",
          "--logtostderr=true",
          "--v=5",
          "--metricsport=${NOMAD_PORT_metrics}"
        ]
        privileged = true
        ports      = ["metrics"]
      }
      template {
        data        = base64decode(var.ceph_controller_config_json)
        destination = "local/config.json"
        change_mode = "restart"
      }
      csi_plugin {
        id        = "ceph-csi-rbd"
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

variable "ceph_controller_config_json" {
  type = string
}
