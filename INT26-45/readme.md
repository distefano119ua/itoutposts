# Kubernetes cluster (kubeadm) using Virtual Box

## Зміст 

1 мастер та 2 воркери
![k8s-clustrer:](./screenshots/k8s-cluster.png)

Обробленний АІ-шкою [readme](README_kubernetes_kubeadm_virtualbox.md)

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

[Deployment](./deployments/nginx-config.yaml)

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

[Service](./services/nginx-service.yaml)
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
├── Node: k8s-worker1
│   └── label: role=app
│
├── Node: k8s-worker2
│   └── label: role=db
│
└── Namespace: itoutposts
    │
    ├── ConfigMap: backend-config
    │   └── env для backend:
    │       ├── APP_LOGS_PATH
    │       ├── ALERT_EMAIL
    │       ├── SERVICE_NAME
    │       ├── DB_NAME
    │       ├── COLLECTION_NAME
    │       ├── DATASET_SLUG
    │       └── CSV_NAME
    │
    ├── Secret: backend-secret
    │   └── env для backend:
    │       └── MONGO_URI=mongodb://mongodb:27017
    │
    ├── Deployment: mongodb
    │   │
    │   ├── nodeSelector:
    │   │   └── role=db
    │   │
    │   ├── Pod: mongodb-xxxxx
    │   │   └── Container: mongodb
    │   │       ├── image: mongo:7
    │   │       ├── port: 27017
    │   │       └── volumeMount: /data/db
    │   │
    │   ├── PVC: mongo-pvc
    │   │   └── binds PV: mongo-pv
    │   │
    │   └── Service: mongodb
    │       ├── type: ClusterIP
    │       ├── port: 27017
    │       └── selector:
    │           └── app=mongodb
    │
    ├── Deployment: monitor-backend
    │   │
    │   ├── nodeSelector:
    │   │   └── role=app
    │   │
    │   ├── initContainer:
    │   │   └── wait-for-mongodb
    │   │
    │   ├── Pod: monitor-backend-xxxxx
    │   │   └── Container: backend
    │   │       ├── image: distefano119/pub-itoutposts:backend-1.1.1-arm64
    │   │       ├── port: 7000
    │   │       ├── envFrom: backend-config
    │   │       └── envFrom: backend-secret
    │   │
    │   └── Service: monitor-api
    │       ├── type: ClusterIP
    │       ├── port: 7000
    │       └── selector:
    │           └── app=monitor-backend
    │
    ├── Deployment: monitor-frontend
    │   │
    │   ├── nodeSelector:
    │   │   └── role=app
    │   │
    │   ├── Pod: monitor-frontend-xxxxx
    │   │   └── Container: frontend
    │   │       ├── image: distefano119/pub-itoutposts:frontend-1.0.1-arm64
    │   │       └── port: 5173
    │   │
    │   └── Service: monitor-frontend
    │       ├── type: ClusterIP
    │       ├── port: 5173
    │       └── selector:
    │           └── app=monitor-frontend
    │
    └── Deployment: nginx
        │
        ├── nodeSelector:
        │   └── role=app
        │
        ├── ConfigMap: nginx-config
        │   └── mounted as:
        │       └── /etc/nginx/conf.d/default.conf
        │
        ├── initContainers:
        │   ├── wait-for-frontend
        │   └── wait-for-backend
        │
        ├── Pod: nginx-xxxxx
        │   └── Container: nginx
        │       ├── image: nginx:1.27-alpine
        │       ├── port: 80
        │       └── proxy:
        │           ├── /      → monitor-frontend:5173
        │           └── /api/  → monitor-api:7000
        │
        └── Service: nginx
            ├── type: NodePort
            ├── port: 80
            ├── nodePort: 30080
            └── selector:
                └── app=nginx

External access:
Browser
└── http://192.168.56.10:30080
    └── Service: nginx
        └── Pod: nginx
            ├── /      → Service: monitor-frontend → Pod: frontend
            └── /api/  → Service: monitor-api      → Pod: backend
                                                  └── mongodb://mongodb:27017
                                                      └── Service: mongodb
                                                          └── Pod: mongodb
```


- Мігрувати власний Docker-образ зі свого registry (imagePullSecrets + ConfigMap/Secret)
`це було зроблено виключно для практики та виконання дз, далі це було виделено та зроблено по іншому`
Оскільки, на той момент часу в мене був публічний rgistry, а запит був у використанні imagePullSecrets + ConfigMap/Secret, то було вирішено використовувати master node
як private registry. Як це було реалізовано описано [тут](./k8s-registry/k8s-registry.md)

у private registry вже є обидва web images: 
```
curl -u dimitr:password \
  http://192.168.56.10:30500/v2/_catalog
{"repositories":["monitor-api","monitor-frontend"]}
```

Створити namespace для застосунку
```
dimitr@k8s-master:~$ kubectl create namespace cars-app
namespace/cars-app created
dimitr@k8s-master:~$ kubectl get ns
NAME              STATUS   AGE
cars-app          Active   7s
default           Active   43h
kube-node-lease   Active   43h
kube-public       Active   43h
kube-system       Active   43h
registry          Active   4h56m
```
Створити imagePullSecret
```
dimitr@k8s-master:~$ kubectl create secret docker-registry registry-secret \
  --docker-server=192.168.56.10:30500 \
  --docker-username=dimitr \
  --docker-password=password \
  -n cars-app
secret/registry-secret created
```

Перевірка Secrets
```
dimitr@k8s-master:~$ kubectl get secret -n cars-app
NAME              TYPE                             DATA   AGE
registry-secret   kubernetes.io/dockerconfigjson   1      3m25s
```

Створення тестового застосунку + imagePullSecret:
```
dimitr@k8s-master:~$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: image-pull-test
  namespace: cars-app
spec:
  imagePullSecrets:
    - name: registry-secret
  containers:
    - name: test
      image: 192.168.56.10:30500/monitor-api:v1
      command: ["sleep", "3600"]
EOF
pod/image-pull-test created

dimitr@k8s-master:~$ kubectl get pods -n cars-app -w
NAME              READY   STATUS    RESTARTS   AGE
image-pull-test   1/1     Running   0          20s
```

Йдемо далі, до наших вже додатків
Отже створюємо Secret до Mongodb, тут [yaml file](./secrets/mongodb-secret.yaml)

- застосувати: kubectl apply -f mongodb-secret.yaml
```
dimitr@k8s-master:~/k8s/secrets$ kubectl get secret -n cars-app mongodb-secret
NAME             TYPE     DATA   AGE
mongodb-secret   Opaque   2      5m42s
```

Тепер Secret для backend → MongoDB
Навіщо

Backend не повинен мати MongoDB password у Docker image або ConfigMap.

Кладемо повний URI в Secret: mongodb://cars_admin:cars_admin_password@mongodb:27017/cars_db?authSource=admin

- створюємо monitor-api-secret [yaml file](./secrets/monitor-api-secret.yaml)
- застосовуємо: kubectl apply -f monitor-api-secret.yaml
перевіряємо:
```
dimitr@k8s-master:~/k8s/secrets$ kubectl get secret -n cars-app monitor-api-secret
NAME                 TYPE     DATA   AGE
monitor-api-secret   Opaque   1      33s
```

Створити ConfigMap для backend (необхідні змінні, які не є sensetive)

тут [приклад](./configmaps/monitor-api-config.yaml), який використовувався

застосувати та перевірити



### Створення ролей
kubectl label node k8s-worker1 role=app
kubectl label node k8s-worker2 role=db
```
dimitr@k8s-master:~$ kubectl get nodes -L role
NAME          STATUS   ROLES           AGE   VERSION   ROLE
k8s-master    Ready    control-plane   45h   v1.34.8   
k8s-worker1   Ready    <none>          45h   v1.34.8   app
k8s-worker2   Ready    <none>          27h   v1.34.8   db
```

Наступний крок Деплой MongoDB з auth
[деплой](./deployments/mongodb.yaml) файл

Перед деплоєм потрібно створити local PersistentVolume на k8s-worker2, тому що у кластері немає dynamic provisioning. Команда перевірки:
```
dimitr@k8s-master:~$ kubectl get storageclass
No resources found
``` 
Для цього створюємо локальну директорію:
```
dimitr@k8s-worker2:~$ sudo mkdir -p /mnt/data/mongodb
dimitr@k8s-worker2:~$ sudo chmod 777 /mnt/data/mongodb
```

Створення PersistentVolume, [yaml](./persistentvolumes/mongodb-pv.yaml)
застосувати: kubectl apply -f mongodb-pv.yaml
```
dimitr@k8s-master:~$ kubectl get pv
NAME               CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    VOLUMEATTRIBUTESCLASS   REASON   AGE
mongodb-local-pv   2Gi        RWO            Retain           Available           local-storage   <unset>                          28s
```

Перед запуском деплою, mongodb:7 image має бути у внутрішньому registry

```
dimitr@k8s-master:~/k8s/deployments$ kubectl apply -f mongodb.yaml
service/mongodb created
statefulset.apps/mongodb created
```
```
dimitr@k8s-master:~$ kubectl get pvc -n cars-app
NAME                     STATUS   VOLUME             CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
mongodb-data-mongodb-0   Bound    mongodb-local-pv   2Gi        RWO            local-storage   <unset>                 80s
```

```
dimitr@k8s-master:~$ kubectl get pod,svc,pvc -n cars-app
NAME        READY   STATUS    RESTARTS   AGE    IP               NODE          NOMINATED NODE   READINESS GATES
mongodb-0   1/1     Running   0          100s   192.168.126.13   k8s-worker2   <none>           <none>


NAME              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
service/mongodb   ClusterIP   10.110.181.219   <none>        27017/TCP   19m

NAME                                           STATUS   VOLUME             CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mongodb-data-mongodb-0   Bound    mongodb-local-pv   2Gi        RWO            local-storage   <unset>                 14m
```

Mongodb відпрацювала:
```
dimitr@k8s-master:~$ kubectl exec -n cars-app mongodb-0 -- \
  mongosh -u cars_admin -p cars_admin_password --authenticationDatabase admin \
  --eval "db.adminCommand('ping')"
{ ok: 1 }
```

Тепер деплоїмо monitor-backend(aka monitor-api)
[yaml](./deployments/monitor-api.yaml) файл
```
dimitr@k8s-master:~/k8s/deployments$ kubectl apply -f monitor-api.yaml
deployment.apps/monitor-api created
service/monitor-api created
```
результат:
```
dimitr@k8s-master:~$ kubectl get pod,svc,pvc -n cars-app -o wide
NAME                               READY   STATUS    RESTARTS   AGE     IP               NODE          NOMINATED NODE   READINESS GATES
pod/mongodb-0                      1/1     Running   0          9m18s   192.168.126.13   k8s-worker2   <none>           <none>
pod/monitor-api-86f48985cf-pcxjl   1/1     Running   0          2m56s   192.168.194.77   k8s-worker1   <none>           <none>
pod/monitor-api-86f48985cf-q6k2t   1/1     Running   0          2m56s   192.168.194.78   k8s-worker1   <none>           <none>

NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE     SELECTOR
service/mongodb       ClusterIP   10.110.181.219   <none>        27017/TCP   28m     app=mongodb
service/monitor-api   ClusterIP   10.109.21.73     <none>        7000/TCP    2m56s   app=monitor-api

NAME                                           STATUS   VOLUME             CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/mongodb-data-mongodb-0   Bound    mongodb-local-pv   2Gi        RWO            local-storage   <unset>                 23m   Filesystem

dimitr@k8s-master:~$ kubectl logs -n cars-app monitor-api-86f48985cf-pcxjl
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:7000 (Press CTRL+C to quit)
INFO:     10.0.2.15:42080 - "GET /health HTTP/1.1" 200 OK
INFO:     10.0.2.15:42086 - "GET /health HTTP/1.1" 200 OK
INFO:     10.0.2.15:45834 - "GET /health HTTP/1.1" 200 OK
```

## Нашe рішення працює

![app](./screenshots/k8s-app.png)

```
dimitr@k8s-master:~$ kubectl get pod,svc,pvc -n itoutposts -o wide
NAME                                    READY   STATUS    RESTARTS   AGE   IP               NODE          NOMINATED NODE   READINESS GATES
pod/mongodb-8fb697f97-8gk48             1/1     Running   0          27m   192.168.126.19   k8s-worker2   <none>           <none>
pod/monitor-backend-7dbc547d88-7l9zx    1/1     Running   0          27m   192.168.194.89   k8s-worker1   <none>           <none>
pod/monitor-frontend-854dfb874d-sm7c7   1/1     Running   0          27m   192.168.194.87   k8s-worker1   <none>           <none>
pod/nginx-5886486cc6-tnmzg              1/1     Running   0          27m   192.168.194.88   k8s-worker1   <none>           <none>

NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/mongodb            ClusterIP   10.111.24.153   <none>        27017/TCP      27m   app=mongodb
service/monitor-api        ClusterIP   10.101.102.70   <none>        7000/TCP       27m   app=monitor-backend
service/monitor-frontend   ClusterIP   10.108.222.32   <none>        5173/TCP       27m   app=monitor-frontend
service/nginx              NodePort    10.99.209.3     <none>        80:30080/TCP   27m   app=nginx

NAME                              STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/mongo-pvc   Bound    mongo-pv   10Gi       RWO            local-storage   <unset>                 27m   Filesystem

NAME                         ENDPOINTS              AGE
endpoints/mongodb            192.168.126.19:27017   39m
endpoints/monitor-api        192.168.194.89:7000    39m
endpoints/monitor-frontend   192.168.194.87:5173    39m
endpoints/nginx              192.168.194.88:80      39m
```



## HELM:

можете спробувати у себе, поставити:
- images доступні
- встановіть тільки helm на мастер
- [тут все є](./helm/)


Команда запуску: `helm install itoutposts ./itoutposts`
Koманда видалення: `helm uninstall itoutposts ./itoutposts` 
```
dimitr@k8s-master:~$ helm list
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
itoutposts      default         1               2026-06-21 20:23:02.001477044 +0000 UTC deployed        itoutposts-0.1.0        1.16.0     
```