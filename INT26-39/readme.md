# AWS Infrastructure Automation with Terraform and Ansible

## Зміст

- [Опис проєкту](#опис-проєкту)
- [Що автоматизує проєкт](#що-автоматизує-проєкт)
- [Структура проєкту](#структура-проєкту)
- [Опис директорій](#опис-директорій)
- [AWS VPC та DNS схема](#aws-vpc-та-dns-схема)
- [Основний потік запитів](#основний-потік-запитів)
- [Що потрібно змінити перед запуском](#що-потрібно-змінити-перед-запуском)
- [Порядок запуску](#порядок-запуску)
- [Порядок видалення](#порядок-видалення)
- [Важливо](#важливо)

---

## Опис проєкту

Цей проєкт є готовим рішенням для автоматичного створення AWS-інфраструктури та деплою застосунку через Ansible.

Користувач може завантажити репозиторій, змінити кілька значень під себе та запустити проєкт локально зі свого компʼютера.

---

## Що автоматизує проєкт

Проєкт автоматизує:

- створення S3 bucket для Terraform remote state;
- створення VPC, public/private subnets, Internet Gateway, NAT Gateway та route tables;
- створення Security Groups;
- створення public EC2 та private EC2;
- генерацію SSH key pair;
- генерацію Ansible `hosts.txt`;
- генерацію Ansible `group_vars`;
- створення Python virtual environment;
- встановлення Ansible dependencies;
- запуск Ansible playbook для деплою застосунку.

---

## Структура проєкту

```text
INT26-39/
├── remote-state-s3/
└── project/
    ├── network/
    ├── security/
    ├── servers/
    └── deploy/
```

---

## Опис директорій

### `remote-state-s3`

Створює S3 bucket для зберігання Terraform remote state.

### `project/network`

Створює AWS networking:

- VPC;
- Public subnet;
- Private subnet;
- Internet Gateway;
- NAT Gateway;
- Elastic IP для NAT Gateway;
- Public route table;
- Private route table;
- Route table associations.

### `project/security`

Створює Security Groups.

#### Web Security Group

Дозволені inbound-зʼєднання:

- HTTP `80`;
- HTTPS `443`;
- SSH `22` тільки з поточного public IP.

#### MongoDB Security Group

Дозволені inbound-зʼєднання:

- MongoDB `27017` тільки з Web Security Group;
- SSH `22` тільки з Web Security Group.

### `project/servers`

Створює EC2 instances:

- Public Web EC2 instance;
- Private MongoDB EC2 instance;
- SSH key pair;
- Local private key: `project/servers/keys/id_rsa`.

### `project/deploy`

Запускає Ansible deployment:

- читає IP-адреси з Terraform remote state;
- генерує `hosts.txt`;
- генерує `group_vars`;
- створює Python `.venv`;
- встановлює dependencies з `requirements.txt`;
- запускає `playbooks/deploy-app.yml`.

---

## AWS VPC та DNS схема

```text
                                        User
                                         |
                                         | HTTPS :443
                                         v
                                Custom Domain Name
                              example.your-domain.com
                                         |
                                         | DNS A Record
                                         v
                                  Route 53 Hosted Zone
                                         |
                                         | points to Public EC2 IP
                                         v
                                  Internet Gateway
                                         |
                                         v
+--------------------------------------------------------------------------------+
|                                      VPC                                       |
|                                                                                |
|  +------------------------------------------------------------------------+    |
|  |                              Public Subnet                             |    |
|  |                                                                        |    |
|  |  +----------------------------------------------------------------+    |    |
|  |  |                         Public Web EC2                         |    |    |
|  |  |                                                                |    |    |
|  |  |  Docker / Docker Compose                                       |    |    |
|  |  |                                                                |    |    |
|  |  |  +----------------+                                            |    |    |
|  |  |  | nginx          |  HTTPS :443 / HTTP :80                     |    |    |
|  |  |  | reverse proxy  |<------------------------------ Users       |    |    |
|  |  |  +-------+--------+                                            |    |    |
|  |  |          |                                                     |    |    |
|  |  |          | internal Docker network                             |    |    |
|  |  |          v                                                     |    |    |
|  |  |  +----------------+        +----------------+                  |    |    |
|  |  |  | frontend       |        | backend        |                  |    |    |
|  |  |  | app / static   |        | API service    |                  |    |    |
|  |  |  +----------------+        +-------+--------+                  |    |    |
|  |  |                                   |                            |    |    |
|  |  |                                   | MongoDB private IP :27017  |    |    |
|  |  +-----------------------------------+----------------------------+    |    |
|  |                                      |                                 |    |
|  +--------------------------------------+---------------------------------+    |
|                                         |                                      |
|                                         | private VPC connection               |
|                                         v                                      |
|  +------------------------------------------------------------------------+    |
|  |                             Private Subnet                             |    |
|  |                                                                        |    |
|  |  +----------------------------------------------------------------+    |    |
|  |  |                        Private MongoDB EC2                     |    |    |
|  |  |                                                                |    |    |
|  |  |  Docker / Docker Compose                                       |    |    |
|  |  |                                                                |    |    |
|  |  |  +-----------------------------+                               |    |    |
|  |  |  | mongodb                     |                               |    |    |
|  |  |  | port: 27017                 |                               |    |    |
|  |  |  +--------------+--------------+                               |    |    |
|  |  |                 |                                              |    |    |
|  |  |                 v                                              |    |    |
|  |  |  +-----------------------------+                               |    |    |
|  |  |  | docker volume               |                               |    |    |
|  |  |  | mongo_data                  |                               |    |    |
|  |  |  +-----------------------------+                               |    |    |
|  |  +----------------------------------------------------------------+    |    |
|  |                                                                        |    |
|  |  Outbound internet access:                                             |    |
|  |  Private EC2 -> NAT Gateway -> Internet Gateway -> Internet            |    |
|  +------------------------------------------------------------------------+    |
|                                                                                |
+--------------------------------------------------------------------------------+
```

---

## Основний потік запитів

```text
User
  -> Custom domain
  -> Route 53 Hosted Zone
  -> A Record
  -> Public EC2
  -> nginx
  -> frontend / backend

backend
  -> MongoDB private IP
  -> Private EC2:27017

Private EC2
  -> NAT Gateway
  -> Internet
```

Домен був створений окремо від AWS. DNS-зона та A-record керуються через Route 53 Hosted Zone.

---

## Що потрібно змінити перед запуском

Перед запуском проєкту потрібно змінити значення під себе у таких файлах:

1. `remote-state-s3/main.tf`
2. `project/network/variables.tf`
3. `project/deploy/variables.tf`

---

## Порядок запуску

### 1. Remote State S3

```bash
cd remote-state-s3
terraform init
terraform apply
```

### 2. Network

```bash
cd ../project/network
terraform init
terraform apply
```

### 3. Security

```bash
cd ../security
terraform init
terraform apply
```

Security module автоматично визначає поточний public IP для SSH-доступу через:

```text
https://checkip.amazonaws.com/
```

### 4. Servers

```bash
cd ../servers
terraform init
terraform apply
```

Після цього Terraform створить EC2 та SSH key:

```text
project/servers/keys/id_rsa
```

Public IP Web EC2 можна отримати командою:

```bash
terraform output web_public_ip
```

### 5. Route 53 Hosted Zone

Перед запуском deploy потрібно вручну оновити A-record у Route 53 Hosted Zone.

A-record має вказувати на public IP Web EC2.

Приклад:

```text
app.example.com -> PUBLIC_WEB_IP
```

Це потрібно для коректної роботи домену, Nginx та Certbot.

### 6. Deploy

```bash
cd ../deploy
terraform init
terraform apply
```

Під час `terraform apply` Terraform:

- згенерує `hosts.txt`;
- згенерує `group_vars/aws_servers`;
- згенерує `group_vars/private_servers`;
- згенерує `group_vars/public_servers`;
- створить Python `.venv`;
- встановить dependencies з `requirements.txt`;
- запустить Ansible playbook.

Команда, яка виконується Terraform:

```bash
ansible-playbook -i hosts.txt playbooks/deploy-app.yml
```

---

## Порядок видалення

Видаляти ресурси потрібно у зворотному порядку за допомогою `terraform destroy`:

1. Deploy
2. Servers
3. Security
4. Network
5. Remote State S3

Перед видаленням `remote-state-s3` не забудьте змінити:

```hcl
force_destroy = false
```

на:

```hcl
force_destroy = true
```

`remote-state-s3` потрібно видаляти останнім, тому що інші Terraform-директорії використовують цей bucket для зберігання state.

---

## Важливо

- Private EC2 не має public IP.
- Доступ до MongoDB дозволений тільки з Web Security Group.
- Private subnet використовує NAT Gateway для виходу в інтернет.
- Ansible запускається локально з машини, де виконується `terraform apply`.
- Private SSH key створюється Terraform і зберігається локально.
- Не додавайте private key у Git.

---

## Рекомендації з безпеки

- Додайте `project/servers/keys/id_rsa` у `.gitignore`.
- Не комітьте Terraform state files у Git.
- Не зберігайте AWS credentials у репозиторії.
- Перевіряйте Security Groups перед деплоєм у production-середовище.

## Definition of Done
- [ Done ] S3 bucket створені через Terraform
- [ Done ] VPC (або модуль) підняті через Terraform
- [ Done ] EC2 запущена, SSH ключ збережений локально в keys/
- [ Done ] keys/ папка в .gitignore
- [ Done ] Output ssh_command містить готову команду для підключення `cd project/servers && terraform output ssh_command: "ssh -i ./keys/id_rsa ubuntu@34.200.240.133"`
- [ Done ] Підключення до сервера через terraform output ssh_command працює
- [ Done ] Ansible playbook запускається автоматично після terraform apply
- [ Done ] Сервер налаштований (Docker + застосунок) — підтверджено через docker ps
- [ Done ] README з описом структури проєкту