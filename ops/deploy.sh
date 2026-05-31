#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=/home/ryanivis/elasticsearch
PROXY_NET=proxy

cd "$REPO_DIR"
docker network inspect "$PROXY_NET" >/dev/null 2>&1 || docker network create "$PROXY_NET" >/dev/null

log_path() {
  docker inspect -f '{{.LogPath}}' "$1"
}

cat > "$REPO_DIR/filebeat/filebeat.yml" <<EOF
filebeat.inputs:
  - type: filestream
    id: ivis-app
    enabled: true
    paths:
      - $(log_path ivis-app)
    parsers:
      - container:
          stream: all
          format: docker
    fields_under_root: true
    fields:
      stack_name: ivisphotography
      service_name: ivis-app

  - type: filestream
    id: ivis-web
    enabled: true
    paths:
      - $(log_path ivis-web)
    parsers:
      - container:
          stream: all
          format: docker
    fields_under_root: true
    fields:
      stack_name: ivisphotography
      service_name: ivis-web

  - type: filestream
    id: ivis-backup
    enabled: true
    paths:
      - $(log_path ivis-backup)
    parsers:
      - container:
          stream: all
          format: docker
    fields_under_root: true
    fields:
      stack_name: ivisphotography
      service_name: ivis-backup

  - type: filestream
    id: teslamate-haproxy
    enabled: true
    paths:
      - $(log_path teslamate-haproxy-1)
    parsers:
      - container:
          stream: all
          format: docker
    fields_under_root: true
    fields:
      stack_name: teslamate
      service_name: teslamate-haproxy

  - type: filestream
    id: teslamate-app
    enabled: true
    paths:
      - $(log_path teslamate-teslamate-1)
    parsers:
      - container:
          stream: all
          format: docker
    fields_under_root: true
    fields:
      stack_name: teslamate
      service_name: teslamate

processors:
  - add_tags:
      tags: ["docker", "home-observability"]
  - add_fields:
      target: ""
      fields:
        observer_stack: "elasticsearch"
        observer_cluster: "ryan-observability"

setup.ilm.enabled: false
setup.template.enabled: false

output.elasticsearch:
  hosts: ["http://elasticsearch:9200"]
  username: "elastic"
  password: "\${ELASTIC_PASSWORD}"
  index: "app-logs-%{+yyyy.MM.dd}"
EOF

docker compose up -d
