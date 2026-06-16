#!/bin/sh
set -eu

until curl -s -o /dev/null "http://sre-demo:8080/"; do
  sleep 1
done

i=0
while true; do
  i=$((i + 1))

  curl -s -o /dev/null "http://sre-demo:8080/" || true

  if [ $((i % 8)) -eq 0 ]; then
    curl -s -o /dev/null "http://sre-demo:8080/fail" || true
  fi

  if [ $((i % 5)) -eq 0 ]; then
    curl -s -o /dev/null "http://sre-demo:8080/slow" || true
  fi

  sleep 0.25
done
