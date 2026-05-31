#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=/home/ryanivis/elasticsearch
NDJSON_FILE="$ROOT_DIR/kibana/observability-dashboards.ndjson"
DATA_VIEW_FILE="$ROOT_DIR/kibana/application-logs-data-view.json"
ELASTIC_PASSWORD="$(grep '^ELASTIC_PASSWORD=' "$ROOT_DIR/.env" | cut -d= -f2-)"
DATA_VIEW_SAVED_OBJECT_JSON="$(python3 - "$DATA_VIEW_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data_view = json.load(fh)["data_view"]

attributes = {
    "title": data_view["title"],
    "name": data_view["name"],
    "timeFieldName": data_view["timeFieldName"],
    "allowNoIndex": data_view.get("allowNoIndex", True),
    "allowHidden": data_view.get("allowHidden", False),
    "fieldAttrs": "{}",
    "sourceFilters": "[]",
    "fields": "[]",
    "fieldFormatMap": "{}",
    "runtimeFieldMap": json.dumps(data_view.get("runtimeFieldMap", {})),
}

print(json.dumps({"attributes": attributes}))
PY
)"

cd "$ROOT_DIR"

delete_status="$(
  docker compose exec -T kibana sh -lc \
    "curl -s -o /tmp/data-view-delete-response.json -w '%{http_code}' -u elastic:$ELASTIC_PASSWORD -X DELETE http://127.0.0.1:5601/api/data_views/data_view/app-logs-data-view -H 'kbn-xsrf:true'"
)"

if [[ "$delete_status" != "200" && "$delete_status" != "404" ]]; then
  response_body="$(docker compose exec -T kibana cat /tmp/data-view-delete-response.json)"
  echo "Data view delete failed with HTTP $delete_status" >&2
  echo "$response_body" >&2
  exit 1
fi

status_code="$(
  docker compose exec -T kibana sh -lc \
    "curl -s -o /tmp/data-view-response.json -w '%{http_code}' -u elastic:$ELASTIC_PASSWORD -X POST http://127.0.0.1:5601/api/data_views/data_view -H 'kbn-xsrf:true' -H 'Content-Type: application/json' --data-binary @-" \
    < "$DATA_VIEW_FILE"
)"

if [[ "$status_code" != "200" ]]; then
  response_body="$(docker compose exec -T kibana cat /tmp/data-view-response.json)"
  echo "Data view creation failed with HTTP $status_code" >&2
  echo "$response_body" >&2
  exit 1
fi

saved_object_status="$(
  printf '%s' "$DATA_VIEW_SAVED_OBJECT_JSON" | docker compose exec -T kibana sh -lc \
    "curl -s -o /tmp/data-view-saved-object-response.json -w '%{http_code}' -u elastic:$ELASTIC_PASSWORD -X PUT http://127.0.0.1:5601/api/saved_objects/index-pattern/app-logs-data-view -H 'kbn-xsrf:true' -H 'Content-Type: application/json' --data-binary @-"
)"

if [[ "$saved_object_status" != "200" ]]; then
  response_body="$(docker compose exec -T kibana cat /tmp/data-view-saved-object-response.json)"
  echo "Data view saved object update failed with HTTP $saved_object_status" >&2
  echo "$response_body" >&2
  exit 1
fi

docker compose exec -T kibana sh -lc \
  "curl -sS -u elastic:$ELASTIC_PASSWORD -X POST 'http://127.0.0.1:5601/api/saved_objects/_import?overwrite=true' -H 'kbn-xsrf:true' --form 'file=@-;filename=observability-dashboards.ndjson;type=application/x-ndjson'" \
  < "$NDJSON_FILE"
