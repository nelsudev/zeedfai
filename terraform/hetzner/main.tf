# zeedfai — cluster k3s na Hetzner Cloud (Fase 7)
#
# Billing à hora: subir para a demo, correr o burst, `terraform destroy`.
# Todos os servers levam a label zeedfai=true — é por ela que a GitHub
# Action de teardown noturno (teardown-cloud-demo.yml) apanha órfãos.

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
}

variable "hcloud_token" {
  description = "Token da API Hetzner Cloud (project → Security → API tokens)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Chave SSH pública para acesso aos nodes"
  type        = string
}

variable "worker_count" {
  description = "Nº de workers fixos (o cluster-autoscaler adiciona os elásticos)"
  type        = number
  default     = 1
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "zeedfai" {
  name       = "zeedfai"
  public_key = var.ssh_public_key
}

resource "hcloud_network" "zeedfai" {
  name     = "zeedfai"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "nodes" {
  network_id   = hcloud_network.zeedfai.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_server" "control_plane" {
  name        = "zeedfai-cp"
  server_type = "cx22" # 2 vCPU / 4 GB — ~€0.006/h
  image       = "ubuntu-24.04"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.zeedfai.id]
  labels      = { zeedfai = "true", role = "control-plane" }

  network {
    network_id = hcloud_network.zeedfai.id
    ip         = "10.0.1.10"
  }

  user_data = templatefile("${path.module}/cloud-init-cp.yaml", {
    k3s_token = random_password.k3s_token.result
  })

  depends_on = [hcloud_network_subnet.nodes]
}

resource "hcloud_server" "worker" {
  count       = var.worker_count
  name        = "zeedfai-worker-${count.index}"
  server_type = "cx22"
  image       = "ubuntu-24.04"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.zeedfai.id]
  labels      = { zeedfai = "true", role = "worker" }

  network {
    network_id = hcloud_network.zeedfai.id
  }

  user_data = templatefile("${path.module}/cloud-init-worker.yaml", {
    k3s_token = random_password.k3s_token.result
    cp_ip     = "10.0.1.10"
  })

  depends_on = [hcloud_server.control_plane]
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

output "control_plane_ip" {
  value = hcloud_server.control_plane.ipv4_address
}

output "next_steps" {
  value = <<-EOT
    1. ssh root@${hcloud_server.control_plane.ipv4_address}
    2. copiar /etc/rancher/k3s/k3s.yaml (trocar 127.0.0.1 pelo IP público)
    3. flux bootstrap github --owner=nelsudev --repository=zeedfai \
         --branch=main --path=gitops/clusters/cloud --personal
    4. instalar o cluster-autoscaler com o provider hetzner (ver README.md)
    5. correr a demo de burst; no fim: terraform destroy
  EOT
}
