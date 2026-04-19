# Linux Basics, Bash Automation & Systemd Homework

Цей репозиторій містить виконання домашнього завдання з автоматизації моніторингу системних ресурсів (Disk & RAM), роботи з логами, налаштування systemd (сервісів та таймерів), а також advanced-частини з налаштуванням поштового сервера та DNS (SPF, DKIM, DMARC, PTR).

## Структура репозиторію

```text
INT26-6/
├── README.md
├── scripts/
│   ├── disk_monitor.sh          # Скрипт моніторингу використання диска
│   ├── ram_monitor.sh           # Скрипт моніторингу використання RAM
│   ├── install_monitors.sh      # встановлює монітори, підключає їх до systemd, запускає їх автоматично та додає email-сповіщення про критичні події
│   └── log_watcher.sh           # Автоматично створенний скрипт відстеження логів та відправки email 
├── systemd/
│   ├── disk-monitor.service     # Systemd unit для disk_monitor (створюється автотимачно завдяки install_monitors.sh)
│   ├── disk-monitor.timer       # Systemd timer для запуску disk_monitor щогодини (створюється автотимачно завдяки install_monitors.sh)
│   ├── ram-monitor.service      # Systemd unit для ram_monitor (створюється автотимачно завдяки install_monitors.sh)
│   ├── ram-monitor.timer        # Systemd timer для запуску ram_monitor щогодини (створюється автотимачно завдяки install_monitors.sh)
│   └── log-watcher.service      # Long-running service для log_watcher (створюється автотимачно завдяки install_monitors.sh)
└── screenshots/                 # Скріншоти результатів виконання команд та перевірок (створюється автотимачно завдяки install_monitors.sh)
    ├── inodes.png
    ├── sticky-bit.png
    ├── letter_header.png
    ├── received_letters.png
    ├── systemctl_monitors_status.png
```

---

## 1. Автоматизація та Systemd

### Disk та RAM моніторинг (Timer approach)
Для моніторингу диска та оперативної пам'яті було обрано підхід із використанням **systemd timers**. 
- Скрипти `disk_monitor.sh` та `ram_monitor.sh` виконують разову перевірку (`Type=oneshot` у `.service` файлах).
- Відповідні таймери (`disk-monitor.timer` та `ram-monitor.timer`) налаштовані на запуск цих сервісів щогодини.

### Install Monitors
Цей скрипт автоматизує встановлення системи моніторингу на сервері.
Що саме він робить:
- шукає вказаній директорії всі файли, які закінчуються на _monitor.sh
- для кожного такого скрипта запитує інтервал запуску таймера
- за потреби дозволяє змінити опис сервісу
- копіює monitor-скрипти в /usr/local/bin
- створює для кожного з них systemd-файли:
    * .service
    * .timer
- копіює ці файли в /etc/systemd/system
- виконує systemctl daemon-reload
- вмикає та запускає всі створені таймери через systemctl enable --now

Додатково він створює окремий скрипт log_watcher.sh, який:

- відстежує логи моніторингу диска та RAM
- шукає рядки з WARNING
- формує повідомлення з часом, hostname і текстом події
- записує інформацію про сповіщення в окремий лог
- надсилає email-сповіщення на адресу, яку користувач вводить під час запуску інсталятора

Також для log_watcher.sh створюється log_watcher.service, який:

- запускає цей watcher як постійний systemd service
- автоматично перезапускається у разі збою

Після встановлення скрипт ще:

- показує список активних timer-ів через systemctl list-timers
- показує статус кожного створеного timer-а
- показує статус log_watcher.service

Окремо формується JSON-лог встановлення, у якому зберігається:

- дата і час запуску інсталяції
- кількість встановлених monitor-скриптів
- шляхи до вихідних і встановлених файлів
- вміст самих .sh, .service і .timer
- налаштування log_watcher, включно з email-адресами

---

## 2. Advanced: Налаштування поштового сервера та DNS (VirtualBox)
В рамках додаткового (Advanced) завдання було налаштовано email-інфраструктуру для відправки повідомлень із сервера.

### Виконані кроки на сервері:
1. **Встановлення пакетів:**
   ```bash
   apt update
   apt install postfix mailutils opendkim opendkim-tools
   ```
   *(Під час встановлення Postfix обрано конфігурацію "Internet Site").*

2. **Генерація та налаштування DKIM-ключів:**
   ```bash
   sudo mkdir -p /etc/opendkim/keys/server.shpatakovskyid.pp.ua
   sudo opendkim-genkey -d server.shpatakovskyid.pp.ua -D /etc/opendkim/keys/server.shpatakovskyid.pp.ua -s mail
   sudo chown -R opendkim:opendkim /etc/opendkim/keys/
   sudo chmod 600 /etc/opendkim/keys/server.shpatakovskyid.pp.ua/mail.private
   ```

3. **Конфігурація OpenDKIM та Postfix:**
    - OpenDKIM: Налаштовано на прослуховування порту `inet:127.0.0.1:8891`. У файлах `KeyTable` та `SigningTable` проведено мапування домену `server.shpatakovskyid.pp.ua` до відповідного приватного ключа.
    - SMTP Relay: Через блокування порту 25 провайдером, налаштовано ретрансляцію через Gmail SMTP (://gmail.com) із використанням App Passwords для автентифікації.
    - Інтеграція: У `main.cf` Postfix додано параметри `smtpd_milters` та `non_smtpd_milters` для передачі листів на підпис OpenDKIM перед відправкою.

4. **Налаштування DNS-записів:**

Для забезпечення валідності пошти та уникнення спам-фільтрів для субдомену `server.shpatakovskyid.pp.ua` були налаштовані наступні записи:
- DKIM: TXT-запис із селектором mail._domainkey, що містить публічний ключ для верифікації криптографічного підпису.
- SPF: TXT-запис `v=spf1 a mx include:_://google.com ~all`, який дозволяє серверу та релею Gmail відправляти пошту від імені домену.
- DMARC: TXT-запис `v=DMARC1; p=none`, що визначає політику моніторингу листів, які проходять перевірку автентичності.

4. **Результат перевірки**

Локальна доставка та відправка на зовнішні адреси підтверджена записами в логах:
`sudo journalctl -f -u postfix -u opendkim`
```bash
Apr 19 16:12:13 linux-server postfix/pickup[97851]: ED9FF61414: uid=0 from=<admin@server.shpatakovskyid.pp.ua>
Apr 19 16:12:13 linux-server postfix/cleanup[99388]: ED9FF61414: message-id=<20260419161213.ED9FF61414@linux-server.play.pl>
Apr 19 16:12:13 linux-server opendkim[89740]: ED9FF61414: DKIM-Signature field added (s=mail, d=server.shpatakovskyid.pp.ua)
Apr 19 16:12:14 linux-server postfix/qmgr[91151]: ED9FF61414: from=<admin@server.shpatakovskyid.pp.ua>, size=512, nrcpt=1 (queue active)
Apr 19 16:12:15 linux-server postfix/smtp[99396]: ED9FF61414: to=<shpatakovskyid@gmail.com>, relay=smtp.gmail.com[142.251.127.108]:587, delay=1.3, delays=0.05/0.01/0.74/0.5, dsn=2.0.0, status=sent (250 2.0.0 OK  1776615135 ffacd0b85a97d-43fe4e3a341sm24258874f8f.24 - gsmtp)
Apr 19 16:12:15 linux-server postfix/qmgr[91151]: ED9FF61414: removed

```