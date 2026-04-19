#!/bin/sh

set -eu

SOURCE_DIR="${1:-.}"
INSTALL_SCRIPT_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="${SOURCE_DIR}/installation_logs"
RUN_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
RUN_TIMESTAMP_SAFE="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/monitors_installation_log_${RUN_TIMESTAMP_SAFE}.json"

LOG_WATCHER_SCRIPT_NAME="log_watcher.sh"
LOG_WATCHER_SERVICE_NAME="log_watcher.service"
LOG_WATCHER_SOURCE_PATH="${SOURCE_DIR}/${LOG_WATCHER_SCRIPT_NAME}"
LOG_WATCHER_INSTALLED_PATH="${INSTALL_SCRIPT_DIR}/${LOG_WATCHER_SCRIPT_NAME}"
LOG_WATCHER_SOURCE_SERVICE_PATH="${SOURCE_DIR}/${LOG_WATCHER_SERVICE_NAME}"
LOG_WATCHER_INSTALLED_SERVICE_PATH="${SYSTEMD_DIR}/${LOG_WATCHER_SERVICE_NAME}"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Directory not found: $SOURCE_DIR"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script with sudo/root"
    exit 1
fi

mkdir -p "$LOG_DIR"
mkdir -p "$INSTALL_SCRIPT_DIR"
mkdir -p "$SYSTEMD_DIR"

make_description() {
    base="$1"
    name=${base%_monitor.sh}
    name=$(echo "$name" | tr '_' ' ')
    echo "$name" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1'
}

escape_json() {
    sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e ':a;N;$!ba;s/\n/\\n/g'
}

escape_json_string() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g'
}

validate_interval() {
    value="$1"

    case "$value" in
        ''|*[!0-9a-zA-Z]*) return 1 ;;
    esac

    case "$value" in
        *ms|*s|*min|*h) return 0 ;;
        *) return 1 ;;
    esac
}

validate_email() {
    value="$1"
    case "$value" in
        *@*.*) return 0 ;;
        *) return 1 ;;
    esac
}

ABS_SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
TMP_MONITORS_FILE="$(mktemp)"
TMP_TIMERS_FILE="$(mktemp)"
FOUND=0
COUNT=0
SEP=""

for script_path in "$ABS_SOURCE_DIR"/*_monitor.sh; do
    [ -e "$script_path" ] || continue
    FOUND=1
    COUNT=$((COUNT + 1))

    script_file=$(basename "$script_path")
    unit_name="${script_file%.sh}"
    service_name="${unit_name}.service"
    timer_name="${unit_name}.timer"

    source_script_path="${script_path}"
    installed_script_path="${INSTALL_SCRIPT_DIR}/${script_file}"
    source_service_path="${ABS_SOURCE_DIR}/${service_name}"
    source_timer_path="${ABS_SOURCE_DIR}/${timer_name}"
    installed_service_path="${SYSTEMD_DIR}/${service_name}"
    installed_timer_path="${SYSTEMD_DIR}/${timer_name}"

    description="$(make_description "$script_file") monitor"

    echo "Found: $script_file"

    while true; do
        printf "Set interval for %s (e.g. 30s, 5min, 1h) [5min]: " "$unit_name"
        read interval
        interval="${interval:-5min}"

        if validate_interval "$interval"; then
            break
        fi

        echo "Invalid interval. Examples: 30s, 5min, 1h"
    done

    printf "Description [%s]: " "$description"
    read custom_description
    custom_description="${custom_description:-$description}"

    cp "$source_script_path" "$installed_script_path"
    chmod +x "$installed_script_path"

    cat > "$source_service_path" <<EOF
[Unit]
Description=${custom_description}

[Service]
Type=oneshot
ExecStart=${installed_script_path}
EOF

    cat > "$source_timer_path" <<EOF
[Unit]
Description=Run ${custom_description} every ${interval}

[Timer]
OnBootSec=1min
OnUnitActiveSec=${interval}
Unit=${service_name}

[Install]
WantedBy=timers.target
EOF

    cp "$source_service_path" "$installed_service_path"
    cp "$source_timer_path" "$installed_timer_path"

    echo "$timer_name" >> "$TMP_TIMERS_FILE"

    script_json=$(cat "$installed_script_path" | escape_json)
    service_json=$(cat "$installed_service_path" | escape_json)
    timer_json=$(cat "$installed_timer_path" | escape_json)

    custom_description_json=$(escape_json_string "$custom_description")

    printf '%s{\n' "$SEP" >> "$TMP_MONITORS_FILE"
    printf '      "monitor": "%s",\n' "$unit_name" >> "$TMP_MONITORS_FILE"
    printf '      "paths": {\n' >> "$TMP_MONITORS_FILE"
    printf '        "source_script": "%s",\n' "$source_script_path" >> "$TMP_MONITORS_FILE"
    printf '        "installed_script": "%s",\n' "$installed_script_path" >> "$TMP_MONITORS_FILE"
    printf '        "source_service": "%s",\n' "$source_service_path" >> "$TMP_MONITORS_FILE"
    printf '        "installed_service": "%s",\n' "$installed_service_path" >> "$TMP_MONITORS_FILE"
    printf '        "source_timer": "%s",\n' "$source_timer_path" >> "$TMP_MONITORS_FILE"
    printf '        "installed_timer": "%s"\n' "$installed_timer_path" >> "$TMP_MONITORS_FILE"
    printf '      },\n' >> "$TMP_MONITORS_FILE"
    printf '      "settings": {\n' >> "$TMP_MONITORS_FILE"
    printf '        "description": "%s",\n' "$custom_description_json" >> "$TMP_MONITORS_FILE"
    printf '        "on_unit_active_sec": "%s"\n' "$interval" >> "$TMP_MONITORS_FILE"
    printf '      },\n' >> "$TMP_MONITORS_FILE"
    printf '      "files": {\n' >> "$TMP_MONITORS_FILE"
    printf '        "script": "%s",\n' "$script_json" >> "$TMP_MONITORS_FILE"
    printf '        "service": "%s",\n' "$service_json" >> "$TMP_MONITORS_FILE"
    printf '        "timer": "%s"\n' "$timer_json" >> "$TMP_MONITORS_FILE"
    printf '      }\n' >> "$TMP_MONITORS_FILE"
    printf '    }' >> "$TMP_MONITORS_FILE"

    SEP=",\n"

    echo "Installed: $installed_script_path"
    echo "Created:   $installed_service_path"
    echo "Created:   $installed_timer_path"
    echo "Saved:     $source_service_path"
    echo "Saved:     $source_timer_path"
done

if [ "$FOUND" -eq 0 ]; then
    rm -f "$TMP_MONITORS_FILE" "$TMP_TIMERS_FILE"
    echo "INFO: No *_monitor.sh files found in $ABS_SOURCE_DIR"
    exit 0
fi

while true; do
    printf "Enter ALERT_EMAIL for log watcher: "
    read ALERT_EMAIL

    if validate_email "$ALERT_EMAIL"; then
        break
    fi

    echo "Invalid email format"
done

printf "Enter SENDER_EMAIL [admin@server.shpatakovskyid.pp.ua]: "
read SENDER_EMAIL
SENDER_EMAIL="${SENDER_EMAIL:-admin@server.shpatakovskyid.pp.ua}"

cat > "$LOG_WATCHER_SOURCE_PATH" <<EOF
#!/bin/bash

set -o pipefail

DISK_LOG="/var/log/monitor/disk_monitor.log"
RAM_LOG="/var/log/monitor/ram_monitor.log"
EMAIL_LOG="/var/log/monitor/email_notifications.log"
ALERT_EMAIL="$ALERT_EMAIL"
SENDER_EMAIL="$SENDER_EMAIL"
HOSTNAME=\$(hostname)

if [ ! -d "/var/log/monitor" ]; then
    echo "Error: Directory /var/log/monitor does not exist." >&2
    exit 1
fi

touch "\$DISK_LOG" "\$RAM_LOG" "\$EMAIL_LOG"

tail -F "\$DISK_LOG" "\$RAM_LOG" | while read -r line; do
    if echo "\$line" | grep -q "WARNING"; then
        TIMESTAMP=\$(date '+%Y-%m-%d %H:%M:%S')
        MESSAGE="[\$TIMESTAMP] Host: \$HOSTNAME - Event: \$line"

        echo "\$MESSAGE" >> "\$EMAIL_LOG"

        if ! echo "\$MESSAGE" | mail -s "System Monitor Warning - \$HOSTNAME" -a "From: \$SENDER_EMAIL" "\$ALERT_EMAIL"; then
            echo "Error: Failed to send email alert for event: \$line" >&2
        fi
    fi
done
EOF

chmod +x "$LOG_WATCHER_SOURCE_PATH"
cp "$LOG_WATCHER_SOURCE_PATH" "$LOG_WATCHER_INSTALLED_PATH"
chmod +x "$LOG_WATCHER_INSTALLED_PATH"

cat > "$LOG_WATCHER_SOURCE_SERVICE_PATH" <<EOF
[Unit]
Description=Monitor warning logs and send email alerts
After=network.target

[Service]
Type=simple
ExecStart=${LOG_WATCHER_INSTALLED_PATH}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cp "$LOG_WATCHER_SOURCE_SERVICE_PATH" "$LOG_WATCHER_INSTALLED_SERVICE_PATH"

systemctl daemon-reload

while IFS= read -r timer_name; do
    [ -n "$timer_name" ] || continue
    systemctl enable --now "$timer_name"
done < "$TMP_TIMERS_FILE"

systemctl enable --now "$LOG_WATCHER_SERVICE_NAME"

systemctl list-timers

while IFS= read -r timer_name; do
    [ -n "$timer_name" ] || continue
    systemctl status "$timer_name" || true
done < "$TMP_TIMERS_FILE"

systemctl status "$LOG_WATCHER_SERVICE_NAME" || true

watcher_script_json=$(cat "$LOG_WATCHER_INSTALLED_PATH" | escape_json)
watcher_service_json=$(cat "$LOG_WATCHER_INSTALLED_SERVICE_PATH" | escape_json)
sender_email_json=$(escape_json_string "$SENDER_EMAIL")
alert_email_json=$(escape_json_string "$ALERT_EMAIL")

{
    printf '{\n'
    printf '  "%s": {\n' "$RUN_TIMESTAMP"
    printf '    "monitors_count": %s,\n' "$COUNT"
    printf '    "source_dir": "%s",\n' "$ABS_SOURCE_DIR"
    printf '    "log_watcher": {\n'
    printf '      "alert_email": "%s",\n' "$alert_email_json"
    printf '      "sender_email": "%s",\n' "$sender_email_json"
    printf '      "paths": {\n'
    printf '        "source_script": "%s",\n' "$LOG_WATCHER_SOURCE_PATH"
    printf '        "installed_script": "%s",\n' "$LOG_WATCHER_INSTALLED_PATH"
    printf '        "source_service": "%s",\n' "$LOG_WATCHER_SOURCE_SERVICE_PATH"
    printf '        "installed_service": "%s"\n' "$LOG_WATCHER_INSTALLED_SERVICE_PATH"
    printf '      },\n'
    printf '      "files": {\n'
    printf '        "script": "%s",\n' "$watcher_script_json"
    printf '        "service": "%s"\n' "$watcher_service_json"
    printf '      }\n'
    printf '    },\n'
    printf '    "monitors": [\n'
    cat "$TMP_MONITORS_FILE"
    printf '\n'
    printf '    ]\n'
    printf '  }\n'
    printf '}\n'
} > "$LOG_FILE"

rm -f "$TMP_MONITORS_FILE" "$TMP_TIMERS_FILE"

echo "Created:   $LOG_WATCHER_SOURCE_PATH"
echo "Installed: $LOG_WATCHER_INSTALLED_PATH"
echo "Created:   $LOG_WATCHER_SOURCE_SERVICE_PATH"
echo "Created:   $LOG_WATCHER_INSTALLED_SERVICE_PATH"
echo "Log written to: $LOG_FILE"
echo "Monitors installed: $COUNT"
echo "Done."