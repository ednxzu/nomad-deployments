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
        image      = "docker:latest@sha256:61b179d1c34a08d85d68df58fa90e4f8f6fe469f8e89aefb474d29f2e3bc8b97"
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
