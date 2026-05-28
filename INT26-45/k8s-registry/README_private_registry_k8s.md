# Private Docker Registry у Kubernetes cluster з containerd

## Опис

Цей документ описує налаштування приватного Docker Registry всередині Kubernetes-кластера, розгорнутого через `kubeadm` у VirtualBox.

Registry запускається як Kubernetes workload у власному namespace, працює через `NodePort`, використовує `Basic Auth` та зберігає образи у локальній директорії на master node.

## Сценарій

| Параметр | Значення |
|---|---|
| Registry URL | `192.168.56.10:30500` |
| Master node | `k8s-master` |
| Registry auth | Basic Auth |
| Username | `dimitr` |
| Password | `registry123` |
| Namespace | `registry` |
| Runtime | `containerd` |

---

## 1. Створити namespace для registry

### Навіщо

Registry — це окремий інфраструктурний компонент. Його краще тримати не в `default`, а в окремому namespace.

```bash
kubectl create namespace registry
```

Перевірка:

```bash
kubectl get ns
```

---

## 2. Підготувати директорію для зберігання образів на master node

### Навіщо

Docker Registry повинен десь зберігати pushed images.

У цій лабораторній схемі використовується локальна директорія на master node:

```text
/opt/registry/data
```

Команди виконуються на `k8s-master`:

```bash
sudo mkdir -p /opt/registry/data
sudo chmod 755 /opt/registry/data
```

Перевірка:

```bash
ls -ld /opt/registry/data
```

---

## 3. Встановити інструмент для генерації htpasswd

### Навіщо

Registry буде захищений через `Basic Auth`.

Для цього потрібен файл `htpasswd`, у якому зберігається користувач і hash пароля.

```bash
sudo apt update
sudo apt install -y apache2-utils
```

---

## 4. Створити htpasswd-файл

### Навіщо

Docker Registry використовує цей файл для перевірки логіна й пароля.

```bash
mkdir -p ~/registry-auth
htpasswd -Bbn dimitr registry123 > ~/registry-auth/htpasswd
```

Де:

```text
dimitr       = username
registry123  = password
```

Перевірка:

```bash
cat ~/registry-auth/htpasswd
```

Очікуваний формат:

```text
dimitr:$2y$05$....
```

Пароль у відкритому вигляді не зберігається, зберігається тільки hash.

---

## 5. Створити Kubernetes Secret з htpasswd

### Навіщо

Registry Pod повинен отримати файл:

```text
/auth/htpasswd
```

Але auth-дані не варто зберігати напряму в YAML-файлі.

Тому створюємо Kubernetes Secret:

```bash
kubectl create secret generic registry-auth \
  --from-file=htpasswd=$HOME/registry-auth/htpasswd \
  -n registry
```

Перевірка:

```bash
kubectl get secret -n registry
```

Очікуваний результат:

```text
registry-auth   Opaque
```

---

## 6. Створити Deployment і Service для registry

### Навіщо

Docker Registry запускається як звичайний Kubernetes workload.

Але є важливий нюанс: registry зберігає образи у локальній директорії master node:

```text
/opt/registry/data
```

Тому Pod registry треба запускати саме на `k8s-master`.

Для цього використовується `nodeSelector`:

```yaml
nodeSelector:
  kubernetes.io/hostname: k8s-master
```

Master node зазвичай має taint:

```text
node-role.kubernetes.io/control-plane:NoSchedule
```

Тому без `tolerations` Pod може зависнути в статусі `Pending`.

Щоб дозволити запуск на control-plane node, додається:

```yaml
tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
```

YAML-файл:

```text
private-registry.yaml
```

Застосувати:

```bash
kubectl apply -f private-registry.yaml
```

---

## 7. Перевірити, що Registry Pod запустився саме на master

```bash
kubectl get pod,svc -n registry -o wide
```

Приклад результату:

```text
NAME                                  READY   STATUS    RESTARTS   AGE   IP                NODE         NOMINATED NODE   READINESS GATES
pod/private-registry-55854cdf-z98xm   1/1     Running   0          24s   192.168.235.196   k8s-master   <none>           <none>

NAME                       TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE     SELECTOR
service/private-registry   NodePort   10.102.126.172   <none>        5000:30500/TCP   8m27s   app=private-registry
```

Важливо перевірити, що Pod запущений саме на node:

```text
k8s-master
```

---

## 8. Перевірити доступ до registry

Без авторизації registry повинен повертати помилку `UNAUTHORIZED`:

```bash
curl http://192.168.56.10:30500/v2/
```

Приклад:

```json
{"errors":[{"code":"UNAUTHORIZED","message":"authentication required","detail":null}]}
```

З логіном і паролем:

```bash
curl -u dimitr:registry123 http://192.168.56.10:30500/v2/
```

Якщо авторизація успішна, команда не повинна повертати помилку авторизації.

---

## 9. Налаштувати containerd для HTTP registry на всіх node

### Навіщо

`imagePullSecrets` відповідає тільки за авторизацію: username/password для registry.

Але registry працює через HTTP:

```text
http://192.168.56.10:30500
```

`containerd` за замовчуванням очікує HTTPS.

Тому на всіх Kubernetes node потрібно явно дозволити HTTP registry.

Команди виконати на всіх нодах: `k8s-master`, `k8s-worker1`, `k8s-worker2`.

```bash
sudo mkdir -p /etc/containerd/certs.d/192.168.56.10:30500
```

Створити файл `hosts.toml`:

```bash
cat <<EOF | sudo tee /etc/containerd/certs.d/192.168.56.10:30500/hosts.toml
server = "http://192.168.56.10:30500"

[host."http://192.168.56.10:30500"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
```

Перезапустити `containerd`:

```bash
sudo systemctl restart containerd
```

Перевірити статус:

```bash
systemctl status containerd --no-pager
```

---

## 10. Перевірити config_path у containerd

Потрібно перевірити, чи `containerd` використовує директорію:

```text
/etc/containerd/certs.d
```

Команда:

```bash
grep -n "config_path" /etc/containerd/config.toml
```

Приклад до зміни:

```text
54:      config_path = '/etc/containerd/certs.d:/etc/docker/certs.d'
169:    plugin_config_path = '/etc/nri/conf.d'
245:    config_path = ''
```

Потрібно змінити `config_path` у секції:

```text
[plugins.'io.containerd.cri.v1.images'.registry]
```

Очікуваний результат після зміни:

```text
54:      config_path = '/etc/containerd/certs.d'
169:    plugin_config_path = '/etc/nri/conf.d'
245:    config_path = '/etc/containerd/certs.d'
```

Після зміни перезапустити сервіси:

```bash
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

Перевірити статус:

```bash
systemctl status containerd --no-pager
systemctl status kubelet --no-pager
```

---

## 11. Перевірити pull образу через crictl

Після налаштування `containerd` потрібно перевірити, що node може завантажити image з private registry.

Приклад:

```bash
sudo crictl pull --creds dimitr:registry123 192.168.56.10:30500/monitor-api:v1
```

Приклад успішного результату:

```text
Image is up to date for sha256:3172276a65d577f4ccd08dc7bdb43bcf74f815efd71d88adf90ea560d2d9fb1d
```

> Якщо використовується інший пароль, потрібно вказати актуальні credentials.

---

## 12. Чому це важливо

Є дві різні задачі:

1. `imagePullSecrets` вирішує авторизацію.
2. `hosts.toml` для `containerd` дозволяє працювати з HTTP registry.

Тобто `imagePullSecrets` передає Kubernetes логін і пароль, але не змушує `containerd` довіряти HTTP registry.

Саме тому для HTTP registry потрібне окреме налаштування `containerd` на кожній node.

---

## Підсумкова схема

```text
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

---

## 13. Налаштування host machine для push images

Потрібно налаштувати host machine, щоб можна було пушити власні образи в private registry.

### macOS + Docker Desktop

Відкрити:

```text
Docker Desktop → Settings → Docker Engine
```

Додати `insecure-registries`:

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "insecure-registries": [
    "192.168.56.10:30500"
  ]
}
```

Після цього натиснути:

```text
Apply & Restart
```

Перевірити налаштування на host:

```bash
docker info
```

Очікуваний фрагмент:

```text
Insecure Registries:
 192.168.56.10:30500
 hubproxy.docker.internal:5555
 ::1/128
 127.0.0.0/8
```

---

## 14. Login до registry з host machine

```bash
docker login 192.168.56.10:30500
```

Ввести:

```text
Username: dimitr
Password: registry123
```

Очікуваний результат:

```text
Login Succeeded
```

---

## 15. Запушити власний образ з host machine

Приклад build і push для `monitor-api`:

```bash
docker buildx build \
  --platform linux/arm64 \
  -t 192.168.56.10:30500/monitor-api:v1 \
  --push .
```

> Платформу потрібно обирати відповідно до архітектури Kubernetes node. Для x86_64 зазвичай використовується `linux/amd64`.

---

## 16. Перевірити catalog registry

```bash
curl -u dimitr:registry123 http://192.168.56.10:30500/v2/_catalog
```

Приклад результату:

```json
{"repositories":["monitor-api","monitor-frontend"]}
```

---

## Корисні команди

Перевірити namespace:

```bash
kubectl get ns
```

Перевірити registry workload:

```bash
kubectl get pod,svc -n registry -o wide
```

Перевірити secrets:

```bash
kubectl get secret -n registry
```

Подивитися logs registry:

```bash
kubectl logs -n registry deployment/private-registry
```

Перевірити доступ без auth:

```bash
curl http://192.168.56.10:30500/v2/
```

Перевірити доступ з auth:

```bash
curl -u dimitr:registry123 http://192.168.56.10:30500/v2/
```

Перевірити catalog:

```bash
curl -u dimitr:registry123 http://192.168.56.10:30500/v2/_catalog
```

Перевірити pull через containerd:

```bash
sudo crictl pull --creds dimitr:registry123 192.168.56.10:30500/monitor-api:v1
```

---

## Важливо

- Registry працює через HTTP, тому його потрібно додати як insecure registry.
- `containerd` потрібно налаштувати на всіх Kubernetes node.
- `imagePullSecrets` не вирішує проблему HTTP registry, він вирішує тільки авторизацію.
- Registry Pod повинен запускатися на `k8s-master`, бо local storage знаходиться саме там.
- Для запуску Pod на control-plane node потрібні `tolerations`.
- Паролі та credentials не варто зберігати напряму в YAML-файлах.
- Для production краще використовувати HTTPS, persistent storage і більш безпечне керування secrets.
