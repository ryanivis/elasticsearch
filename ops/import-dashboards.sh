#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=/home/ryanivis/elasticsearch
NDJSON_FILE="$ROOT_DIR/kibana/observability-dashboards.ndjson"
DATA_VIEW_FILE="$ROOT_DIR/kibana/application-logs-data-view.json"
ELASTIC_PASSWORD="$(grep '^ELASTIC_PASSWORD=' "$ROOT_DIR/.env" | cut -d= -f2-)"

cd "$ROOT_DIR"

status_code="$(
  docker compose exec -T kibana sh -lc \
    "curl -s -o /tmp/data-view-response.json -w '%{http_code}' -u elastic:$ELASTIC_PASSWORD -X POST http://127.0.0.1:5601/api/data_views/data_view -H 'kbn-xsrf:true' -H 'Content-Type: application/json' --data-binary @-" \
    < "$DATA_VIEW_FILE"
)"

if [[ "$status_code" != "200" && "$status_code" != "409" ]]; then
  response_body="$(docker compose exec -T kibana cat /tmp/data-view-response.json)"
  if [[ "$status_code" == "400" && "$response_body" == *"Duplicate data view"* ]]; then
    :
  else
    echo "Data view creation failed with HTTP $status_code" >&2
    echo "$response_body" >&2
    exit 1
  fi
fi

docker compose exec -T kibana sh -lc \
  "curl -sS -u elastic:$ELASTIC_PASSWORD -X POST 'http://127.0.0.1:5601/api/saved_objects/_import?overwrite=true' -H 'kbn-xsrf:true' --form 'file=@-;filename=observability-dashboards.ndjson;type=application/x-ndjson'" \
  < "$NDJSON_FILE"
