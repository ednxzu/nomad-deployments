job "traefik" {
  datacenters = ["gre1"]
  type        = "service"
  priority    = 85
  namespace   = "default"
  vault {
    policies = ["read_kv_hs"]
  }

  group "traefik" {
    network {
      mode = "bridge"
      port "http" {
        to     = 80
        static = 80
      }
      port "https" {
        to     = 443
        static = 443
      }
      port "gitea-ssh" {
        to     = 5022
        static = 5022
      }
      port "teamspeak-voice" {
        to     = 9987
        static = 9987
      }
      port "teamspeak-file" {
        to     = 30033
        static = 30033
      }
      port "prometheus-exporter" {
        to = 8082
      }
    }

    service {
      name = "traefik"
      port = 8080
      task = "loadbalancer"
      tags = [
        "traefik.enable=true",
        # service router setup (optional)
        "traefik.http.routers.dashboard.rule=Host(`traefik.ednz.fr`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard/`))",
        "traefik.http.routers.dashboard.service=api@internal",
        "traefik.http.routers.dashboard.tls=true",
        "traefik.http.routers.dashboard.tls.certresolver=cloudflare",
        "traefik.http.routers.dashboard.middlewares=internal-acl@consulcatalog",
        # service router setup (optional)
        "traefik.http.routers.ping.rule=Host(`traefik.ednz.fr`) && PathPrefix(`/ping`)",
        "traefik.http.routers.ping.service=ping@internal",
        "traefik.http.routers.ping.tls=true",
        "traefik.http.routers.ping.tls.certresolver=cloudflare",
        # real-ip middleware definition
        "traefik.http.middlewares.real-ip.plugin.real-ip.Proxy.proxyHeadername=X-From-Cdn",
        "traefik.http.middlewares.real-ip.plugin.real-ip.Proxy.proxyHeadervalue=cloudflare",
        "traefik.http.middlewares.real-ip.plugin.real-ip.Proxy.realIP=Cf-Connecting-Ip",
        "traefik.http.middlewares.real-ip.plugin.real-ip.Proxy.OverwriteXFF=true",
        # bouncer middleware definition
        "traefik.http.middlewares.bouncer.forwardauth.address=http://localhost:6666/api/v1/forwardAuth",
        "traefik.http.middlewares.bouncer.forwardauth.trustForwardHeader=true",
        # chain real-ip+bounce
        "traefik.http.middlewares.secured.chain.middlewares=real-ip@consulcatalog,bouncer@consulcatalog",
        # network ACLs middleware definition
        "traefik.http.middlewares.internal-acl.ipallowlist.sourcerange=10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.1/32",
        # ForwardAuth middleware definition
        "traefik.http.middlewares.authentik.forwardauth.address=http://localhost:9000/outpost.goauthentik.io/auth/traefik",
        "traefik.http.middlewares.authentik.forwardauth.trustForwardHeader=true",
        "traefik.http.middlewares.authentik.forwardauth.authResponseHeaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid,X-authentik-jwt,X-authentik-meta-jwks,X-authentik-meta-outpost,X-authentik-meta-provider,X-authentik-meta-app,X-authentik-meta-version",

      ]
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "crowdsec-bouncer-traefik"
              local_bind_port  = 6666
            }
          }
        }
        sidecar_task {
          resources {
            cpu        = 125
            memory     = 64
            memory_max = 128
          }
        }
      }
    }

    service {
      name = "loadbalancer-exporter"
      port = "prometheus-exporter"
      task = "loadbalancer"
      tags = [
        "fr.ednz_cloud.prometheus.enable=true",
        "fr.ednz_cloud.prometheus.metrics_path=/metrics",
        "fr.ednz_cloud.prometheus.scrape_interval=15s",
      ]
    }

    service {
      name = "logging-sidecar"
      port = 9080
      task = "logging-sidecar"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "loki"
              local_bind_port  = 3100
            }
          }
        }
        sidecar_task {
          resources {
            cpu        = 125
            memory     = 64
            memory_max = 128
          }
        }
      }
    }

    task "keepalived" {
      driver = "docker"
      lifecycle {
        hook    = "poststart"
        sidecar = true
      }
      config {
        image        = "ednxzu/keepalived:2.3.2"
        network_mode = "host"
        cap_add = [
          "NET_ADMIN",
          "NET_BROADCAST",
          "NET_RAW"
        ]
      }
      template {
        data        = base64decode(var.keepalived_keepalived_env)
        destination = "secrets/keepalived.env"
        env         = true
      }
      resources {
        cpu    = 50
        memory = 10
      }
    }

    task "loadbalancer" {
      driver = "docker"
      config {
        image = "traefik:v2.11"
        ports = [
          "http",
          "https",
          "gitea-ssh",
          "teamspeak-voice",
          "teamspeak-file"
        ]
        mount {
          type   = "bind"
          source = "secrets/traefik.yml"
          target = "/etc/traefik/traefik.yml"
        }
      }
      template {
        data        = base64decode(var.loadbalancer_traefik_env)
        destination = "secrets/traefik.env"
        env         = true
      }
      template {
        data        = base64decode(var.loadbalancer_traefik_yml)
        destination = "secrets/traefik.yml"
      }
      template {
        data        = base64decode(var.loadbalancer_ednz_ca_pem)
        destination = "secrets/ednz_ca.pem"
      }
      volume_mount {
        volume      = "traefik-certs"
        destination = "/certificates"
      }
      resources {
        cpu    = 128
        memory = 256
      }
    }

    task "authentik" {
      driver = "docker"
      config {
        image = "ghcr.io/goauthentik/proxy:2025.2.3"
      }
      template {
        data        = base64decode(var.authentik_authentik_env)
        destination = "secrets/authentik.env"
        env         = true
      }
      resources {
        cpu    = 128
        memory = 256
      }
    }

    task "logging-sidecar" {
      lifecycle {
        hook    = "poststart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "grafana/promtail:latest"
        args = [
          "-config.file=/etc/promtail/promtail.yml"
        ]
        mount {
          type   = "bind"
          source = "secrets/promtail.yml"
          target = "/etc/promtail/promtail.yml"
        }
        mount {
          type     = "bind"
          source   = "/opt/nomad/alloc/${NOMAD_ALLOC_ID}/alloc/logs"
          target   = "/opt/logs"
          readonly = true
        }
      }
      template {
        data        = base64decode(var.logging_sidecar_promtail_yml)
        destination = "secrets/promtail.yml"
      }
      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }

    volume "traefik-certs" {
      type            = "csi"
      source          = "traefik-certs"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }
  }
}

variable "keepalived_keepalived_env" {
  type = string
}

variable "loadbalancer_traefik_env" {
  type = string
}

variable "loadbalancer_traefik_yml" {
  type = string
}

variable "loadbalancer_ednz_ca_pem" {
  type = string
}

variable "authentik_authentik_env" {
  type = string
}

variable "logging_sidecar_promtail_yml" {
  type = string
}
