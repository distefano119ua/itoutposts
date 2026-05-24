#----------------------------------------------------------
# My Terraform
# Provision:
#  - S3 Backend for remote Terraform state
#  - Servers remote state lookup
#  - Generate Ansible inventory file hosts.txt
#  - Generate Ansible group_vars/public_servers
#  - Run Ansible playbook after Terraform apply
# Dmytro Shpatakovskyi
#----------------------------------------------------------
provider "aws" {
  region = "us-east-1"
}


terraform {
  backend "s3" {
    bucket = "dev-terraform-state-int26-39"
    key    = "dev/deploy/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

#-------------------------Remote State---------------------------------

data "terraform_remote_state" "servers" {
  backend = "s3"

  config = {
    bucket = "dev-terraform-state-int26-39"
    key    = "dev/instances/terraform.tfstate"
    region = "us-east-1"
  }
}

#-------------------------Generate Ansible hosts.txt-------------------------

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/hosts.txt"

  content = <<EOT
[public_servers]
public ansible_host=${data.terraform_remote_state.servers.outputs.web_public_ip} ansible_user=${var.ansible_user}

[private_servers]
private ansible_host=${data.terraform_remote_state.servers.outputs.private_ip_mongodb} ansible_user=${var.ansible_user}

[private_servers:vars]
ansible_ssh_common_args='-o ProxyJump=${var.ansible_user}@${data.terraform_remote_state.servers.outputs.web_public_ip} -o ForwardAgent=yes'

[aws_servers:children]
public_servers
private_servers
EOT
}

#-------------------------Generate group_vars/aws_servers-------------------------

resource "local_file" "aws_servers_group_vars" {
  filename = "${path.module}/group_vars/aws_servers"

  content = <<EOT
---
ansible_user: ${var.ansible_user}
ansible_ssh_private_key_file: ../servers/keys/id_rsa
EOT
}

#-------------------------Generate group_vars/private_servers-------------------------

resource "local_file" "private_servers_group_vars" {
  filename = "${path.module}/group_vars/private_servers"

  content = <<EOT
---
ansible_user: ${var.ansible_user}
ansible_ssh_private_key_file: ../servers/keys/id_rsa
EOT
}

#-------------------------Generate group_vars/public_servers-------------------------

resource "local_file" "public_servers_group_vars" {
  filename = "${path.module}/group_vars/public_servers"

  content = <<EOT
---
ansible_user: ${var.ansible_user}
ansible_ssh_private_key_file: ../servers/keys/id_rsa

app_dir: /opt/monitor-app
public_registry: ghcr.io/distefano119ua/itoutposts

nginx_image: nginx:1.27-alpine
frontend_image: "{{ public_registry }}/frontend:80d95db5d6b8730b8e093df1a9855d02d640d4e1"
backend_image: "{{ public_registry }}/backend:fe1fa430e48f5f79aedb72231a4510cce3eca90b"

nginx_container_name: monitor-nginx
frontend_container_name: monitor-frontend
backend_container_name: monitor-api

app_network_name: itouposts-network

nginx_public_port: 80
nginx_https_port: 443

frontend_public_port: 5173
frontend_internal_port: 5173

backend_public_port: 7777
backend_internal_port: 7000

frontend_api_url: /api

mongo_private_ip: ${data.terraform_remote_state.servers.outputs.private_ip_mongodb}
mongo_uri: "mongodb://{{ mongo_private_ip }}:27017"

app_logs_path: /app/logs
alert_email: ${var.alert_email}
service_name: ITOUTPOSTS
db_name: monitoring
collection_name: script_errors
dataset_slug: abdulmalik1518/cars-datasets-2025
csv_name: Cars Datasets 2025.csv

domain_name: ${var.domain_name}
certbot_email: ${var.certbot_email}
EOT
}

#-------------------------Run Ansible Playbook-------------------------
#create Python venv -> install dependencies -> run ansible-playbook

resource "null_resource" "ansible_deploy" {
  depends_on = [
    local_file.ansible_inventory,
    local_file.aws_servers_group_vars,
    local_file.private_servers_group_vars,
    local_file.public_servers_group_vars
  ]

  provisioner "local-exec" {
    working_dir = path.module

    command = <<EOT
      python3 -m venv .venv
      . .venv/bin/activate
      python -m pip install --upgrade pip
      pip install -r requirements.txt
      chmod 600 ../servers/keys/id_rsa
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
        -i hosts.txt \
        playbooks/deploy-app.yml
    EOT
  }
}