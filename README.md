# Elasticsearch Stack

This stack runs a private single-node Elasticsearch instance, a Kibana frontend routed through HAProxy behind mTLS, and a lightweight Filebeat collector that ships selected Docker logs into Elasticsearch.

## What it collects

- `ivis-app`
- `ivis-web`
- `ivis-backup`
- `teslamate-haproxy-1`
- `teslamate-teslamate-1`

## Exposure model

- Elasticsearch stays on the internal Docker network only
- Kibana is reachable at `https://kibana.lastcloudstanding.com`
- Kibana is intended to stay behind the existing HAProxy mTLS gate

## Credentials

Operational settings live in `.env`.

- `ELASTIC_PASSWORD` is the admin login for Kibana
- `KIBANA_PASSWORD` is the internal `kibana_system` service password
- `KIBANA_ENCRYPTION_KEY` protects Kibana secrets and saved objects

## Operations

Bring the stack up:

```bash
./ops/deploy.sh
```

Useful checks:

```bash
docker compose ps
docker compose logs -f elasticsearch
docker compose logs -f kibana
docker compose logs -f filebeat
```

Import or refresh the Kibana dashboards:

```bash
./ops/import-dashboards.sh
```

## Notes

- The shipper only keeps the named application logs, so it does not become a broad container vacuum.
- `ops/deploy.sh` regenerates `filebeat/filebeat.yml` from the current Docker log paths before each start, so it keeps following the right containers after they are recreated.
- The stack is sized to stay modest: single-node Elasticsearch, Kibana, and one Filebeat instance.
- Kibana includes two security-focused dashboards:
  - `HAProxy Security Watch`
  - `Ivis Photography Security Watch`
