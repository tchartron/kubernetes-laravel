# kubernetes-laravel
Laravel deployment to kubernetes cluster  
- [Minikube](https://github.com/tchartron/kubernetes-laravel#minikube-cluster)
- [Ovh manual cluster setup](https://github.com/tchartron/kubernetes-laravel#ovh-manual-setup-using-3-nodes)
- [Ovh managed kubernetes cluster](https://github.com/tchartron/kubernetes-laravel#ovh-managed-kubernetes-cluster)

___

## Common steps

### Pre image building steps
Add a dockerignore file to the root of your laravel app to avoid copying `vendor` and `node_modules` folders during the build process  
```
cat > laravel-app/.dockerignore << EOF
/vendor
/node_modules
EOF
```

### Build images
Example of building a php image for a laravel application.  
Using two tags to update the latest tag and pin the image to a specific version at the same time  
Execute from the root of this repository for docker build context  
```
docker build -t registry.gitlab.com/devops0077/kubernetes-laravel/php-cli:0.0.1 -f docker/php/8.1-alpine3.16/Dockerfile --target cli .
docker build -t registry.gitlab.com/devops0077/kubernetes-laravel/cron:0.0.1 -f docker/php/8.1-alpine3.16/Dockerfile --target cron .
docker build -t registry.gitlab.com/devops0077/kubernetes-laravel/php-fpm:0.0.1 -f docker/php/8.1-alpine3.16/Dockerfile --target fpm .
docker build -t registry.gitlab.com/devops0077/kubernetes-laravel/nginx:0.0.1 -f docker/nginx/1.22-alpine/Dockerfile --target nginx .
```

### Push images
```
docker push registry.gitlab.com/devops0077/kubernetes-laravel/php-cli:0.0.1
docker push registry.gitlab.com/devops0077/kubernetes-laravel/cron:0.0.1
docker push registry.gitlab.com/devops0077/kubernetes-laravel/php-fpm:0.0.1
docker push registry.gitlab.com/devops0077/kubernetes-laravel/nginx:0.0.1
```

### Makefile usage
```
make docker VERSION=0.0.1
```

___

## Minikube cluster
- 1 Node
- 1 Mysql instance
- 2 Nginx instances
- 3 Php-fpm instances
- 6 Redis instances running as a redis cluster
- 1 Cronjob instance running as kubernetes CronJob
- 1 Queue worker for default queue

---

### Install Docker
```
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
# Post install steps
sudo groupadd docker
sudo usermod -aG docker $USER
sudo systemctl enable docker.service
```

### Minikube setup
```
brew install minikube
minikube start
kubectl get pods -A
# Aliases
mk = minikube kubectl --
k = kubectl
```

### Private registry access
```
# Create deploy token https://gitlab.com/devops0077/kubernetes-laravel/-/settings/repository
k create secret docker-registry gitlab-kubernetes-laravel-cred --docker-server=registry.gitlab.com --docker-username=<deploy-token-username> --docker-password=<deploy-token-password> --docker-email=<account-email>
```

### Deployments
```
# Fpm before nginx is important because nginx deployment needs service php-fpm-svc to exist for FPM_HOST env
mk apply -f kubernetes/minikube/mysql
mk apply -f kubernetes/minikube/php
mk apply -f kubernetes/minikube/nginx
# Queues
mk apply -f kubernetes/minikube/queues
# Scheduler
# Two option : 1 run in K8s cronjob component / 2 Run in a php cli container
# 1)
mk apply -f kubernetes/minikube/crons/cronjob
# 2)
mk apply -f kubernetes/minikube/crons/container

# Then watch creation of pods
mk get pod --watch
# Run laravel migrations
mk exec php-fpm-deployment-bc4fd9664-fl6sx -- php artisan migrate --force
```

### Deploy redis cluster
```
mk apply -f kubernetes/minikube/redis
mk get pod --watch

# Activate cluster
# Get nodes ip
#REDIS_NODES=$(kubectl get pods  -l app=redis -l tier=backend -n default -o json | jq -r '.items | map(.status.podIP) | join(":6379 ")'):6379
#kubectl exec -it redis-cluster-0 -n default -- redis-cli --cluster create --cluster-replicas 1 ${REDIS_NODES}
#kubectl get pods -l app=redis-cluster -o jsonpath='{range.items[*]}{.status.podIP}

mk get pod -o wide
mk exec -it redis-cluster-0 -- sh
redis-cli --cluster create --cluster-replicas 1 172.17.0.6:6379 172.17.0.7:6379 172.17.0.8:6379 172.17.0.9:6379 172.17.0.10:6379 172.17.0.11:6379 -a a-very-complex-password-here --cluster-yes
redis-cli --cluster create --cluster-replicas 1 172.17.0.10:6379 172.17.0.11:6379 172.17.0.12:6379 172.17.0.13:6379 172.17.0.14:6379 172.17.0.15:6379 -a a-very-complex-password-here --cluster-yes

# Check replication in different redis pods
redis-cli -a a-very-complex-password-here
info replication
cluster info

# Side note troubleshooting PV stuck in Terminating state when running kubectl delete -f kubernetes/minikube/redis (for each volumes stuck)
mk patch pv redis-local-pv1 -p '{"metadata":{"finalizers":null}}'
```

### Check mysql, php, nginx and redis are correctly running
```
mk port-forward pod/nginx-deployment-xxxxxxx-xxxx 8181:80 
mk port-forward svc/nginx-svc 8181:80 
```

### Exposing the app using ingress
```
# Enable ingress addon in minikube (nginx-ingress)
minikube addons enable ingress
# Check ingress is running 
mk get pod -n ingress-nginx
# Enable tunnel in one terminal
minikube tunnel
# Add this to your /etc/hosts
127.0.0.1 laravel.kube
# Create ingress controller
mk apply -f kubernetes/minikube/ingress.yml
# Type password in minikube tunnel terminal
# You should be able to visit http://laravel.kube in your browser
# Check php pod serving request using /server url
# Check nginx pod serving request using Response headers server ip
```

___

## OVH Manual setup using 3 nodes
- 3 nodes d-2-4 (2 VCpu 4Go Ram 50Go NVMe)
- 3 Mysql instance with replication
- 2 Nginx instances
- 2 Php-fpm instances
- 3 Redis instances with replication and AOF persistence + Auth

---

### Setup the cluster
```

```


## OVH Managed Kubernetes Cluster
- 3 nodes d-2-4 (2 VCpu 4Go Ram 50Go NVMe
- 3 Mysql instance with replication
- 2 Nginx instances
- 2 Php-fpm instances
- 3 Redis instances with replication and AOF persistence + Auth

---

___

## Side notes

### Openstack client in docker container
```
docker run --rm -it\
  -e OS_AUTH_URL=https://auth.cloud.ovh.net/v3 \
  -e OS_IDENTITY_API_VERSION=3 \
  -e OS_PROJECT_NAME=xxxxxx \
  -e OS_PROJECT_DOMAIN_NAME=Default \
  -e OS_USERNAME=user-xxxxx \
  -e OS_USER_DOMAIN_NAME=Default \
  -e OS_PASSWORD=xxxxxxx \
  openstacktools/openstack-client:latest bash

# Commands
openstack help
openstack volume list
```

### Usefull commands
```
# kubectl
kubectl get pod -A
kubectl -n kube-system logs pods/my-pod-name
kubectl describe pods/my-pod-name
kubectl get [storageclass, service, deployment, statefulset, secret, configmap, persistentvolume, persistentvolumeclaim, ...] [name]
kubectl apply -f /path/to/manifests
kubectl delete -f /path/to/manifests
# kube-proxy

# minikube
minkube start
minikube status
minikube stop
minikube delete
minikube node list
minikube node add --worker
minikube node delete
```

___

## Sources
Official doc  
https://kubernetes.io/docs  
Thanks to **Chris Vermeulen** 🙌🏼 for this guide  
https://chris-vermeulen.com/laravel-in-kubernetes-part-1  
Kubeacademy videos and hands on labs from VMWare instructors  
https://kube.academy  
Great youtube channels KISS  
https://www.youtube.com/c/TechWorldwithNana  
90Days of DevOps  
https://github.com/MichaelCade/90DaysOfDevOps/blob/main/Days/day49.md  
CSI Cinder storage backend  
https://platform9.com/learn/v1.0/tutorials/asd  
MySql operator for Kubernetes  
https://github.com/mysql/mysql-operator  
3 nodes setup with kubadm  
https://k21academy.com/docker-kubernetes/three-node-kubernetes-cluster/  
Redis cluster with replication using redis sentinel  
https://www.containiq.com/post/deploy-redis-cluster-on-kubernetes  
Redis cluster  
https://medium.com/geekculture/redis-cluster-on-kubernetes-c9839f1c14b6  





___


### Notes for later 

# Mysql operator 
```
# Deploy the Custom Resource Definitions (CRDs)
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-crds.yaml
# Deploy MySQL Operator for Kubernetes
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-operator.yaml
# Check operator is running
kubectl get deployment -n mysql-operator mysql-operator
kubectl get deployment -A
# View CRDs
kubectl api-resources | grep mysql
kubectl api-resources | grep zalando

# Create secret as file
kubectl create secret generic mypwds \
        --from-literal=rootUser=root \
        --from-literal=rootHost=% \
        --from-literal=rootPassword="verysecret"

kubectl get secret mypwds -o yaml | tee kubernetes/mysql/operator/secret.yml
kubectl delete secret mypwds

# Add a minkube worker node
minikube node add --worker
# Deploy cluster and watch cluster creation
kubectl apply -f kubernetes/mysql/operator/innodb-cluster.yml
kubectl get innodbcluster --watch

```

### Openstack csi-cinder-plugin installation (Block Storage)
```
# Create cloud.conf from open-rc-file (see template)
# Encode cloud.conf file
cat kubernetes/ovhcloud/mysql/csi-cinder/cloud.conf | base64 |tr -d '\n'
# Create secret
kubectl create secret generic cloud-config
kubectl get secret cloud-config -o yaml | tee kubernetes/ovhcloud/mysql/csi-cinder/secret.yml
kubectl edit secret cloud-config
# Past cloud.conf base64 encoded / Edit namespace to kube-system
# Delete it
kubectl delete secret cloud-config

# Apply csi-cinder files to create components (driver, controllerplugin, nodeplugin, created secret)
kubectl apply -f kubernetes/ovhcloud/mysql/csi-cinder/
# Check plugins are running
kubectl get pods -n kube-system
#  Get information about CSI drivers running in cluster
kubectl get csidrivers.storage.k8s.io
```
