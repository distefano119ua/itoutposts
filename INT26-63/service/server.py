from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import random
import time


REQUESTS = {}
HIST_BUCKETS = [0.05, 0.1, 0.2, 0.3, 0.5, 1.0, float("inf")]
HIST_COUNTS = {}
HIST_SUMS = {}
HIST_TOTALS = {}


def inc_request(route, status):
    key = (route, str(status))
    REQUESTS[key] = REQUESTS.get(key, 0) + 1


def observe_duration(route, duration):
    HIST_SUMS[route] = HIST_SUMS.get(route, 0.0) + duration
    HIST_TOTALS[route] = HIST_TOTALS.get(route, 0) + 1
    for bucket in HIST_BUCKETS:
        key = (route, bucket)
        if duration <= bucket:
            HIST_COUNTS[key] = HIST_COUNTS.get(key, 0) + 1


def labels(route, status=None, le=None):
    parts = [f'route="{route}"']
    if status is not None:
        parts.append(f'status="{status}"')
    if le is not None:
        le_value = "+Inf" if le == float("inf") else str(le)
        parts.append(f'le="{le_value}"')
    return "{" + ",".join(parts) + "}"


def metrics_body():
    lines = [
        "# HELP sre_demo_requests_total Total HTTP requests by route and status.",
        "# TYPE sre_demo_requests_total counter",
    ]
    for (route, status), value in sorted(REQUESTS.items()):
        lines.append(f"sre_demo_requests_total{labels(route, status=status)} {value}")

    lines.extend(
        [
            "# HELP sre_demo_request_duration_seconds Request duration histogram.",
            "# TYPE sre_demo_request_duration_seconds histogram",
        ]
    )
    for route in sorted(HIST_TOTALS):
        for bucket in HIST_BUCKETS:
            value = HIST_COUNTS.get((route, bucket), 0)
            lines.append(
                f"sre_demo_request_duration_seconds_bucket{labels(route, le=bucket)} {value}"
            )
        lines.append(
            f'sre_demo_request_duration_seconds_sum{{route="{route}"}} {HIST_SUMS.get(route, 0.0):.6f}'
        )
        lines.append(
            f'sre_demo_request_duration_seconds_count{{route="{route}"}} {HIST_TOTALS.get(route, 0)}'
        )
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        start = time.monotonic()
        route = self.path.split("?")[0]

        if route == "/metrics":
            body = metrics_body().encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if route == "/fail":
            time.sleep(random.uniform(0.02, 0.08))
            status = 500
            body = b"simulated failure\n"
        elif route == "/slow":
            time.sleep(random.uniform(0.35, 0.7))
            status = 200
            body = b"slow response\n"
        else:
            route = "/"
            time.sleep(random.uniform(0.02, 0.12))
            status = 200
            body = b"ok\n"

        duration = time.monotonic() - start
        inc_request(route, status)
        observe_duration(route, duration)

        self.send_response(status)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()
