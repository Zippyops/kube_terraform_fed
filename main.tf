provider "aws" {
  region     = var.region
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

data "aws_vpc" "default_vpc" {
  default = true
}
data "aws_subnet" "default_subnet" {
  vpc_id = data.aws_vpc.default_vpc.id
  availability_zone = "${var.region}${var.zone_primary}"
}
data "aws_subnet" "default_subnet-2" {
  vpc_id = data.aws_vpc.default_vpc.id
  availability_zone = "${var.region}${var.zone_secondary}"
}

resource "aws_spot_instance_request" "master" {
  count = var.master_count
  ami = data.aws_ami.ubuntu_ami.id
  instance_type = var.master_instance_type
  key_name = var.aws_keypair
  vpc_security_group_ids = [aws_security_group.default_master_security_group.id]
  subnet_id = data.aws_subnet.default_subnet.id
  iam_instance_profile = "training-kubernetes_master_profile"
  user_data = file("${var.Application_Name}.sh")
  instance_interruption_behavior = "stop"
  spot_price = var.master_price
  wait_for_fulfillment = true
  root_block_device {
    volume_size = var.master_instance_storage
    volume_type = "standard"
    delete_on_termination = true
  }
  tags = {
    Name              = "${var.lab_name}-${var.Application_Name}-master-trainee-${count.index + 1}"
    application_name  = var.Application_Name
    "${var.lab_name}-${var.Application_Name}" = "kube-master-${count.index + 1}"
  }
}

resource "null_resource" "master_tags" {
  count = var.master_count
  depends_on = [aws_spot_instance_request.master]
  triggers = {
    build_number = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "${data.template_file.master[count.index].rendered}"
  }
}

resource "null_resource" "master_volume_tags" {
  count = var.master_count
  depends_on = [null_resource.master_tags]
  triggers = {
    build_number = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "${data.template_file.master_volume[count.index].rendered}"
  }
}

resource "aws_spot_instance_request" "nodes-1" {
  count = var.master_count
  depends_on = [aws_spot_instance_request.master]
  ami = data.aws_ami.ubuntu_ami.id
  instance_type = var.node_instance_type
  key_name = var.aws_keypair
  vpc_security_group_ids = [aws_security_group.default_node_security_group.id]
  subnet_id = data.aws_subnet.default_subnet.id
  iam_instance_profile = "training-kubernetes_nodes_profile"
  user_data = file("${var.Application_Name}_node.sh")
  instance_interruption_behavior = "stop"
  spot_price = var.node_price
  wait_for_fulfillment = true
  root_block_device {
    volume_size = var.node_instance_storage
    volume_type = "standard"
    delete_on_termination = true
  }
  tags = {
    Name              = "${var.lab_name}-${var.Application_Name}-nodes-trainee-${count.index + 1}"
    application_name  = var.Application_Name
    "${var.lab_name}-${var.Application_Name}" = "nodes-${count.index + 1}"
  }
}

resource "null_resource" "nodes-1_tags" {
  count = var.master_count
  depends_on = [aws_spot_instance_request.nodes-1]
  triggers = {
    build_number = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "${data.template_file.nodes[count.index].rendered}"
  }
}

resource "null_resource" "nodes-1_volume_tags" {
  count = var.master_count
  depends_on = [null_resource.nodes-1_tags]
  triggers = {
    build_number = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "${data.template_file.nodes_volume[count.index].rendered}"
  }
}

resource "aws_spot_instance_request" "nodes-2" {
  count = var.master_count
  depends_on = [aws_spot_instance_request.master]
  ami = data.aws_ami.ubuntu_ami.id
  instance_type = var.node_instance_type
  key_name = var.aws_keypair
  vpc_security_group_ids = [aws_security_group.default_node_security_group.id]
  subnet_id = data.aws_subnet.default_subnet.id
  iam_instance_profile = "training-kubernetes_nodes_profile"
  user_data = file("${var.Application_Name}_node.sh")
  instance_interruption_behavior = "stop"
  spot_price = var.node_price
  wait_for_fulfillment = true
  root_block_device {
    volume_size = var.node_instance_storage
    volume_type = "standard"
    delete_on_termination = true
  }
  tags = {
    Name              = "${var.lab_name}-${var.Application_Name}-nodes-trainee-${count.index + 1}"
    application_name  = var.Application_Name
    "${var.lab_name}-${var.Application_Name}" = "nodes-${count.index + 1}"
  }
}

resource "null_resource" "nodes-2_tags" {
  count = var.master_count
  depends_on = [aws_spot_instance_request.nodes-2]
  triggers = {
    build_number = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "${data.template_file.nodes[count.index].rendered}"
  }
}

resource "null_resource" "nodes-2_volume_tags" {
  count = var.master_count
  depends_on = [null_resource.nodes-2_tags]
  triggers = {
    build_number = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "${data.template_file.nodes_volume[count.index].rendered}"
  }
}

resource "aws_ec2_tag" "default_subnet_tag-1" {
  count = var.master_count
  key = "kubernetes.io/cluster/${var.cluster_name}-${count.index + 1}"
  resource_id = data.aws_subnet.default_subnet.id
  value = "owned"
}
resource "aws_ec2_tag" "default_subnet_tag-2" {
  count = var.master_count
  key = "kubernetes.io/cluster/${var.cluster_name}-${count.index + 1}"
  resource_id = data.aws_subnet.default_subnet-2.id
  value = "owned"
}

resource "random_string" "lb_name" {
  count = var.master_count
  depends_on = [aws_spot_instance_request.master]
  length   = 12
  special  = false
  upper    = false
  number   = false
}

resource "aws_elb" "kube-master" {
  count = var.master_count
  name = "${random_string.lb_name[count.index].result}-${var.Application_Name}-elb-${count.index + 1}"
  depends_on = [random_string.lb_name]
  security_groups = [aws_security_group.default_master_security_group.id]
  subnets = [data.aws_subnet.default_subnet.id,data.aws_subnet.default_subnet-2.id]
  listener {
    instance_port = 6443
    instance_protocol = "TCP"
    lb_port = 6443
    lb_protocol = "TCP"
  }
  listener {
    instance_port = 6443
    instance_protocol = "TCP"
    lb_port = 443
    lb_protocol = "TCP"
  }
  health_check {
    healthy_threshold = 5
    interval = 60
    target = "TCP:6443"
    timeout = 30
    unhealthy_threshold = 5
  }
  tags = {
    Name = "${var.lab_name}-${var.Application_Name}-master-load-balancer"
    "kubernetes.io/cluster/${var.cluster_name}-${count.index + 1}" = "owned"
  }
}

resource "aws_ssm_parameter" "master-elb-dns" {
  count = var.master_count
  depends_on = [aws_elb.kube-master]
  name = "${var.lab_name}-${var.Application_Name}-elb-dns-${count.index + 1}"
  type = "String"
  value = aws_elb.kube-master[count.index].dns_name
}

resource "aws_ssm_parameter" "cluster-name" {
  name = "${var.lab_name}-${var.Application_Name}-cluster-name"
  type = "String"
  value = var.cluster_name
}

resource "aws_security_group" "default_master_security_group" {
  vpc_id = data.aws_vpc.default_vpc.id

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    protocol = "tcp"
    to_port = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 53
    to_port = 53
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 10250
    to_port = 10259
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15000
    to_port = 15001
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15006
    to_port = 15006
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15008
    to_port = 15008
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15010
    to_port = 15010
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15012
    to_port = 15012
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15014
    to_port = 15014
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15020
    to_port = 15021
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15090
    to_port = 15090
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 9153
    to_port = 9153
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8443
    to_port = 8443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8472
    to_port = 8472
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 6784
    to_port = 6784
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.lab_name}-${var.Application_Name}_default_master_security_group"
    "${var.Application_Name}.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group" "master_security_group" {
  vpc_id = data.aws_vpc.default_vpc.id

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  dynamic "ingress" {
    for_each = local.master_ports
    content {
      description = "description ${ingress.key}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  tags = {
    Name = "${var.lab_name}-${var.Application_Name}_master_security_group"
  }
}

resource "aws_security_group" "default_node_security_group" {
  vpc_id = data.aws_vpc.default_vpc.id


  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    protocol = "tcp"
    to_port = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15000
    to_port = 15001
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15006
    to_port = 15006
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15008
    to_port = 15008
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15010
    to_port = 15010
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15012
    to_port = 15012
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15014
    to_port = 15014
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15020
    to_port = 15021
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 15090
    to_port = 15090
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8443
    to_port = 8443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8472
    to_port = 8472
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 10255
    to_port = 10256
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.lab_name}-${var.Application_Name}_default_node_security_group"
    "${var.Application_Name}.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group" "node_security_group" {
  vpc_id = data.aws_vpc.default_vpc.id

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  dynamic "ingress" {
    for_each = local.node_ports
    content {
      description = "description ${ingress.key}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  tags = {
    Name = "${var.lab_name}-${var.Application_Name}_node_security_group"
  }
}
