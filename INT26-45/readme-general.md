Namespace, Deployment і Service

Namespace
Namespace — це логічний простір усередині Kubernetes-кластера.

Він потрібен, щоб ізолювати ресурси один від одного. Наприклад, можна мати окремі namespace для тестів, dev, staging або production.
У моєму випадку: test-zastosunok - це namespace, у якому живе тестовий застосунок.

Deployment

Deployment описує, який застосунок треба запустити і в якій кількості.
Але Deployment не запускає контейнер напряму. Він створює ReplicaSet, а вже ReplicaSet підтримує потрібну кількість Pod-ів.
Логіка така:
Deployment
  ↓
ReplicaSet
  ↓
Pod
  ↓
Container

Deployment відповідає за:
scaling
rolling update
rollback
self-healing через ReplicaSet
Тобто, коли ми змінюємо кількість реплік або версію image, ми змінюємо бажаний стан у Deployment, а Kubernetes сам приводить кластер до цього стану.

Service

Service — це стабільна точка доступу до Pod-ів.

Pod-и в Kubernetes можуть створюватися, видалятися і отримувати нові IP. Тому напряму звертатися до Pod IP — погана ідея.

Service вирішує цю проблему.

Він знаходить потрібні Pod-и за labels, наприклад:
selector:
  app: nginx-demo

І направляє трафік на всі Pod-и, які мають цей label.

У нашому випадку NodePort Service відкриває застосунок на порту ноди:
192.168.56.10:30080
192.168.56.11:30080
192.168.56.12:30080

Service не створює Pod-и. Він тільки дає доступ до них.

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

### Як іде трафік
```
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