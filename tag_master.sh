#!/usr/bin/env bash

sleep 20
id=$(aws ec2 describe-spot-instance-requests --region ${region} --filters Name=tag:${lab_name}-${Application_Name},Values=kube-master-${count_no} Name=state,Values=active | grep -i InstanceId | awk '{print $2}' | tr -d '"' | tr -d ',')
aws ec2 create-tags --resources $id --tags Key=Name,Value=${lab_name}-${Application_Name}-master-trainee-${count_no} Key=${lab_name}-${Application_Name},Value=kube-master-${count_no} Key=${lab_name}-kube_master,Value=${count_no} Key=kube_master,Value=${lab_name} Key=application_name,Value=${Application_Name} Key=labname,Value=${lab_name} Key=email,Value=${email} Key=epoch_id,Value=${epoch_id} Key=kubernetes.io/cluster/${cluster_name}-${count_no},Value=owned --region ${region}
