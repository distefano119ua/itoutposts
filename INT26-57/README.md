## Minimum Required Tasks
Suggested scraped-metric panel queries (PromQL, datasource `Mimir`):
```promql
sum(rate(nginx_http_requests_total[1m]))
```

```promql
avg(nginx_up)
```
![minimum:](./ht_items/minimum.png)

## Additional Tasks
```promql
sum(count_over_time({job="nginx",status="500"}[1m]))
```

Error rate from logs (%):
```promql
100 *
sum(count_over_time({job="nginx",status=~"5.."}[1m]))
/
sum(count_over_time({job="nginx"}[1m]))
```
![error rate](./ht_items/error_rate.png)

## dashboard panel from that log-based metric.
![dashboard](./ht_items/dashboard.png)


Open:
- Grafana: `http://localhost:3000`
- NGINX exporter metrics: `http://localhost:9113/metrics`
- Alloy UI/metrics: `http://localhost:12347`
![open](./ht_items/open.png)


## Expected Deliverables
- Updated Alloy [config:](./ht_items/config.alloy)
- Screenshot of NGINX metrics query in Grafana Explore
![nginx_metrics](./ht_items/nginx_metrics.png)
- Screenshot of NGINX logs query in Grafana Explore
![nginx_logs](./ht_items/nginx_logs.png)
- Screenshot of a dashboard panel showing request error rate from scraped metrics [DONE]
- Optional: screenshot of a dashboard panel showing 5xx rate using Loki datasource. [DONE]