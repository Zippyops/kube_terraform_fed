#!/usr/bin/env bash

Application_Name="kubernetes"


echo ${Application_Name} > /tmp/app.txt
if [ ${Application_Name} = "kubernetes" ]; then
        useradd -s /bin/bash -m training
	      echo -e "Test@123\nTest@123" | passwd training >/dev/null 2>&1
	      echo "training ALL=(ALL)      NOPASSWD: ALL" >> /etc/sudoers

        useradd -s /bin/bash -m labasservice
        echo -e "Labsteam@123\nLabsteam@123" | passwd labasservice >/dev/null 2>&1
        echo "labasservice ALL=(ALL)      NOPASSWD: ALL" >> /etc/sudoers

	      sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sed -i 's/PermitRootLogin forced-commands-only/#PermitRootLogin forced-commands-only/g' /etc/ssh/sshd_config
        systemctl restart ssh >/dev/null 2>&1
        systemctl restart sshd >/dev/null 2>&1

        apt update -y
        apt install -y acct
        systemctl enable --now acct

        apt-get install -y apt-transport-https curl
        apt install -y docker.io
        apt install -y awscli
        systemctl enable --now docker
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg > cloud.key.io
        apt-key add cloud.key.io && rm -rf cloud.key.io
        sh -c 'echo deb https://apt.kubernetes.io/ kubernetes-xenial main' >> /etc/apt/sources.list.d/kubernetes.list
        apt-get update -y
        apt-get install -y kubelet=1.21.1-00 kubeadm=1.21.1-00 kubectl=1.21.1-00
        swapoff -a
        sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
        sed -i "s/cgroupfs/systemd/g" /var/lib/kubelet/config.yaml
        sed -i 's/$KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS/$KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS --cloud-provider=aws/g'  /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
        host=$(hostname)
        hostname=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
        sed -i "2 a $host $hostname" /etc/hosts
        hostnamectl set-hostname $hostname
        systemctl daemon-reload
        apt install -y sshpass >/dev/null 2>&1
        sleep 200
        region=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)
        id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
        lab_name=$(aws ec2 describe-tags  --filters "Name=tag:kube_nodes,Values=*" "Name=resource-id,Values=$id" --region ${region:: -1} | awk '{print $2}' | tail -n 4 | head -n 1 | tr -d '"')
        Application_Name=$(aws ec2 describe-tags  --filters "Name=tag:application_name,Values=*" "Name=resource-id,Values=$id" --region ${region:: -1} | awk '{print $2}' | tail -n 4 | head -n 1 | tr -d '"')
        count=$(aws ec2 describe-tags  --filters "Name=tag:$lab_name-kube_nodes,Values=*" "Name=resource-id,Values=$id" --region ${region:: -1} | awk '{print $2}' | tail -4 | head -n 1 | tr -d '"')
        sleep 60
        master_ip=$(aws ssm get-parameters --names ${lab_name}-${Application_Name}-master_ip-${count} --region ${region:: -1} --output text | awk '{print $7}')
        echo $master_ip > /tmp/master_ip.txt
        echo $count > /tmp/count.txt
        echo $region > /tmp/region.txt
        echo $lab_name > /tmp/lab_name.txt
        echo $Application_Name > /tmp/application_name.txt
        echo $id > /tmp/id.txt

        cat << EOF > /tmp/kubeadm-node.config
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  tlsBootstrapToken: "dw1j4s.7ab6voh5lzh5e783"
  file:
    kubeConfigPath: "/tmp/kubeadm-join.config"
nodeRegistration:
  name: "${hostname}"
  kubeletExtraArgs:
    cloud-provider: aws
EOF
        sleep 100
        sshpass -p "Test@123" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no training@$master_ip:/tmp/kubeadm-join.config /tmp/kubeadm-join.config >> /tmp/master_joinfile.log 2>&1
        kubeadm join --config /tmp/kubeadm-node.config "$master_ip:6443" --ignore-preflight-errors=all >> /tmp/joincluster.log 2>&1
	echo "worked" > /tmp/kubernetes_node.txt
else
  echo "bye"
fi

