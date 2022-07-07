# Install mysql operator

[Github](https://github.com/mysql/mysql-operator)
[Official doc](https://dev.mysql.com/doc/mysql-operator/en/mysql-operator-preface.html)

### Create CRDs
`kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-crds.yaml`

### Deploy operator
`kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-operator.yaml`

### Check opeartor is running
`kubectl get deployment -n mysql-operator mysql-operato`

### View CRDs
`kubectl api-resources | grep mysql`
`kubectl api-resources | grep zalando`

### Create secret as file
```
kubectl create secret generic mypwds \
        --from-literal=rootUser=root \
        --from-literal=rootHost=% \
        --from-literal=rootPassword="verysecret"

kubectl get secret mypwds -o yaml | tee kubernetes/mysql/operator/secret-auto.yml
kubectl delete secret mypwds
```

### Deploy cluster and watch cluster creation
`kubectl apply -f kubernetes/mysql/operator/innodb-cluster.yml.yaml`
`kubectl get innodbcluster --watch`
