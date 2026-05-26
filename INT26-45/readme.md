# Kubernetes cluster (kubeadm) using Virtual Box

## Зміст

1 мастер та 2 воркери
![k8s-clustrer:](./screenshots/k8s-cluster.png)
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

![Deployment](./deployments/nginx-config.yaml)

```
[dimitr@k8s-master$] kubectl get deployment,rs,pod -n test-zastosunok -o wide
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES       SELECTOR
deployment.apps/nginx-demo   2/2     2            2           21m   nginx        nginx:1.25   app=nginx-demo

NAME                                    DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES       SELECTOR
replicaset.apps/nginx-demo-757ddcf8d5   2         2         2       21m   nginx        nginx:1.25   app=nginx-demo,pod-template-hash=757ddcf8d5

NAME                              READY   STATUS    RESTARTS   AGE   IP               NODE          NOMINATED NODE   READINESS GATES
pod/nginx-demo-757ddcf8d5-6kcjr   1/1     Running   0          21m   192.168.126.1    k8s-worker2   <none>           <none>
pod/nginx-demo-757ddcf8d5-7bc85   1/1     Running   0          21m   192.168.194.70   k8s-worker1   <none>           <none>

```

![Service](./services/nginx-service.yaml)
```
[dimitr@k8s-master$] kubectl apply -f nginx-service.yaml
service/nginx-demo-svc created
dimitr@k8s-master:~/k8s/services$ kubectl get svc -n test-zastosunok -o wide
NAME             TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE   SELECTOR
nginx-demo-svc   NodePort   10.105.168.110   <none>        80:30080/TCP   6s    app=nginx-demo

[dimitr@k8s-master$] kubectl get endpointslices -n test-zastosunok
NAME                   ADDRESSTYPE   PORTS   ENDPOINTS                      AGE
nginx-demo-svc-bm2ww   IPv4          80      192.168.126.1,192.168.194.70   4m32s

```
![Перевірка доступу з Master-node та Host](./screenshots/curl_to_nginx.png)

Scaling: 
```
[dimitr@k8s-master$] kubectl get pods -n test-zastosunok -o wide
NAME                          READY   STATUS    RESTARTS   AGE     IP               NODE          NOMINATED NODE   READINESS GATES
nginx-demo-757ddcf8d5-6kcjr   1/1     Running   0          4h50m   192.168.126.1    k8s-worker2   <none>           <none>
nginx-demo-757ddcf8d5-7bc85   1/1     Running   0          4h50m   192.168.194.70   k8s-worker1   <none>           <none>

[dimitr@k8s-master$] kubectl scale deployment nginx-demo -n test-zastosunok --replicas=5
deployment.apps/nginx-demo scaled

[dimitr@k8s-master$] kubectl get pods -n test-zastosunok -o wide
NAME                          READY   STATUS    RESTARTS   AGE     IP               NODE          NOMINATED NODE   READINESS GATES
nginx-demo-757ddcf8d5-5xhgc   0/1     Running   0          7s      192.168.194.71   k8s-worker1   <none>           <none>
nginx-demo-757ddcf8d5-6kcjr   1/1     Running   0          4h50m   192.168.126.1    k8s-worker2   <none>           <none>
nginx-demo-757ddcf8d5-7bc85   1/1     Running   0          4h50m   192.168.194.70   k8s-worker1   <none>           <none>
nginx-demo-757ddcf8d5-gfd9l   0/1     Running   0          7s      192.168.126.3    k8s-worker2   <none>           <none>
nginx-demo-757ddcf8d5-mzx74   0/1     Running   0          7s      192.168.126.2    k8s-worker2   <none>           <none>

[dimitr@k8s-master$] kubectl get deployment nginx-demo -n test-zastosunok
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
nginx-demo   3/5     5            3           4h51m

[dimitr@k8s-master$] kubectl get endpointslices -n test-zastosunok
NAME                   ADDRESSTYPE   PORTS   ENDPOINTS                                                AGE
nginx-demo-svc-bm2ww   IPv4          80      192.168.126.1,192.168.194.70,192.168.126.2 + 2 more...   16m

[dimitr@k8s-master$] kubectl get pods -n test-zastosunok -o wide
NAME                          READY   STATUS             RESTARTS      AGE     IP               NODE          NOMINATED NODE   READINESS GATES
nginx-demo-757ddcf8d5-5xhgc   1/1     Running            0             4m53s   192.168.194.71   k8s-worker1   <none>           <none>
nginx-demo-757ddcf8d5-6kcjr   1/1     Running            0             4h55m   192.168.126.1    k8s-worker2   <none>           <none>
nginx-demo-757ddcf8d5-7bc85   1/1     Running            0             4h55m   192.168.194.70   k8s-worker1   <none>           <none>
nginx-demo-757ddcf8d5-gfd9l   0/1     CrashLoopBackOff   5 (52s ago)   4m53s   192.168.126.3    k8s-worker2   <none>           <none>
nginx-demo-757ddcf8d5-mzx74   0/1     CrashLoopBackOff   5 (52s ago)   4m53s   192.168.126.2    k8s-worker2   <none>           <none>

[dimitr@k8s-master$] kubectl scale deployment nginx-demo -n test-zastosunok --replicas=3
deployment.apps/nginx-demo scaled

[dimitr@k8s-master$] kubectl get pods -n test-zastosunok -o wide
NAME                          READY   STATUS    RESTARTS   AGE     IP               NODE          NOMINATED NODE   READINESS GATES
nginx-demo-757ddcf8d5-5xhgc   1/1     Running   0          5m4s    192.168.194.71   k8s-worker1   <none>           <none>
nginx-demo-757ddcf8d5-6kcjr   1/1     Running   0          4h55m   192.168.126.1    k8s-worker2   <none>           <none>
nginx-demo-757ddcf8d5-7bc85   1/1     Running   0          4h55m   192.168.194.70   k8s-worker1   <none>           <none>
```
![Перевірка доступу з Master-node та Host](./screenshots/curl_to_worker_nginx.png)


- Мігрувати власний Docker-образ зі свого registry (imagePullSecrets + ConfigMap/Secret)

Результат дз:  