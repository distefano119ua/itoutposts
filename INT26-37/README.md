# Підготовка AWS-мережі та DNS

Перед запуском Ansible потрібно підготувати AWS-інфраструктуру: VPC, public/private subnets, Internet Gateway, NAT Gateway, route tables та Security Groups.

Окремо описано bastion-доступ до private EC2, налаштування NAT Gateway для виходу private subnet в інтернет і правила безпеки для public/private інстансів.

Детальна інструкція знаходиться в окремому файлі:

[Підготовка приватної AWS-мережі](./ec2_private_instruction/README.md)

Додавання A-запису для домену через Route 53 також було реалізовано раніше:

[Налаштування DNS через Route 53](https://github.com/distefano119ua/itoutposts/tree/main/INT26-20#4-personal-domain--a-record--ssl) `4. Personal domain + A Record + SSL`

## Ansible automation

Детальний опис Ansible-автоматизації винесено в окремий файл [`ansible-automation.md`](./ansible-automation.md).

У ньому описані Ansible-ролі, які встановлюють Docker, запускають MongoDB, backend, frontend і Nginx через Docker Compose, а також налаштовують HTTPS-сертифікати через Certbot.

## AWS VPC схема

```text
                              Internet
                                  |
                                  v
                          Internet Gateway
                                  |
                                  v
+------------------------------------------------------------------+
|                               VPC                                |
|                                                                  |
|  +------------------------------------------------------------+  |
|  |                       Public Subnet                        |  |
|  |                                                            |  |
|  |  +------------------------------------------------------+  |  |
|  |  |                    Public EC2                        |  |  |
|  |  |                                                      |  |  |
|  |  |  docker-compose.yml                                  |  |  |
|  |  |                                                      |  |  |
|  |  |  +----------------+                                  |  |  |
|  |  |  | nginx          |  |  HTTPS :443                   |  |  |
|  |  |  | reverse proxy  |<------------------ Users         |  |  |
|  |  |  +-------+--------+                                  |  |  |
|  |  |          |                                           |  |  |
|  |  |          | HTTP всередині Docker network             |  |  |
|  |  |          v                                           |  |  |
|  |  |  +----------------+        +----------------+        |  |  |
|  |  |  | frontend       |        | backend        |        |  |  |
|  |  |  | app / static   |        | API service    |        |  |  |
|  |  |  +----------------+        +-------+--------+        |  |  |
|  |  |                                   |                  |  |  |
|  |  |  +----------------+               | MongoDB          |  |  |
|  |  |  | certbot        |               | private IP       |  |  |
|  |  |  | SSL renewals   |               | :27017           |  |  |
|  |  |  +----------------+               |                  |  |  |
|  |  +-----------------------------------+------------------+  |  |
|  |                                      |                     |  |
|  +--------------------------------------+---------------------+  |
|                                         |                        |
|                                         | private connection     |
|                                         v                        |
|  +------------------------------------------------------------+  |
|  |                       Private Subnet                       |  |
|  |                                                            |  |
|  |  +------------------------------------------------------+  |  |
|  |  |                    Private EC2                       |  |  |
|  |  |                                                      |  |  |
|  |  |  docker-compose.yml                                  |  |  |
|  |  |                                                      |  |  |
|  |  |  +-----------------------------+                     |  |  |
|  |  |  | mongodb                     |                     |  |  |
|  |  |  | port: 27017                 |                     |  |  |
|  |  |  +--------------+--------------+                     |  |  |
|  |  |                 |                                    |  |  |
|  |  |                 v                                    |  |  |
|  |  |  +-----------------------------+                     |  |  |
|  |  |  | docker volume               |                     |  |  |
|  |  |  | mongo_data                  |                     |  |  |
|  |  |  +-----------------------------+                     |  |  |
|  |  |                                                      |  |  |
|  |  +------------------------------------------------------+  |  |
|  |                                                            |  |
|  +------------------------------------------------------------+  |
|                                                                  |
+------------------------------------------------------------------+
```

Основний потік запитів:

```text
Users
  -> HTTPS
  -> Internet Gateway
  -> Public EC2
  -> nginx
  -> frontend / backend

backend
  -> MongoDB by private IP
  -> Private EC2:27017

Private EC2
  -> MongoDB container
  -> Docker volume: mongo_data
```

## Запуск

Рішення можна завантажити, налаштувати під свої EC2-інстанси та запустити командою:

```bash
ansible-playbook playbooks/deploy-app.yml
```

Для повного видалення застосунку з серверів:

```bash
ansible-playbook playbooks/purge-app.yml
```

## Що потрібно заповнити перед запуском

### `hosts.txt`

У файлі `hosts.txt` потрібно вказати public IP для `public` EC2 та private IP для `private` EC2.

```ini
[public_servers]
public ansible_host=public_subnet.ip.address.ec2

[private_servers]
private ansible_host=private_subnet.ip.address.ec2

[private_servers:vars]
ansible_ssh_common_args='-o ProxyJump=username@public_subnet.ip.address.ec2 -o ForwardAgent=yes'

[aws_servers:children]
public_servers
private_servers
```

Також потрібно вказати SSH-ключ:

```yaml
ansible_ssh_private_key_file: /path/to/key-pair.pem
```

### `group_vars/public_servers`

У файлі `group_vars/public_servers` потрібно змінити основні значення під свою інфраструктуру:

```yaml
---
ansible_user: ubuntu
ansible_ssh_private_key_file: /path/to/key-pair.pem

mongo_private_ip: private_subnet.ip.address.ec2
mongo_uri: "mongodb://{{ mongo_private_ip }}:27017"

domain_name: your.domain
certbot_email: your.email@mail.com
```

Docker images вже вказані в конфігурації та доступні публічно з GitHub Container Registry:

```yaml
public_registry: ghcr.io/distefano119ua/itoutposts

frontend_image: "{{ public_registry }}/frontend:80d95db5d6b8730b8e093df1a9855d02d640d4e1"
backend_image: "{{ public_registry }}/backend:fe1fa430e48f5f79aedb72231a4510cce3eca90b"
```

## Код застосунку

[<посилання-на-репозиторій>](https://github.com/distefano119ua/itoutposts/tree/main/INT26-24)

## Приклад запуску

Приклад запуску доступний у записі `ansible-automation.rec`:

```bash
asciinema play ansible-automation.rec
```

а також у записі екрану
[Переглянути demo video](./ansible-automation.mp4)