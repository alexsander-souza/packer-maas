packer {
  required_version = ">= 1.7.0"
  required_plugins {
    qemu = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "http_directory" {
  type    = string
  default = "http"
}

variable "http_proxy" {
  type    = string
  default = "${env("http_proxy")}"
}

variable "https_proxy" {
  type    = string
  default = "${env("https_proxy")}"
}

variable "name" {
  type    = string
  default = "ubuntu-20.04"
}

variable "no_proxy" {
  type    = string
  default = "${env("no_proxy")}"
}

variable "ssh_password" {
  type    = string
  default = "ubuntu"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

source "qemu" "flat" {
  boot_command           = ["<wait>e<wait5>", "<down><wait><down><wait><down><wait2><end><wait5>", "<bs><bs><bs><bs><wait>autoinstall ---<wait><f10>"]
  boot_wait              = "2s"
  cpus                   = 2
  disk_size              = "4G"
  format                 = "raw"
  headless               = true
  http_directory         = var.http_directory
  iso_checksum           = "file:http://releases.ubuntu.com/20.04/SHA256SUMS"
  iso_target_path        = "packer_cache/ubuntu.iso"
  iso_url                = "https://releases.ubuntu.com/focal/ubuntu-20.04.4-live-server-amd64.iso"
  memory                 = 1024
  qemuargs               = [["-vga", "qxl"], ["-device", "virtio-blk-pci,drive=drive0,bootindex=0"], ["-device", "virtio-blk-pci,drive=cdrom0,bootindex=1"], ["-device", "virtio-blk-pci,drive=drive1,bootindex=2"], ["-drive", "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd"], ["-drive", "if=pflash,format=raw,file=OVMF_VARS.fd"], ["-drive", "file=output-qemu/packer-qemu,if=none,id=drive0,cache=writeback,discard=ignore,format=raw"], ["-drive", "file=seeds-flat.iso,format=raw,cache=none,if=none,id=drive1"], ["-drive", "file=packer_cache/ubuntu.iso,if=none,id=cdrom0,media=cdrom"]]
  shutdown_command       = "sudo -S shutdown -P now"
  ssh_handshake_attempts = 500
  ssh_password           = var.ssh_password
  ssh_timeout            = "45m"
  ssh_username           = var.ssh_username
  ssh_wait_timeout       = "45m"
}

build {
  sources = ["source.qemu.flat"]

  provisioner "file" {
    destination = "/tmp/"
    sources     = ["${path.root}/scripts/curtin-hooks", "${path.root}/scripts/install-custom-packages", "${path.root}/scripts/setup-bootloader", "${path.root}/packages/custom-packages.tar.gz"]
  }

  provisioner "shell" {
    environment_vars  = ["HOME_DIR=/home/ubuntu", "http_proxy=${var.http_proxy}", "https_proxy=${var.https_proxy}", "no_proxy=${var.no_proxy}"]
    execute_command   = "echo 'ubuntu' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
    expect_disconnect = true
    scripts           = ["${path.root}/scripts/curtin.sh", "${path.root}/scripts/networking.sh", "${path.root}/scripts/cleanup.sh"]
  }

  post-processor "shell-local" {
    inline         = ["IMG_FMT=raw", "source ../scripts/setup-nbd", "OUTPUT=$${OUTPUT:-custom-ubuntu.tar.gz}", "source ./scripts/tar-rootfs"]
    inline_shebang = "/bin/bash -e"
  }
}
