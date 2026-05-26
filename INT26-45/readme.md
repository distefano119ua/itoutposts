# Kubernetes cluster (kubeadm) using Virtual Box

## Зміст

1 мастер та 2 воркери
![k8s-clustrer:](k8s-cluster.png)
---

## Розгорнути Kubernetes кластер вручну (kubeadm), підключити worker ноду та задеплоїти застосунок із власного Docker Registry


Обов'язково:

- Підняти control plane через `kubeadm init`, підключити worker через `kubeadm join` → усі ноди `Ready`
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.56.10:6443 --token 9k8as9.uk9jkq6tslo3sdd \
	--discovery-token-ca-cert-hash sha256:b0c3bbb815918f3b3ee41c551a7cbb080ab1d77626e21sss 
```


- Задеплоїти тестовий застосунок (Deployment + Service), відпрацювати: scaling, rolling update, rollback, self-healing

- Мігрувати власний Docker-образ зі свого registry (imagePullSecrets + ConfigMap/Secret)

Результат дз:  