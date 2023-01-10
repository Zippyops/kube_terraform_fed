#!/usr/bin/env bash

sleep 20
id=$(aws ec2 describe-spot-instance-requests --region ${region} --filters Name=tag:${lab_name}-${Application_Name},Values=nodes-${count_no} Name=state,Values=active | grep -i InstanceId | awk '{print $2}' | tr -d '"' | tr -d ',')
aws ec2 create-tags --resources $id --tags Key=Name,Value=${lab_name}-${Application_Name}-nodes-trainee-${count_no} Key=${lab_name}-${Application_Name},Value=nodes-${count_no} Key=${lab_name}-kube_nodes,Value=${count_no} Key=kube_nodes,Value=${lab_name} Key=application_name,Value=${Application_Name} Key=labname,Value=${lab_name} Key=email,Value=${email} Key=epoch_id,Value=${epoch_id} Key=kubernetes.io/cluster/${cluster_name}-${count_no},Value=owned --region ${region}
