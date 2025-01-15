job "housekeeping-agent" {
  datacenters = ["gre1"]
  type        = "sysbatch"
  priority    = 50
  namespace   = "maintenance"

  periodic {
    cron      = "@daily"
    time_zone = "Europe/Paris"
  }

  group "housekeeping-agent" {
    network {
      mode = "bridge"
    }
    task "housekeeping-agent" {
      driver = "docker"
      config {
        image      = "docker:latest@sha256:cbde039f51b3d85366f59fe2e97cdaf329a6eef076b79a9afb9f9568d04d0767"
        privileged = true
        command    = "docker"
        args       = ["system", "prune", "--all", "--force", "--volumes"]
        mount {
          type   = "bind"
          target = "/var/run/docker.sock"
          source = "/var/run/docker.sock"
        }
      }
      resources {
        cpu    = 64
        memory = 64
      }
    }
  }
}
