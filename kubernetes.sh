#!/usr/bin/env bash

useradd -s /bin/bash -m training
echo -e "Test@123\nTest@123" | passwd training >/dev/null 2>&1
echo "training ALL=(ALL)      NOPASSWD: ALL" >> /etc/sudoers
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin forced-commands-only/#PermitRootLogin forced-commands-only/g' /etc/ssh/sshd_config

useradd -s /bin/bash -m automation
echo -e "Trip@123\nTrip@123" | passwd automation >/dev/null 2>&1
echo "automation ALL=(ALL)      NOPASSWD: ALL" >> /etc/sudoers
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin forced-commands-only/#PermitRootLogin forced-commands-only/g' /etc/ssh/sshd_config

useradd -s /bin/bash -m labasservice
echo -e "Labsteam@123\nLabsteam@123" | passwd labasservice >/dev/null 2>&1
echo "labasservice ALL=(ALL)      NOPASSWD: ALL" >> /etc/sudoers

systemctl restart ssh >/dev/null 2>&1
systemctl restart sshd >/dev/null 2>&1

apt update -y
apt install -y acct
systemctl enable --now acct

apt install -y awscli
apt-get install -y apt-transport-https curl
apt install -y docker.io
systemctl enable --now docker
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg > cloud.key.io
apt-key add cloud.key.io && rm -rf cloud.key.io
sh -c 'echo deb https://apt.kubernetes.io/ kubernetes-xenial main' >> /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet=1.21.1-00 kubeadm=1.21.1-00 kubectl=1.21.1-00
swapoff -a
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
sed -i 's/$KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS/$KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS --cloud-provider=aws/g'  /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
host=$(hostname)
hostname=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
sed -i "2 a $host $hostname" /etc/hosts
hostnamectl set-hostname $hostname
systemctl daemon-reload
sleep 100
region=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)
id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
lab_name=$(aws ec2 describe-tags  --filters "Name=tag:kube_master,Values=*" "Name=resource-id,Values=$id" --region ${region:: -1} | awk '{print $2}' | tail -n 4 | head -n 1 | tr -d '"')
Application_Name=$(aws ec2 describe-tags  --filters "Name=tag:application_name,Values=*" "Name=resource-id,Values=$id" --region ${region:: -1} | awk '{print $2}' | tail -n 4 | head -n 1 | tr -d '"')
count=$(aws ec2 describe-tags  --filters "Name=tag:$lab_name-kube_master,Values=*" "Name=resource-id,Values=$id" --region ${region:: -1} | awk '{print $2}' | tail -4 | head -n 1 | tr -d '"')
private_ip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
aws ssm put-parameter --name "${lab_name}-${Application_Name}-master_ip-${count}" --value "$private_ip" --type String --region ${region:: -1}
lb_dns=$(aws ssm get-parameters --names ${lab_name}-${Application_Name}-elb-dns-$count --region ${region:: -1} --output text | awk '{print $7}')
aws elb register-instances-with-load-balancer --load-balancer-name ${lb_dns:: 12}-${Application_Name}-elb-${count} --instances $id --region ${region:: -1}
cluster_name=$(aws ssm get-parameters --names ${lab_name}-${Application_Name}-cluster-name --region ${region:: -1} --output text | awk '{print $7}')
echo $lb_dns > /tmp/loadbalancer_dns.txt
echo $cluster_name > /tmp/clustername.txt
echo $count > /tmp/count.txt
echo $lab_name > /tmp/lab_name.txt
echo $region > /tmp/region.txt
echo $id > /tmp/id.txt
echo $Application_Name > /tmp/application_name.txt
echo $private_ip > /tmp/private_ip.txt

cat << EOF > /tmp/kubeadm.config
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
  - groups:
      - system:bootstrappers:kubeadm:default-node-token
    token: dw1j4s.7ab6voh5lzh5e783
    ttl: 0s
    usages:
      - signing
      - authentication
kind: InitConfiguration
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: ${hostname}
  taints:
    - effect: NoSchedule
      key: node-role.kubernetes.io/master
---
apiServer:
  certSANs:
    - ${lb_dns}
  extraArgs:
    cloud-provider: aws
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: ${cluster_name}-${count}
controlPlaneEndpoint: ${lb_dns}:6443
controllerManager:
  extraArgs:
    cloud-provider: aws
    configure-cloud-routes: "false"
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.21.1
networking:
  podSubnet: 172.16.0.0/16
scheduler: {}
EOF

cat << EOF > /tmp/storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
EOF

cat << EOF > /tmp/dashboard-user.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

cat << EOF > /tmp/dashboard-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF


kubeadm init --config /tmp/kubeadm.config --ignore-preflight-errors=all >> /tmp/kubeinit.log 2>&1
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config
sed -i "13 a spec:\n  containers:\n  - command:\n    - kube-kubelet-service\n    - --cloud-provider=aws" /etc/kubernetes/kubelet.conf

kubectl --kubeconfig=/etc/kubernetes/admin.conf get cm -n kube-public cluster-info -o jsonpath={.data.kubeconfig} > /tmp/kubeadm-join.config

sleep 100
#kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.WEAVE_MTU=1337" --kubeconfig /etc/kubernetes/admin.conf > /tmp/network.log 2>&1
sudo kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml > /tmp/network.log 2>&1
sudo kubectl apply -f /tmp/storageclass.yaml > /tmp/storageclass.log 2>&1
sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml > /tmp/kube_dashboard.log 2>&1
sudo kubectl apply -f /tmp/dashboard-user.yaml
sudo kubectl apply -f /tmp/dashboard-rbac.yaml

sleep 150
aws ssm delete-parameter --name "${lab_name}-${Application_Name}-master_ip-${count}" --region ${region:: -1}
echo "worked" > /tmp/kubernetes.txt

