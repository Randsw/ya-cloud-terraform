terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    sops = {
      source = "carlpett/sops"
      version = "~> 0.5"
    }
  }
}

data "sops_file" "secret" {
  source_file = "secret.enc.yaml"
}

provider "yandex" {
  token     = data.sops_file.secret.data["token"]
  cloud_id  = data.sops_file.secret.data["cloud_id"]
  folder_id = data.sops_file.secret.data["folder_id"]
  zone      = data.sops_file.secret.data["zone"]
}

resource "yandex_vpc_network" "test-net" {
    name = "yandex-terraform"
}

resource "yandex_vpc_subnet" "ya-subnet" {
  name = "ya-subnet-1"
  v4_cidr_blocks = ["10.2.0.0/16"]
  zone       = "ru-central1-a"
  network_id = "${yandex_vpc_network.test-net.id}"
}

resource "yandex_dns_zone" "tlstest" {
  name    = "tls-cert-zone"
  zone    = "rand-tls-test.ga."
  public  = true
}

resource "yandex_dns_recordset" "rs1" {
  zone_id = "${yandex_dns_zone.tlstest.id}"
  name    = "rand-tls-test.ga."
  type    = "A"
  ttl     = 200
  data    = ["${yandex_compute_instance.yandex-terraform-test.network_interface.0.nat_ip_address}"]
}

resource "yandex_compute_instance" "yandex-terraform-test" {
  name        = "test"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd83klic6c8gfgi40urb"
      size = 20
      type = "network-hdd"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.ya-subnet.id}"
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/ya_rsa.pub")}"
  }

  connection {
      host        = "${self.network_interface.0.nat_ip_address}"
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/ya_rsa")}"
    }
  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]
   }


}

resource "null_resource" "ansible_provision" {
   provisioner "local-exec" {
     command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${self.network_interface.0.nat_ip_address},' --private-key ${var.ssh_key_private} ansible/nginx-deploy.yml"
   }
}

output "internal_ip_address_yandex-terraform-test" {
  value = yandex_compute_instance.yandex-terraform-test.network_interface.0.ip_address
}

output "external_ip_address_yandex-terraform-test" {
  value = yandex_compute_instance.yandex-terraform-test.network_interface.0.nat_ip_address
}

output "ya-subnet" {
  value = yandex_vpc_subnet.ya-subnet.id
}