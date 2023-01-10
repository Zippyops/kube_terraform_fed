data "template_file" "master" {
  count = var.master_count
  template = file("tag_master.sh")
  vars = {
    region = var.region
    lab_name = var.lab_name
    Application_Name = var.Application_Name
    cluster_name  = var.cluster_name
    count_no = "${count.index + 1}"
    email = var.email
    epoch_id = var.epoch_id
  }
}

data "template_file" "master_volume" {
  count = var.master_count
  template = file("volume_master.sh")
  vars = {
    region = var.region
    lab_name = var.lab_name
    Application_Name = var.Application_Name
    count_no = "${count.index + 1}"
  }
}

data "template_file" "nodes" {
  count = var.master_count
  template = file("tag_nodes.sh")
  vars = {
    region = var.region
    lab_name = var.lab_name
    Application_Name = var.Application_Name
    cluster_name  = var.cluster_name
    count_no = "${count.index + 1}"
    email = var.email
    epoch_id = var.epoch_id
  }
}

data "template_file" "nodes_volume" {
  count = var.master_count
  template = file("volume_nodes.sh")
  vars = {
    region = var.region
    lab_name = var.lab_name
    Application_Name = var.Application_Name
    count_no = "${count.index + 1}"
  }
}
