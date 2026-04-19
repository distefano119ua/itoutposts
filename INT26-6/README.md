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
├── installation_logs/.          # Директорія, яка зберігає всі детальні записи для швидкого аналізу: коли було запущено, що було в цьому запуску
│   ├── monitors_installation_log_20260419_170534.json
└── screenshots/                 # Скріншоти результатів виконання команд та перевірок (створюється автотимачно завдяки install_monitors.sh)
    ├── inodes.png
    ├── sticky-bit.png
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

Приклад запуску: `sudo ./install_monitors.sh`

```text
Found: disk_monitor.sh
Set interval for disk_monitor (e.g. 30s, 5min, 1h) [5min]: 30s 
Description [Disk monitor]: disk monitor every 5min
Installed: /usr/local/bin/disk_monitor.sh
Created:   /etc/systemd/system/disk_monitor.service
Created:   /etc/systemd/system/disk_monitor.timer
Saved:     /home/dimitr/Desktop/outposts/monitors/disk_monitor.service
Saved:     /home/dimitr/Desktop/outposts/monitors/disk_monitor.timer
Found: ram_monitor.sh
Set interval for ram_monitor (e.g. 30s, 5min, 1h) [5min]: 30s
Description [Ram monitor]: ram monitor every 5min
Installed: /usr/local/bin/ram_monitor.sh
Created:   /etc/systemd/system/ram_monitor.service
Created:   /etc/systemd/system/ram_monitor.timer
Saved:     /home/dimitr/Desktop/outposts/monitors/ram_monitor.service
Saved:     /home/dimitr/Desktop/outposts/monitors/ram_monitor.timer
Enter ALERT_EMAIL for log watcher: shpatakovskyid@gmail.com
Enter SENDER_EMAIL [admin@server.shpatakovskyid.pp.ua]: admin@server.shpatakovskyid.pp.ua
Created symlink '/etc/systemd/system/timers.target.wants/disk_monitor.timer' → '/etc/systemd/system/disk_monitor.timer'.
Created symlink '/etc/systemd/system/timers.target.wants/ram_monitor.timer' → '/etc/systemd/system/ram_monitor.timer'.
NEXT                                 LEFT LAST                              PASSED UNIT                           ACTIVATES                       
Sun 2026-04-19 17:07:35 UTC           29s Sun 2026-04-19 17:07:04 UTC    318ms ago disk_monitor.timer             disk_monitor.service
Sun 2026-04-19 17:07:35 UTC           29s Sun 2026-04-19 17:07:05 UTC    153ms ago ram_monitor.timer              ram_monitor.service
Sun 2026-04-19 17:10:00 UTC      2min 54s Sun 2026-04-19 17:00:30 UTC     6min ago sysstat-collect.timer          sysstat-collect.service
Sun 2026-04-19 17:34:08 UTC         27min Sun 2026-04-19 16:31:59 UTC    35min ago anacron.timer                  anacron.service
Sun 2026-04-19 18:00:37 UTC         53min Sun 2026-04-19 17:07:04 UTC    332ms ago fwupd-refresh.timer            fwupd-refresh.service
Sun 2026-04-19 20:48:14 UTC      3h 41min Sun 2026-04-19 12:10:37 UTC 4h 12min ago apt-daily.timer                apt-daily.service
Mon 2026-04-20 00:00:00 UTC            6h Sun 2026-04-19 00:00:08 UTC       7h ago dpkg-db-backup.timer           dpkg-db-backup.service
Mon 2026-04-20 00:00:00 UTC            6h Sun 2026-04-19 00:00:08 UTC       7h ago sysstat-rotate.timer           sysstat-rotate.service
Mon 2026-04-20 00:07:00 UTC            6h Sun 2026-04-19 00:07:03 UTC       7h ago sysstat-summary.timer          sysstat-summary.service
Mon 2026-04-20 00:23:24 UTC            7h Sun 2026-04-19 14:08:30 UTC 2h 58min ago motd-news.timer                motd-news.service
Mon 2026-04-20 00:37:57 UTC            7h Sun 2026-04-19 00:38:23 UTC       6h ago logrotate.timer                logrotate.service
Mon 2026-04-20 00:39:06 UTC            7h -                                      - fstrim.timer                   fstrim.service
Mon 2026-04-20 06:12:31 UTC           13h Sun 2026-04-19 11:50:44 UTC 4h 31min ago apt-daily-upgrade.timer        apt-daily-upgrade.service
Mon 2026-04-20 08:11:44 UTC           15h Sat 2026-04-18 22:27:23 UTC       8h ago update-notifier-download.timer update-notifier-download.service
Mon 2026-04-20 08:22:13 UTC           15h Sat 2026-04-18 22:37:52 UTC       8h ago systemd-tmpfiles-clean.timer   systemd-tmpfiles-clean.service
Mon 2026-04-20 09:53:37 UTC           16h Sun 2026-04-19 14:08:30 UTC 2h 58min ago man-db.timer                   man-db.service
Sun 2026-04-26 03:10:56 UTC        6 days Sun 2026-04-19 11:50:44 UTC 4h 31min ago e2scrub_all.timer              e2scrub_all.service
Wed 2026-04-29 07:46:19 UTC 1 week 2 days Sun 2026-04-19 15:01:21 UTC  2h 5min ago update-notifier-motd.timer     update-notifier-motd.service

18 timers listed.
Pass --all to see loaded but inactive timers, too.
● disk_monitor.timer - Run disk monitor every 5min every 30s
     Loaded: loaded (/etc/systemd/system/disk_monitor.timer; enabled; preset: enabled)
     Active: active (waiting) since Sun 2026-04-19 17:07:04 UTC; 335ms ago
 Invocation: a7a23beda0a14ad1bb85eaf3796ae44a
    Trigger: Sun 2026-04-19 17:07:35 UTC; 29s left
   Triggers: ● disk_monitor.service

Apr 19 17:07:04 linux-server systemd[1]: Started disk_monitor.timer - Run disk monitor every 5min every 30s.
● ram_monitor.timer - Run ram monitor every 5min every 30s
     Loaded: loaded (/etc/systemd/system/ram_monitor.timer; enabled; preset: enabled)
     Active: active (waiting) since Sun 2026-04-19 17:07:05 UTC; 182ms ago
 Invocation: d5e35042ee7b4a4692bcf4a762894c20
    Trigger: Sun 2026-04-19 17:07:35 UTC; 29s left
   Triggers: ● ram_monitor.service

Apr 19 17:07:05 linux-server systemd[1]: Started ram_monitor.timer - Run ram monitor every 5min every 30s.
● log_watcher.service - Monitor warning logs and send email alerts
     Loaded: loaded (/etc/systemd/system/log_watcher.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-04-19 17:07:05 UTC; 37ms ago
 Invocation: 2ff61fe88ef84eeea9bae3ea731a2d71
   Main PID: 100609 (log_watcher.sh)
      Tasks: 5 (limit: 6675)
     Memory: 4.1M (peak: 5.5M)
        CPU: 16ms
     CGroup: /system.slice/log_watcher.service
             ├─100609 /bin/bash /usr/local/bin/log_watcher.sh
             ├─100614 tail -F /var/log/monitor/disk_monitor.log /var/log/monitor/ram_monitor.log
             ├─100615 /bin/bash /usr/local/bin/log_watcher.sh
             └─100623 mail -s "System Monitor Warning - linux-server" -a "From: admin@server.shpatakovskyid.pp.ua" shpatakovskyid@gmail.com

Apr 19 17:07:05 linux-server systemd[1]: Started log_watcher.service - Monitor warning logs and send email alerts.
Created:   ./log_watcher.sh
Installed: /usr/local/bin/log_watcher.sh
Created:   ./log_watcher.service
Created:   /etc/systemd/system/log_watcher.service
Log written to: ./installation_logs/monitors_installation_log_20260419_170534.json
Monitors installed: 2
Done.
```

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
Додатково надається знімок екрану `received_letters.png`

## 3. Теоретичні питання

### **Inode Research**

Виконати наступні команди
```bash
df -i
mkdir -p /tmp/inode_test
for i in {1..10000}; do touch /tmp/inode_test/file_$i; done
df -i
rm -rf /tmp/inode_test
```

Результат імітації створення файлів через цикл див. `screenshots/inodes.png`

**1. Що станеться, якщо inode закінчаться, але дисковий простір ще є?**
- Не буде можливості створювати нові файли, а в Лінукс все файли: директорія, сокети, сімлінки
- При спробі створити `файл` отримуєш відповідь - `No space left on device`, навіть якщо `df -h` показує вільне місце

**2. Чому при створенні великої кількості порожніх файлів змінюється кількість `inode`, але майже не змінюється зайнятий диск?**
- Inode необхідний для зберігання метаданних: права доступу, власник, час створення
- Кожний `ФАЙЛ` "споживає" один `inode`, тому важливо дивитися перевіряти як саме місце на диску, так і `inode` зі структур файлової системи

**3. Як знайти директорію з найбільшою кількістю файлів?**
```text
du --inodes -s /* 2>/dev/null | sort -nr | head
```


### Sticky Bit 

Sticky Bit — це спеціальний біт прав доступу в Linux/Unix. (див. `screenshots/sticky-bit.png`)

Що він робить:
* якщо на директорії встановлено sticky bit, то видаляти або перейменовувати файли в ній можуть лише:
    * власник файлу
    * власник директорії
    * root

Навіть якщо директорія спільна і всі мають право на запис.


**1. Що означає `t` у правах доступу `drwxrwxrwt`?**
- Символ `t` позначає встановлений **Sticky Bit** (разом із правом виконання для всіх інших користувачів — `x`). 
- Якщо б права виконання не було, відображалася б велика літера `T`.

**2. Де sticky bit використовується за замовчуванням?**
Приклад:
* /tmp — спільна директорія для всіх користувачів
* без sticky bit будь-хто міг би видалити чужий файл
* зі sticky bit — ні

**3. Що станеться, якщо інший користувач спробує видалити твій файл у такій директорії?**
- Нічого, отримає тільки `Operation not permitted`
- Права мають ті, що описані в `Що він робить`

**4. Навіщо sticky bit потрібен у спільних директоріях?**
- Безпека та ізоляція від `Ой, я випадково...`