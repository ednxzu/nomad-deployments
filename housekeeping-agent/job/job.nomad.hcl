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
        image      = "docker:latest@sha256:24173119fa6d1b5b4a27ab164fa7863deb66574ee5b90fef3b85dc888ef1a7e6"
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
