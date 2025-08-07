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
        image      = "docker:latest@sha256:c0872aae4791ff427e6eda52769afa04f17b5cf756f8267e0d52774c99d5c9de"
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
