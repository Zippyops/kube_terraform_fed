#!/usr/bin/env bash

id=$(aws ec2 describe-instances --region ${region} --filters Name=tag:${lab_name}-${Application_Name},Values=nodes-${count_no} | grep -i VolumeId | awk '{print $2}' | tr -d '"' | tr -d ',')
aws ec2 create-tags --resources $id --tags Key=Name,Value=${lab_name}-${Application_Name}-nodes-volume-trainee-${count_no} --region ${region}

