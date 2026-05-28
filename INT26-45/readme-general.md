# Kubernetes: Namespace, Deployment і Service

## Опис

Цей документ пояснює базові Kubernetes-ресурси, які використовуються для запуску тестового застосунку:

- `Namespace`
- `Deployment`
- `ReplicaSet`
- `Pod`
- `Container`
- `Service`

У прикладі використовується namespace `test-zastosunok`, у якому запускається тестовий застосунок `nginx-demo`.

---

## Namespace

`Namespace` — це логічний простір усередині Kubernetes-кластера.

Він потрібен для ізоляції ресурсів один від одного. Наприклад, у Kubernetes можна створити окремі namespace для різних середовищ:

- `dev`
- `test`
- `staging`
- `production`

У цьому прикладі використовується namespace:

```text
test-zastosunok
```

Саме в ньому живе тестовий застосунок.

---

## Deployment

`Deployment` описує, який застосунок потрібно запустити і в якій кількості.

Deployment не запускає контейнер напряму. Він створює `ReplicaSet`, а вже `ReplicaSet` підтримує потрібну кількість `Pod`-ів.

Логіка роботи виглядає так:

```text
Deployment
  ↓
ReplicaSet
  ↓
Pod
  ↓
Container
```

Deployment відповідає за:

- scaling
- rolling update
- rollback
- self-healing через ReplicaSet

Тобто, коли змінюється кількість реплік або версія Docker image, змінюється бажаний стан у `Deployment`, а Kubernetes сам приводить кластер до цього стану.

Приклад бажаного стану:

```text
image: nginx:1.25
replicas: 2
```

Це означає, що Kubernetes має підтримувати два запущені Pod-и з контейнером `nginx:1.25`.

---

## Service

`Service` — це стабільна точка доступу до Pod-ів.

Pod-и в Kubernetes можуть створюватися, видалятися і отримувати нові IP-адреси. Тому напряму звертатися до `Pod IP` — погана практика.

Service вирішує цю проблему.

Він знаходить потрібні Pod-и за labels. Наприклад:

```yaml
selector:
  app: nginx-demo
```

Після цього Service направляє трафік на всі Pod-и, які мають відповідний label.

У цьому прикладі використовується `NodePort Service`, який відкриває застосунок на порту ноди:

```text
192.168.56.10:30080
192.168.56.11:30080
192.168.56.12:30080
```

Service не створює Pod-и. Він тільки дає стабільний доступ до них.

---

## Графічна схема залежностей

```text
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

---

## Як іде трафік

```text
User / Host machine
        │
        ▼
192.168.56.11:30080
        │
        ▼
Service: nginx-demo-svc
        │
        ▼
Pod з label app=nginx-demo
        │
        ▼
Container nginx:80
```

Тобто користувач відкриває застосунок через IP-адресу ноди та порт `30080`, а Kubernetes Service перенаправляє трафік на один із Pod-ів з label `app=nginx-demo`.

---

## Приклад Kubernetes manifest

Нижче наведено приклад manifest-файлу, який створює:

- namespace `test-zastosunok`
- deployment `nginx-demo`
- service `nginx-demo-svc`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-zastosunok
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
  namespace: test-zastosunok
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-demo-svc
  namespace: test-zastosunok
spec:
  type: NodePort
  selector:
    app: nginx-demo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
```

---

## Застосування manifest-файлу

Щоб створити ресурси в Kubernetes, потрібно виконати:

```bash
kubectl apply -f nginx-demo.yaml
```

---

## Перевірка ресурсів

Перевірити namespace:

```bash
kubectl get namespace
```

Перевірити Deployment:

```bash
kubectl get deployment -n test-zastosunok
```

Перевірити ReplicaSet:

```bash
kubectl get rs -n test-zastosunok
```

Перевірити Pod-и:

```bash
kubectl get pods -n test-zastosunok
```

Перевірити Service:

```bash
kubectl get svc -n test-zastosunok
```

Перевірити всі ресурси в namespace:

```bash
kubectl get all -n test-zastosunok
```

---

## Перевірка доступу до застосунку

Застосунок буде доступний через IP-адресу будь-якої Kubernetes-ноди та NodePort `30080`:

```text
http://192.168.56.10:30080
http://192.168.56.11:30080
http://192.168.56.12:30080
```

Також можна перевірити через `curl`:

```bash
curl http://192.168.56.11:30080
```

---

## Масштабування Deployment

Щоб змінити кількість реплік, можна виконати:

```bash
kubectl scale deployment nginx-demo --replicas=3 -n test-zastosunok
```

Після цього Kubernetes створить або видалить Pod-и так, щоб їх кількість відповідала новому бажаному стану.

Перевірити результат:

```bash
kubectl get pods -n test-zastosunok
```

---

## Оновлення image

Щоб змінити версію image, можна виконати:

```bash
kubectl set image deployment/nginx-demo nginx=nginx:1.26 -n test-zastosunok
```

Kubernetes виконає rolling update — поступово замінить старі Pod-и на нові.

Перевірити статус оновлення:

```bash
kubectl rollout status deployment/nginx-demo -n test-zastosunok
```

---

## Rollback

Якщо після оновлення виникла проблема, можна повернутися до попередньої версії:

```bash
kubectl rollout undo deployment/nginx-demo -n test-zastosunok
```

---

## Видалення ресурсів

Щоб видалити всі ресурси, створені manifest-файлом:

```bash
kubectl delete -f nginx-demo.yaml
```

Або можна видалити весь namespace:

```bash
kubectl delete namespace test-zastosunok
```

> Увага: видалення namespace видалить усі ресурси всередині нього.

---

## Важливо

- Namespace ізолює Kubernetes-ресурси логічно.
- Deployment описує бажаний стан застосунку.
- Deployment створює ReplicaSet.
- ReplicaSet підтримує потрібну кількість Pod-ів.
- Pod містить один або кілька контейнерів.
- Service не створює Pod-и, а тільки дає доступ до них.
- Service знаходить Pod-и за labels.
- NodePort відкриває застосунок на порту Kubernetes-ноди.
- Напряму звертатися до Pod IP не рекомендується, тому що Pod-и можуть пересоздаватися та отримувати нові IP.
