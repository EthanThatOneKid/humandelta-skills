#!/usr/bin/env bash
# Human Delta API helper script
# Usage: ./humandelta.sh <command> [args]
#
# Commands:
#   indexes list                        List all indexes
#   indexes create <name> <url> [max]  Create and start a crawl job
#   indexes poll <index_id>             Poll until crawl completes
#   search <query> [top_k] [sources]    Vector similarity search
#   fs shell <cmd>                      Run VFS shell command
#   fs read <path>                      Read a VFS file
#   fs write <path> <content>           Write to a VFS file
#   fs delete <path>                    Delete a VFS file
#   docs list                           List uploaded documents
#   docs upload <file>                  Upload a file
#   docs preview <doc_id>               Get extracted text from a document

set -euo pipefail

API_KEY="${HUMANDELTA_API_KEY:?Please set HUMANDELTA_API_KEY}"
BASE_URL="https://api.humandelta.ai"
AUTH="Authorization: Bearer $API_KEY"

help() {
  grep "^#" "$0" | tail -n +2 | sed 's/^# \?//'
  exit 1
}

req() {
  curl -s -H "$AUTH" -H "Content-Type: application/json" "$@"
}

req_raw() {
  curl -s -H "$AUTH" "$@"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  indexes)
    sub="${1:-}"
    case "$sub" in
      list)
        req_raw "$BASE_URL/v1/indexes"
        ;;
      create)
        name="${1:?name required}"; url="${2:?url required}"; max="${3:-100}"
        req -X POST "$BASE_URL/v1/indexes" -d "{\"source_type\":\"website\",\"name\":\"$name\",\"website\":{\"url\":\"$url\",\"max_pages\":$max}}"
        ;;
      poll)
        idx="${1:?index_id required}"
        while true; do
          result=$(req_raw "$BASE_URL/v1/indexes/$idx")
          status=$(echo "$result" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
          echo "$result" | grep -v "pages_discovered\|pages_indexed\|stages\|completed_at" || true
          echo "status: $status"
          [[ "$status" == "completed" || "$status" == "failed" || "$status" == "cancelled" ]] && break
          sleep 4
        done
        ;;
      *) help ;;
    esac
    ;;
  search)
    query="${1:?query required}"; top="${2:-5}"; sources="${3:-web,documents}"
    req -X POST "$BASE_URL/v1/search" -d "{\"query\":\"$query\",\"top_k\":$top,\"sources\":[\"${sources//,/\\\",\\\"}\"]}"
    ;;
  fs)
    op="${1:?op required}"
    case "$op" in
      shell)   cmd="${1:?cmd required}"; req -X POST "$BASE_URL/v1/fs" -d "{\"op\":\"shell\",\"cmd\":\"$cmd\"}" ;;
      read)    path="${1:?path required}"; req -X POST "$BASE_URL/v1/fs" -d "{\"op\":\"read\",\"path\":\"$path\"}" ;;
      write)   path="${1:?path required}"; content="${2:-}"; req -X POST "$BASE_URL/v1/fs" -d "{\"op\":\"write\",\"path\":\"$path\",\"content\":\"$content\"}" ;;
      delete)  path="${1:?path required}"; req -X POST "$BASE_URL/v1/fs" -d "{\"op\":\"delete\",\"path\":\"$path\"}" ;;
      stat)    path="${1:?path required}"; req -X POST "$BASE_URL/v1/fs" -d "{\"op\":\"stat\",\"path\":\"$path\"}" ;;
      *) help ;;
    esac
    ;;
  docs)
    sub="${1:-}"
    case "$sub" in
      list)    req_raw "$BASE_URL/v1/documents" ;;
      upload)  file="${1:?file required}"; curl -s -H "$AUTH" -F "file=@$file" "$BASE_URL/v1/documents" ;;
      preview) id="${1:?doc_id required}"; req_raw "$BASE_URL/v1/documents/$id/preview" ;;
      *) help ;;
    esac
    ;;
  *) help ;;
esac
