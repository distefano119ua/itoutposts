# Що автоматизує Ansible

Ansible автоматизує встановлення Docker, підготовку конфігурацій, запуск сервісів через Docker Compose та налаштування HTTPS для публічного веб-інтерфейсу.

У проєкті використовується рольова структура. Кожна роль відповідає за окрему частину інфраструктури або застосунку.

## Роль `docker`

Роль `docker` виконується на обох EC2-інстансах: `public` та `private`.

Вона відповідає за:

- видалення старих або конфліктних Docker-пакетів;
- встановлення необхідних системних пакетів;
- додавання офіційного Docker APT repository;
- встановлення Docker Engine;
- встановлення Docker Compose Plugin;
- запуск і додавання Docker service в автозавантаження;
- перевірку встановлених версій Docker та Docker Compose.

Після виконання ролі на сервері доступні команди:

```bash
docker --version
docker compose version
```

## Роль `mongodb`

Роль `mongodb` виконується тільки на `private` EC2-інстансі.

Вона відповідає за запуск MongoDB як окремого Docker Compose сервісу в приватній підмережі.

Роль створює:

- директорію для MongoDB Compose-проєкту;
- `docker-compose.yml` для MongoDB;
- Docker volume для збереження даних;
- окрему Docker network для MongoDB;
- контейнер `monitor-mongodb` на базі образу `mongo:7`.

MongoDB доступна тільки з `public` EC2 через приватну мережу AWS. Порт `27017` не відкривається в інтернет.

## Роль `monitoring`

Роль `monitoring` виконується на `public` EC2-інстансі.

Вона відповідає за підготовку backend/monitoring-сервісу:

- створення директорії застосунку;
- створення директорії для логів;
- генерацію `.env.example` через Jinja2-шаблон `env.j2`;
- налаштування змінних середовища для `monitor-api`;
- передачу MongoDB connection string через приватний IP `private` EC2.

У `.env.example` передаються параметри:

```env
APP_LOGS_PATH
ALERT_EMAIL
SERVICE_NAME
MONGO_URI
DB_NAME
COLLECTION_NAME
DATASET_SLUG
CSV_NAME
```

Контейнер `monitor-api` запускається через загальний Docker Compose файл на `public` EC2.

## Роль `frontend`

Роль `frontend` виконується на `public` EC2-інстансі.

Вона відповідає за підготовку frontend-сервісу до запуску через Docker Compose.

Frontend запускається як окремий контейнер з образу, який зберігається в GitHub Container Registry.

Для frontend передається змінна:

```env
VITE_API_URL=/api
```

Це дозволяє frontend звертатися до backend через Nginx reverse proxy.

## Роль `nginx`

Роль `nginx` виконується на `public` EC2-інстансі.

Вона відповідає за налаштування Nginx як reverse proxy.

Роль створює:

- директорію для конфігурації Nginx;
- файл `default.conf` з Jinja2-шаблону `nginx.conf.j2`;
- HTTP-конфіг для першого запуску;
- HTTPS-конфіг після отримання SSL-сертифіката.

Nginx проксирує запити:

```text
/      -> frontend container
/api/  -> monitor-api container
```

Також у конфігурації Nginx передбачено шлях для Certbot challenge:

```text
/.well-known/acme-challenge/
```

При зміні конфігурації Nginx спрацьовує handler, який перезапускає Nginx-контейнер.

## Роль `compose_app`

Роль `compose_app` виконується на `public` EC2-інстансі.

Вона відповідає за створення та запуск основного Docker Compose stack.

Роль створює `docker-compose.yml` з Jinja2-шаблону `docker-compose.yml.j2`.

У цьому Compose stack запускаються:

- `monitor-nginx`;
- `monitor-frontend`;
- `monitor-api`.

Також роль:

- завантажує Docker images;
- зупиняє старий Compose stack;
- прибирає orphan containers;
- запускає актуальну версію застосунку;
- показує статус контейнерів.

Nginx-контейнер відкриває порти:

```text
80:80
443:443
```

## Роль `certbot`

Роль `certbot` виконується на `public` EC2-інстансі.

Вона відповідає за отримання та оновлення HTTPS-сертифіката через Let’s Encrypt.

Роль:

- встановлює certbot;
- створює webroot-директорію для ACME challenge;
- створює challenge-директорію `.well-known/acme-challenge`;
- отримує SSL-сертифікат для домену;
- додає cron job для автоматичного оновлення сертифіката;
- перезапускає Nginx-контейнер після оновлення сертифіката.

Certbot використовує webroot-підхід, тому Nginx залишається всередині Docker-контейнера, а сертифікати зберігаються на хості в:

```text
/etc/letsencrypt
```

Ця директорія монтується в Nginx-контейнер як read-only volume.
