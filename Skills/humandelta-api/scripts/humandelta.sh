#!/usr/bin/env bash
# Human Delta API CLI helper
# Requires: HUMANDELTA_API_KEY set in environment
#
# Usage: humandelta.sh <command> [args]

set -e

BASE_URL="https://api.humandelta.ai"
KEY="${HUMANDELTA_API_KEY:?Missing HUMANDELTA_API_KEY}"

auth_header() {
  echo "Authorization: Bearer $KEY"
}

json_header() {
  echo "Content-Type: application/json"
}

case "$1" in
  indexes)
    case "$2" in
      list)
        curl -s "$BASE_URL/v1/indexes" \
          -H "$(auth_header)"
        ;;
      create)
        name="${3:?Usage: indexes create <name> <url> [max_pages]}"
        url="${4:?Missing url}"
        max="${5:-100}"
        curl -s -X POST "$BASE_URL/v1/indexes" \
          -H "$(auth_header)" \
          -H "$(json_header)" \
          -d "{
            \"source_type\": \"website\",
            \"source_url\": \"$url\",
            \"max_pages_to_crawl\": $max
          }"
        ;;
      poll)
        index_id="${3:?Usage: indexes poll <index_id>}"
        curl -s "$BASE_URL/v1/indexes/$index_id" \
          -H "$(auth_header)"
        ;;
      *)
        echo "Usage: humandelta.sh indexes {list|create <name> <url> [max]|poll <index_id>}"
        exit 1
        ;;
    esac
    ;;
  search)
    query="${2:?Usage: humandelta.sh search <query> [top_k]}"
    top_k="${3:-5}"
    curl -s -X POST "$BASE_URL/v1/search" \
      -H "$(auth_header)" \
      -H "$(json_header)" \
      -d "{
        \"query\": \"$query\",
        \"top_k\": $top_k
      }"
    ;;
  fs)
    case "$2" in
      shell)
        cmd="${3:?Usage: fs shell <CMD> <path>}"
        path="${4:?Missing path}"
        curl -s -X POST "$BASE_URL/v1/fs" \
          -H "$(auth_header)" \
          -H "$(json_header)" \
          -d "{\"cmd\": \"$cmd\", \"path\": \"$path\"}"
        ;;
      read)
        path="${3:?Usage: fs read <path>}"
        curl -s "$BASE_URL/v1/fs?path=$path" \
          -H "$(auth_header)"
        ;;
      write)
        path="${3:?Usage: fs write <path> <content>}"
        content="${4:?Missing content}"
        curl -s -X POST "$BASE_URL/v1/fs" \
          -H "$(auth_header)" \
          -H "$(json_header)" \
          -d "{\"cmd\": \"WRITE\", \"path\": \"$path\", \"content\": \"$content\"}"
        ;;
      delete|rm)
        path="${3:?Usage: fs delete <path>}"
        curl -s -X POST "$BASE_URL/v1/fs" \
          -H "$(auth_header)" \
          -H "$(json_header)" \
          -d "{\"cmd\": \"RM\", \"path\": \"$path\"}"
        ;;
      *)
        echo "Usage: humandelta.sh fs {shell <CMD> <path>|read <path>|write <path> <content>|delete <path>}"
        exit 1
        ;;
    esac
    ;;
  docs)
    case "$2" in
      list)
        curl -s "$BASE_URL/v1/documents" \
          -H "$(auth_header)"
        ;;
      upload)
        filepath="${3:?Usage: docs upload <filepath>}"
        curl -s -X POST "$BASE_URL/v1/documents" \
          -H "$(auth_header)" \
          -F "file=@$filepath"
        ;;
      preview)
        doc_id="${3:?Usage: docs preview <doc_id>}"
        curl -s "$BASE_URL/v1/documents/$doc_id/preview" \
          -H "$(auth_header)"
        ;;
      *)
        echo "Usage: humandelta.sh docs {list|upload <filepath>|preview <doc_id>}"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Human Delta API CLI"
    echo ""
    echo "Commands:"
    echo "  indexes list                       List all indexes"
    echo "  indexes create <name> <url> [max]  Create and start a crawl job"
    echo "  indexes poll <index_id>            Poll until crawl completes"
    echo "  search <query> [top_k]             Vector similarity search"
    echo "  fs shell <CMD> <path>              Run VFS shell command"
    echo "  fs read <path>                     Read a VFS file"
    echo "  fs write <path> <content>          Write to a VFS file"
    echo "  fs delete <path>                    Delete a VFS file"
    echo "  docs list                           List uploaded documents"
    echo "  docs upload <filepath>             Upload a document"
    echo "  docs preview <doc_id>              Get extracted text"
    echo ""
    echo "Environment: HUMANDELTA_API_KEY=hd_live_..."
    exit 1
    ;;
esac
