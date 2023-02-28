#!/usr/bin/bash

export SCRIPT_NAME="$(basename "$0")"
export K8S_LONG=k8s-version
export K8S_SHORT=k8sv

usage() {
    cat << EOF
$SCRIPT_NAME - installs a single-node k8s cluster of the specified version

Script requirements:
	* OS: Ubuntu
	* service provisioning and management subsystem: systemd

If k8s version is not defined in the script parameter, version $KUBE_VERSION will be used for installation

Usage:
    ./$SCRIPT_NAME [flags]

Flags:
    -$K8S_SHORT, --$K8S_LONG            specify the required version of k8s to install
EOF
}

check_os () {
	echo $'\nCheck OS is Ubuntu...'
    if ! cat /etc/*release | grep ^NAME | grep Ubuntu &>/dev/null; then 
		echo "This script works on Linux Ubuntu only!"; exit 1
	fi
	echo $'OK\n'
}
check_os


KUBE_VERSION=1.23.16-00

if [[ $# -eq 0 ]] ; then
	echo $'\n'
    echo $"You did not choose k8s version, version $KUBE_VERSION will be installed."
	echo $'\n'
else
   case "$1" in
     -h | --help) usage; exit 0;;
     -${K8S_SHORT} | --${K8S_LONG}) if [[ "$2" =~ [0-9].[0-9][0-9].([0-9]{1,2})-[0-9][0-9]$ ]]; then KUBE_VERSION="$2" && echo $"k8s $2 version will be installed."; else echo "Error: $2 has wrong k8s version format, it must be like 1.20.0-00"; exit 1; fi; ;;
     *) echo "$1 parameter is undefined"; exit 1;;
   esac
fi


install_k8s () {
	sudo apt-get update

	echo $'\nInstall jq\n'
	sudo apt-get install -y jq
	
	echo $'\nInstall Docker\n'
	DOCKER_VERSION=5:20.10.23~3-0~ubuntu-focal
	
	sudo apt-get install -y apt-transport-https ca-certificates curl
	sudo apt-get remove docker docker-engine docker.io containerd runc 2>/dev/null
	sudo apt-get update
	sudo apt-get -y install \
		ca-certificates \
		curl \
		gnupg \
		lsb-release
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
	  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	apt-cache madison docker-ce | awk '{ print $3 }'

	sudo apt-get install -y docker-ce=$DOCKER_VERSION docker-ce-cli=$DOCKER_VERSION containerd.io docker-compose-plugin
	sudo groupadd -f docker
	sudo usermod -aG docker $USER
	sudo systemctl enable docker

	sudo chmod 666 /var/run/docker.sock
	docker version
	
	cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

	sudo systemctl daemon-reload
	sudo systemctl restart docker	

	echo $'\nInstall runc\n'
	curl -fsSLo runc.amd64 \
	  https://github.com/opencontainers/runc/releases/download/v1.1.3/runc.amd64
	sudo install -m 755 runc.amd64 /usr/local/sbin/runc

	echo $'\nPrepare environment for k8s\n'
	curl -fsSLo cni-plugins-linux-amd64-v1.1.1.tgz \
	  https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
	sudo mkdir -p /opt/cni/bin
	sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz

	cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

	sudo modprobe -a overlay br_netfilter

	# sysctl params required by setup, params persist across reboots
	cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

	# Apply sysctl params without reboot
	sudo sysctl --system
	
	# Add Kubernetes GPG key
	sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
	  https://packages.cloud.google.com/apt/doc/apt-key.gpg

	# Add Kubernetes apt repository
	echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" \
	  | sudo tee /etc/apt/sources.list.d/kubernetes.list

	# Fetch package list
	sudo apt-get update

	# install k8s
	sudo apt-get install -y kubelet=$KUBE_VERSION kubeadm=$KUBE_VERSION kubectl=$KUBE_VERSION

	# Prevent them from being updated automatically
	sudo apt-mark hold kubelet kubeadm kubectl

	# See if swap is enabled
	swapon --show
	# Turn off swap
	sudo swapoff -a
	# Disable swap completely
	sudo sed -i -e '/swap/d' /etc/fstab

	sudo kubeadm init --pod-network-cidr=10.244.0.0/16

	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config

	kubectl taint nodes $(hostname) node-role.kubernetes.io/master:NoSchedule-

	echo $'\nInstall kube-flannel\n'
	kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

	echo $'\nInstall helm\n'
	curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

	echo $'\nInstall openebs\n'
	helm repo add openebs https://openebs.github.io/charts
	kubectl create namespace openebs
	helm --namespace=openebs install openebs openebs/openebs

	echo $'\nInstall traefik\n'
	helm repo add traefik https://helm.traefik.io/traefik
	helm repo update
	helm install traefik traefik/traefik --set service.type=NodePort
	kubectl get svc -l app.kubernetes.io/instance=traefik-default

	export WEB_PORT=$(kubectl get svc -l app.kubernetes.io/instance=traefik-default -o=jsonpath='{.items[*].spec.ports[?(@.port==80)].nodePort}')
}


print_installation_results () {
	echo $'\n'
	echo $"Installation completed successfully.

Use the following info to access k8s cluster:

WEB_PORT=$WEB_PORT

For aceess via external ip-address you can use FLOATING_IP:WEB_PORT if you have one.
"
}

main(){
    install_k8s
	print_installation_results
}

main
