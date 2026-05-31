## Minimum Required Tasks
Suggested scraped-metric panel queries (PromQL, datasource Mimir):
`sum(rate(nginx_http_requests_total[1m]))`
`sum(rate(nginx_http_requests_total[1m]))`
![minimum:](./ht_items/minimum.png)

## Expected Deliverables
- Updated Alloy [config:](./ht_items/config.alloy)
- Screenshot of NGINX metrics query in Grafana Explore
- Screenshot of NGINX logs query in Grafana Explore
- Screenshot of a dashboard panel showing request error rate from scraped metrics
- Optional: screenshot of a dashboard panel showing 5xx rate using Loki datasource.