Using Prometheus
View Targets: Go to http://34.40.17.122.nip.io/prometheus/targets to see which services Prometheus is scraping

Currently, Matchmaking service is already instrumented and should show metrics
Query Metrics: Use the Graph tab to query metrics like:

http_requests_total - Total HTTP requests by service
http_request_duration_seconds - Request latency
trade_offers_created_total - Business metrics from Matchmaking
circuit_breaker_state - Circuit breaker status
grpc_requests_total - gRPC call metrics
📈 Creating Grafana Dashboards
Login to Grafana at http://34.40.17.122.nip.io/grafana
Verify Datasource: Go to Configuration → Data Sources (Prometheus should already be configured)
Create Dashboard: Click "+" → Dashboard → Add new panel
Add Metrics: Use queries like:
rate(http_requests_total[5m]) - Request rate per service
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) - 95th percentile latency
circuit_breaker_state - Circuit breaker status (0=closed, 1=open)
trade_offers_by_status - Offers by status (pending/accepted/rejected)