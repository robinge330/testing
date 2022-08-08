#!/bin/bash

### Setting hostname

logger -s "Setting hostnames"
#export HOSTNAME NetOneNode
sudo hostname $HOSTNAME
sudo hostnamectl set-hostname $HOSTNAME

echo $HOSTNAME
echo "ending hostname"

#1 Clone the ric-plt/dep git repository
logger -s "Cloning"
git clone "https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep"

#2 Install kubernetes, kubernetes-CNI, helm and docker
logger -s "Changing the Flannel file"
#flannel developers moved the flannel pod to the namespace kube-flannel and not kube-system 
sudo sed -i 's|kubectl apply -f "https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"|kubectl apply -f "https://raw.githubusercontent.com/flannel-io/flannel/9de10c12c8266b0cfe09bc0d5c969ae28832239f/Documentation/kube-flannel.yml"|g' /root/ric-dep/bin/install_k8s_and_helm.sh

logger -s "Installing K8s"
/root/ric-dep/bin/install_k8s_and_helm.sh
#configure docker to use proxy
logger -s "configure docker to use proxy"
sudo mkdir -p /etc/systemd/system/docker.service.d

cat <<EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://192.168.181.164:3128/"
Environment="HTTPS_PROXY=http://192.168.181.164:3128/"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker

sudo mkdir -p /root/ric-dep/deploy-script/

sudo echo "
#!/bin/sh -xvf
logger -s "Starting master.sh execution"
echo \"Starting master.sh execution\"
#Validation  kubernetes
logger -s "Validating"

# install chartmuseum into helm and add ric-common templates
logger -s "Installing ric-common and helm"
echo \"Installing ric-common and helm\"
/root/ric-dep/bin/install_common_templates_to_helm.sh
echo \"Going to sleep\"
sleep 2
echo \"Ending the sleep\"

#Issue #1: The tiller image is no longer available in the registry mentioned in the helm charts helm/appmgr and helm/infrastructure

logger -s "Updating Tiller for appmgr and infrastructure helm"
logger -s "Backing up file and now applying"
echo \"Updating Tiller for appmgr and infrastructure helm\"
cp /root/ric-dep/helm/appmgr/values.yaml /root/ric-dep/helm/appmgr/values.yaml.old
cp /root/ric-dep/helm/infrastructure/values.yaml /root/ric-dep/helm/infrastructure/values.yaml.old

sed -i 's/registry: gcr.io/registry: ghcr.io/g' /root/ric-dep/helm/appmgr/values.yaml
sed -i 's|name: kubernetes-helm/tiller|name: helm/tiller|g' /root/ric-dep/helm/appmgr/values.yaml
sed -i 's|tag: v2.12.3|tag: v2.16.12|g' /root/ric-dep/helm/appmgr/values.yaml

sed -i 's/registry: gcr.io/registry: ghcr.io/g' /root/ric-dep/helm/infrastructure/values.yaml
sed -i 's|name: kubernetes-helm/tiller|name: helm/tiller|g' /root/ric-dep/helm/infrastructure/values.yaml
sed -i 's|tag: v2.12.3|tag: v2.16.12|g' /root/ric-dep/helm/infrastructure/values.yaml

#Modify deployment receipe
#currently the example_recipe_latest_stable.yaml file is a symbolic link to the example_recipe_oran_e_release.yaml, which is NOT really the latest
#Please make it point to example_recipe_oran_f_release.yaml

logger -s "Modify deployment receipe"
logger -s "Pointing to f release"
echo \"Modify deployment receipe\"

ln -sfn /root/ric-dep/RECIPE_EXAMPLE/example_recipe_oran_f_release.yaml /root/ric-dep/RECIPE_EXAMPLE/example_recipe_latest_stable.yaml
sudo mkdir -p /root/ric-dep/RECIPE_EXAMPLE/PLATFORM
cp /root/ric-dep/RECIPE_EXAMPLE/example_recipe_latest_stable.yaml /root/ric-dep/RECIPE_EXAMPLE/PLATFORM/
sed -i 's/auxip: "10.0.0.1"/auxip: ""/g' /root/ric-dep/RECIPE_EXAMPLE/PLATFORM/example_recipe_latest_stable.yaml
sed -i 's/ricip: "10.0.0.1"/ricip: ""/g' /root/ric-dep/RECIPE_EXAMPLE/PLATFORM/example_recipe_latest_stable.yaml

#docker registry requires login credential is ignored
logger -s "Installing the recepie"
echo \"Installing the recepie\"
/root/ric-dep/bin/install -f /root/ric-dep/RECIPE_EXAMPLE/PLATFORM/example_recipe_latest_stable.yaml 
echo \"Installation completed\"
" | sudo tee -a /root/ric-dep/deploy-script/master.sh

chmod 755 /root/ric-dep/deploy-script/master.sh

logger -s "Job ended successfully"
logger -s "End of installation"
