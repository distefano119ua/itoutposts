Сценарій:
Registry URL:  192.168.56.10:30500
Master node:   k8s-master
Registry auth: Basic Auth
Username:      dimitr
Password:      registry123
Namespace:     registry
Runtime:       containerd

1. Створити окремий namespace для registry

Навіщо
Registry — це окремий інфраструктурний компонент. Краще тримати його не в default, а в окремому namespace.
kubectl create namespace registry

Перевірка:
kubectl get ns

2. Підготувати директорію для зберігання образів на master node
Навіщо

Docker Registry повинен десь зберігати pushed images.
У нашій лабораторній схемі використовуємо локальну директорію на master node:
/opt/registry/data

Команди на k8s-master:
sudo mkdir -p /opt/registry/data
sudo chmod 755 /opt/registry/data

Перевірка:
ls -ld /opt/registry/data

3. Встановити інструмент для генерації htpasswd

Навіщо

Registry буде захищений через Basic Auth.
Для цього потрібен файл htpasswd, у якому зберігається користувач і hash пароля.
sudo apt update
sudo apt install -y apache2-utils

4. Створити htpasswd-файл

Навіщо

Docker Registry використовує цей файл для перевірки логіна й пароля.

Команда:
mkdir -p ~/registry-auth
htpasswd -Bbn dimitr registry123 > ~/registry-auth/htpasswd

Де: dimitr       = username
    registry123  = password

Перевірка cat ~/registry-auth/htpasswd:
dimitr:$2y$05$....
Пароль у відкритому вигляді не зберігається, тільки hash.

5. Створити Kubernetes Secret з htpasswd

Навіщо

Registry Pod повинен отримати файл /auth/htpasswd, але auth-дані не варто зберігати прямо в YAML-файлі.

Тому створюємо Secret:

kubectl create secret generic registry-auth \
  --from-file=htpasswd=$HOME/registry-auth/htpasswd \
  -n registry

Перевірка: kubectl get secret -n registry
registry-auth   Opaque

6. Створити Deployment + Service для registry

Навіщо

Ми запускаємо Docker Registry як звичайний Kubernetes workload.

Але є важливий нюанс: registry зберігає образи у локальній директорії master-ноди:

/opt/registry/data

Тому Pod registry треба запускати саме на k8s-master.

Для цього використовуємо:
nodeSelector:
  kubernetes.io/hostname: k8s-master

Але master node зазвичай має taint: node-role.kubernetes.io/control-plane:NoSchedule

Тому без tolerations Pod буде зависати в Pending.

Щоб уникнути конфлікту, додаємо:
tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"


![Файл private-registry.yaml](private-registry.yaml)

Застосувати: kubectl apply -f private-registry.yaml

7. Перевірити, що Pod запустився саме на master

```
dimitr@k8s-master:~$ kubectl get pod,svc -n registry -o wide
NAME                                  READY   STATUS    RESTARTS   AGE   IP                NODE         NOMINATED NODE   READINESS GATES
pod/private-registry-55854cdf-z98xm   1/1     Running   0          24s   192.168.235.196   k8s-master   <none>           <none>

NAME                       TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE     SELECTOR
service/private-registry   NodePort   10.102.126.172   <none>        5000:30500/TCP   8m27s   app=private-registry
```

8. Перевірити доступ до registry (З логіном і паролем)
```
dimitr@k8s-master:~$ curl http://192.168.56.10:30500/v2/
{"errors":[{"code":"UNAUTHORIZED","message":"authentication required","detail":null}]}
dimitr@k8s-master:~$ curl -u dimitr:password http://192.168.56.10:30500/v2/

```

9. Налаштувати containerd для HTTP registry на всіх node
Навіщо
imagePullSecrets відповідає тільки за логін і пароль.
Але наш registry працює через HTTP: http://192.168.56.10:30500

Containerd за замовчуванням очікує HTTPS.
Тому на всіх Kubernetes node потрібно явно дозволити HTTP registry.

команди виконати на всіх нодах: 
sudo mkdir -p /etc/containerd/certs.d/192.168.56.10:30500

```
cat <<EOF | sudo tee /etc/containerd/certs.d/192.168.56.10:30500/hosts.toml
server = "http://192.168.56.10:30500"

[host."http://192.168.56.10:30500"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
```

Перезапустити containerd: sudo systemctl restart containerd
Перевірити: systemctl status containerd

10. Чому це важливо

imagePullSecrets вирішує тільки авторизацію: username/password для registry

А containerd hosts.toml вирішує іншу проблему: дозволити containerd працювати з HTTP registry

Підсумкова схема
```
Kubernetes Cluster
│
└── Namespace: registry
    │
    ├── Secret: registry-auth
    │   └── htpasswd з username/password
    │
    ├── Deployment: private-registry
    │   │
    │   ├── nodeSelector:
    │   │   └── запускати тільки на k8s-master
    │   │
    │   ├── tolerations:
    │   │   └── дозволити запуск на control-plane node
    │   │
    │   ├── volume:
    │   │   └── /opt/registry/data на master
    │   │
    │   └── container:
    │       └── registry:2
    │
    └── Service: private-registry
        │
        ├── type: NodePort
        ├── port: 5000
        └── nodePort: 30500
```