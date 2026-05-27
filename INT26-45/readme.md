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

Rolling update:
```
[dimitr@k8s-master$] kubectl set image deployment/nginx-demo nginx=nginx:1.26 -n test-zastosunok

[dimitr@k8s-master$] kubectl rollout status deployment/nginx-demo -n test-zastosunok
deployment "nginx-demo" successfully rolled out

[dimitr@k8s-master$] kubectl get deployment,rs,pod,svc -n test-zastosunok -o wide
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES       SELECTOR
deployment.apps/nginx-demo   3/3     3            3           5h5m   nginx        nginx:1.26   app=nginx-demo

NAME                                    DESIRED   CURRENT   READY   AGE     CONTAINERS   IMAGES       SELECTOR
replicaset.apps/nginx-demo-6c74d78f66   3         3         3       2m14s   nginx        nginx:1.26   app=nginx-demo,pod-template-hash=6c74d78f66
replicaset.apps/nginx-demo-757ddcf8d5   0         0         0       5h5m    nginx        nginx:1.25   app=nginx-demo,pod-template-hash=757ddcf8d5

NAME                              READY   STATUS    RESTARTS      AGE     IP               NODE          NOMINATED NODE   READINESS GATES
pod/nginx-demo-6c74d78f66-2s8r8   1/1     Running   0             117s    192.168.126.5    k8s-worker2   <none>           <none>
pod/nginx-demo-6c74d78f66-9sxrk   1/1     Running   1 (92s ago)   2m14s   192.168.194.72   k8s-worker1   <none>           <none>
pod/nginx-demo-6c74d78f66-rmc4f   1/1     Running   0             2m14s   192.168.126.4    k8s-worker2   <none>           <none>

NAME                     TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/nginx-demo-svc   NodePort   10.105.168.110   <none>        80:30080/TCP   29m   app=nginx-demo
dimitr@k8s-master:~/k8s/services$ 

[dimitr@k8s-master$] kubectl rollout history deployment/nginx-demo -n test-zastosunok
deployment.apps/nginx-demo 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

Roullback:
```
[dimitr@k8s-master$] kubectl rollout undo deployment/nginx-demo -n test-zastosunok

[dimitr@k8s-master$] kubectl rollout status deployment/nginx-demo -n test-zastosunok
Waiting for deployment "nginx-demo" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-demo" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-demo" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-demo" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-demo" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-demo" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "nginx-demo" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "nginx-demo" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "nginx-demo" rollout to finish: 2 of 3 updated replicas are available...
deployment "nginx-demo" successfully rolled out

[dimitr@k8s-master$] kubectl describe deployment nginx-demo -n test-zastosunok | grep Image
    Image:         nginx:1.25

[dimitr@k8s-master$] kubectl get deployment,rs,pod,svc -n test-zastosunok -o wide
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES       SELECTOR
deployment.apps/nginx-demo   3/3     3            3           5h12m   nginx        nginx:1.25   app=nginx-demo

NAME                                    DESIRED   CURRENT   READY   AGE     CONTAINERS   IMAGES       SELECTOR
replicaset.apps/nginx-demo-6c74d78f66   0         0         0       9m29s   nginx        nginx:1.26   app=nginx-demo,pod-template-hash=6c74d78f66
replicaset.apps/nginx-demo-757ddcf8d5   3         3         3       5h12m   nginx        nginx:1.25   app=nginx-demo,pod-template-hash=757ddcf8d5

NAME                              READY   STATUS    RESTARTS        AGE     IP               NODE          NOMINATED NODE   READINESS GATES
pod/nginx-demo-757ddcf8d5-q4nh9   1/1     Running   0               2m2s    192.168.126.7    k8s-worker2   <none>           <none>
pod/nginx-demo-757ddcf8d5-t584j   1/1     Running   4 (78s ago)     3m50s   192.168.194.73   k8s-worker1   <none>           <none>
pod/nginx-demo-757ddcf8d5-wdbcc   1/1     Running   2 (2m38s ago)   3m50s   192.168.126.6    k8s-worker2   <none>           <none>

NAME                     TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/nginx-demo-svc   NodePort   10.105.168.110   <none>        80:30080/TCP   36m   app=nginx-demo
```

Self-healing:
```
[dimitr@k8s-master$] kubectl get pods -n test-zastosunok
NAME                          READY   STATUS    RESTARTS        AGE
nginx-demo-757ddcf8d5-q4nh9   1/1     Running   0               5m22s
nginx-demo-757ddcf8d5-t584j   1/1     Running   4 (4m38s ago)   7m10s

[dimitr@k8s-master$] kubectl delete pod -n test-zastosunok nginx-demo-757ddcf8d5-t584j

[dimitr@k8s-master$] kubectl get pods -n test-zastosunok -w
NAME                          READY   STATUS    RESTARTS   AGE
nginx-demo-757ddcf8d5-q4nh9   1/1     Running   0          6m34s
nginx-demo-757ddcf8d5-zhhhs   0/1     Running   0          25s
nginx-demo-757ddcf8d5-zhhhs   0/1     Running   1 (0s ago)   32s
nginx-demo-757ddcf8d5-zhhhs   0/1     Running   2 (0s ago)   72s
nginx-demo-757ddcf8d5-zhhhs   0/1     Running   3 (0s ago)   112s
nginx-demo-757ddcf8d5-zhhhs   1/1     Running   3 (32s ago)   2m24s
```
### Графічна схема залежностей
```
Kubernetes Cluster
│
└── Namespace: test-zastosunok
    │
    ├── Deployment: nginx-demo
    │   │
    │   ├── ReplicaSet: nginx-demo-757ddcf8d5
    │   │   │
    │   │   ├── Pod: nginx-demo-xxxxx
    │   │   │   └── Container: nginx
    │   │   │
    │   │   └── Pod: nginx-demo-yyyyy
    │   │       └── Container: nginx
    │   │
    │   └── Desired state:
    │       ├── image: nginx:1.25
    │       └── replicas: 2
    │
    └── Service: nginx-demo-svc
        │
        ├── type: NodePort
        ├── nodePort: 30080
        └── selector:
            └── app=nginx-demo
                    │
                    ├── matches Pod: nginx-demo-xxxxx
                    └── matches Pod: nginx-demo-yyyyy
```


- Мігрувати власний Docker-образ зі свого registry (imagePullSecrets + ConfigMap/Secret)

Оскільки, на той момент часу в мене був публічний rgistry, а запит був у використанні imagePullSecrets + ConfigMap/Secret, то було вирішено використовувати master node
як private registry. Як це було реалізовано описано ![тут](./k8s-registry/k8s-registry.md)



Результат дз:  