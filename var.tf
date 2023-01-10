variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "aws_keypair" {
  type = string
  default = "laboffering"
}

variable "region" {
  type = string
}

variable "zone_primary" {
  type = string
}

variable "zone_secondary" {
  type = string
}

variable "Application_Name" {
  type = string
}

variable "lab_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "master_price" {
  type = string
}

variable "node_price" {
  type = string
}

variable "master_count" {
  type = number
}

variable "email" {
  type = string
}

variable "epoch_id" {
  type = string
}

variable "org_id" {
  type = number
  default = "001"
}

##MASTER

variable "master_instance_type" {
  type = string
}

variable "master_instance_storage" {
  type = number

}

variable "master_ports" {
  type = list(number)
  default = [9090]
}

locals {
  master_ports = var.master_ports
}
##NODE

variable "node_instance_type" {
  type = string
}
variable "node_instance_storage" {
  type = number
}

variable "node_ports" {
  type = list(number)
  default = [9090]
}
locals {
  node_ports = var.node_ports
}

##AMI

data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
