job "ceph-csi-rbd-plugin-nodes" {
  datacenters = ["gre1"]
  type        = "system"
  priority    = 60
  namespace   = "storage"
  vault {
    policies = ["read_kv_hs"]
  }

  group "nodes" {
    network {
      port "metrics" {}
    }

    service {
      name = "ceph-csi-rbd-nodes-exporter"
      port = "metrics"
      tags = ["prometheus"]
    }

    task "ceph-node" {
      driver = "docker"
      config {
        image = "quay.io/cephcsi/cephcsi:v3.10.2"
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
          "--drivername=rbd.csi.ceph.com",
          "--nodeserver=true",
          "--endpoint=unix://csi/csi.sock",
          "--nodeid=${node.unique.name}",
          "--instanceid=${node.unique.name}-nodes",
          "--pidlimit=-1",
          "--logtostderr=true",
          "--v=5",
          "--metricsport=${NOMAD_PORT_metrics}"
        ]
        privileged = true
        ports = ["metrics"]
      }
      template {
        data        = base64decode(var.ceph_node_config_json)
        destination = "local/config.json"
        change_mode = "restart"
      }
      csi_plugin {
        id        = "ceph-csi-rbd"
        type      = "node"
        mount_dir = "/csi"
      }
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}

variable "ceph_node_config_json" {
  type = string
}
