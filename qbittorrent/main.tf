terraform {
  required_version = ">= 1.0.0"

  backend "consul" {
    address = "consul.service.consul:8501"
    scheme  = "https"
    path    = "terraform/ednz-cloud/infrastructure/environments/production/eu-west-1/applications/deployments/qbittorrent/terraform.tfstate"
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.25.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20.0"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1.1"
    }
  }
}

provider "vault" {
  address = "https://vault.service.consul:8200"
}

provider "consul" {
  address = "consul.service.consul:8501"
  scheme  = "https"
}

provider "nomad" {
  address = "https://nomad.service.consul:4646"
  region  = "global"
}

module "nomad_job" {
  source = "git::https://git.ednz.fr/terraform-registry/terraform-nomad-base.git//?ref=v2.2.0"

  jobs           = local.jobs
  jobs_variables = local.jobs_variables

  consul_kv         = local.consul_kv
  consul_intentions = local.consul_intentions

  volumes     = local.volumes
  nfs_volumes = local.nfs_volumes
}
