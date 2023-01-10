output "master_name" {
  value = aws_spot_instance_request.master.*.tags.Name
}
output "node-1_name" {
  value = aws_spot_instance_request.nodes-1.*.tags.Name
}
output "node-2_name" {
  value = aws_spot_instance_request.nodes-2.*.tags.Name
}
output "dns_name" {
  value = aws_elb.kube-master.*.dns_name
}
