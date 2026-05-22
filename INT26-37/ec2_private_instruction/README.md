# Налаштування MongoDB у приватній підмережі AWS з доступом лише з EC2 у публічній підмережі

## Мета

Потрібно розгорнути MongoDB у Docker на EC2-інстансі в приватній підмережі AWS так, щоб:

- MongoDB була недоступна з інтернету.
- MongoDB була доступна тільки з EC2-інстанса у публічній підмережі.
- Приватний EC2 мав доступ до інтернету для встановлення Docker і завантаження Docker-образів.

---

## Зміст

1. [Загальна архітектура](#1-загальна-архітектура)
2. [Підготовка мережі](#2-підготовка-мережі)
   - [Публічна підмережа](#21-публічна-підмережа)
   - [Приватна підмережа](#22-приватна-підмережа)
3. [Створення NAT Gateway](#3-створення-nat-gateway)
4. [Route Table для private subnet](#4-route-table-для-private-subnet)
5. [Security Group для public EC2](#5-security-group-для-public-ec2)
6. [Security Group для private EC2 з MongoDB](#6-security-group-для-private-ec2-з-mongodb)
7. [Підключення до private EC2 через public EC2](#7-підключення-до-private-ec2-через-public-ec2)

---

## 1. Загальна архітектура

```text
Internet
   |
Internet Gateway
   |
Public Subnet
   |
Public EC2 instance
   |
Private IP connection
   |
Private Subnet
   |
Private EC2 instance
   |
Docker + MongoDB
```

Приватний EC2 не має публічної IP-адреси.

Для виходу в інтернет він використовує **NAT Gateway**.

---

## 2. Підготовка мережі

### 2.1. Публічна підмережа

Публічна підмережа повинна мати маршрут до **Internet Gateway**.

**Route Table для public subnet:**

| Destination | Target |
|---|---|
| VPC CIDR | local |
| `0.0.0.0/0` | Internet Gateway |

**Приклад:**

| Destination | Target |
|---|---|
| `10.0.0.0/16` | local |
| `0.0.0.0/0` | `igw-xxxxxxxx` |

### 2.2. Приватна підмережа

Приватна підмережа не повинна напряму виходити через **Internet Gateway**.

Для неї потрібно створити **NAT Gateway**.

---

## 3. Створення NAT Gateway

### Крок 1. Створити Elastic IP

В AWS Console перейти:

```text
VPC → Elastic IPs → Allocate Elastic IP address
```

Натиснути:

```text
Allocate
```

Elastic IP буде використовуватись для NAT Gateway.

### Крок 2. Створити NAT Gateway

Перейти:

```text
VPC → NAT Gateways → Create NAT Gateway
```

Заповнити поля:

| Поле | Значення |
|---|---|
| Name | `nat-gateway` |
| Subnet | public subnet |
| Connectivity type | Public |
| Elastic IP | вибрати створений Elastic IP |

Натиснути:

```text
Create NAT Gateway
```

Дочекатися статусу:

```text
Available
```

> **Важливо:** NAT Gateway створюється саме в **public subnet**, а не в **private subnet**.

---

## 4. Route Table для private subnet

Private subnet повинна мати маршрут в інтернет через **NAT Gateway**.

Перейти:

```text
VPC → Route Tables
```

Вибрати route table, яка прив’язана до private subnet.

Додати маршрут:

| Destination | Target |
|---|---|
| `0.0.0.0/0` | NAT Gateway |

Після налаштування route table private subnet має виглядати так:

| Destination | Target |
|---|---|
| `10.0.0.0/16` | local |
| `0.0.0.0/0` | `nat-xxxxxxxx` |

---

## 5. Security Group для public EC2

Public EC2 використовується як **bastion/app server**.

Приклад назви Security Group:

```text
sg-public-ec2
```

### Inbound rules

| Type | Port | Source |
|---|---:|---|
| SSH | 22 | your IP |
| HTTP | 80 | `0.0.0.0/0`, якщо потрібно |
| HTTPS | 443 | `0.0.0.0/0`, якщо потрібно |
| Custom TCP | 7777 | `your IP`, якщо є необхідність подивитися роботу backend-service |

### Outbound rules

| Type | Destination |
|---|---|
| All traffic | `0.0.0.0/0` |

---

## 6. Security Group для private EC2 з MongoDB

Private EC2 повинен приймати SSH та MongoDB-з’єднання тільки від public EC2.

Приклад назви Security Group:

```text
sg-private-mongodb
```

### Inbound rules

| Type | Port | Source |
|---|---:|---|
| SSH | 22 | `sg-public-ec2` |
| Custom TCP | 27017 | `sg-public-ec2` |

> **Правильно:** порт `27017` має бути відкритий тільки для Security Group public EC2.

### Outbound rules для private EC2

| Type | Destination |
|---|---|
| All traffic | `0.0.0.0/0` |

Це потрібно, щоб private EC2 міг завантажувати пакети та Docker-образи через **NAT Gateway**.

---

## 7. Підключення до private EC2 через public EC2

Оскільки private EC2 не має public IP, підключення виконується через public EC2.

### Варіант 1. SSH agent forwarding

На локальному комп’ютері:

```bash
eval "$(ssh-agent -s)"
ssh-add /path/to/key.pem
ssh -A ubuntu@PUBLIC_EC2_PUBLIC_IP
```

Після входу на public EC2 перевірити, що ключ передався:

```bash
ssh-add -l
```

Якщо ключ відображається, підключитися до private EC2:

```bash
ssh ubuntu@PRIVATE_EC2_PRIVATE_IP
```

### Варіант 2. ProxyJump

З локального комп’ютера можна одразу підключитися до private EC2 через public EC2:

```bash
ssh -i /path/to/key.pem -J ubuntu@PUBLIC_EC2_PUBLIC_IP ubuntu@PRIVATE_EC2_PRIVATE_IP
```
