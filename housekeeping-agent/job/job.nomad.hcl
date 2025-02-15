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
        image      = "docker:latest@sha256:fe74c13f0f4447cd6cf23a6c4c06b696b5c5c4b6471f9a371090f2f3fb6ec2ce"
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
