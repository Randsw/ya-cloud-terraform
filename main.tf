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

resource "yandex_compute_instance" "yandex-terraform-test" {
  name        = "test"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 1
    memory = 2
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id = "fd83klic6c8gfgi40urb"
      size = 20
      type = "HDD"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.ya-subnet.id}"
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/ya_rsa.pub")}"
  }
}

resource "yandex_vpc_network" "test-net" {
    name = "yandex-terraform"
}

resource "yandex_vpc_subnet" "ya-subnet" {
  v4_cidr_blocks = ["10.2.0.0/16"]
  zone       = "ru-central1-a"
  network_id = "${yandex_vpc_network.test-net.id}"
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