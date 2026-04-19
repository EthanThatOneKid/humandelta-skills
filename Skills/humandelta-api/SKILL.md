---
name: humandelta-api
description: >
  Use when you need to index websites, run vector search over org knowledge,
  manage uploaded documents, or explore/write the org KB virtual filesystem.
  All endpoints are under https://api.humandelta.ai.
  Auth: Authorization: Bearer hd_live_<key>  (org-scoped; no org slug in URL).
---

# Human Delta API Skill

> **API Key:** Set `HUMANDELTA_API_KEY` in your environment.

## Base URL

```
https://api.humandelta.ai
```

## Auth

```
Authorization: Bearer hd_live_<key>
```

All endpoints are org-scoped — no org slug in the URL.

## Content-Type

`application/json` for all endpoints except `/v1/documents` (multipart/form-data).

---

## Indexes

### Create and start a crawl job

```bash
curl -s -X POST https://api.humandelta.ai/v1/indexes \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "website",
    "source_url": "https://example.com",
    "max_pages_to_crawl": 100
  }'
```

Response `202`:
```json
{
  "index_id": "idx_...",
  "status": "pending"
}
```

### Poll until crawl completes

```bash
# Replace <index_id>
curl -s "https://api.humandelta.ai/v1/indexes/<index_id>" \
  -H "Authorization: Bearer hd_live_<key>"
```

Status values: `pending` → `processing` → `completed` | `failed`

### List all indexes

```bash
curl -s https://api.humandelta.ai/v1/indexes \
  -H "Authorization: Bearer hd_live_<key>"
```

---

## Search

### Vector similarity search

```bash
curl -s -X POST https://api.humandelta.ai/v1/search \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "<your question>",
    "top_k": 5,
    "filters": {
      "index_ids": ["idx_..."],
      "source_type": "web"
    }
  }'
```

Response `200`:
```json
{
  "results": [
    {
      "content": "...",
      "source_url": "https://docs.example.com/account/reset",
      "page_title": "Account & Password",
      "source_type": "web",
      "match_type": "semantic"
    }
  ]
}
```

---

## Virtual Filesystem (VFS)

### Run a VFS shell command

```bash
curl -s -X POST https://api.humandelta.ai/v1/fs \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{
    "cmd": "MKDIR",
    "path": "/my-org/knowledge"
  }'
```

### Write a file

```bash
curl -s -X POST https://api.humandelta.ai/v1/fs \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{
    "cmd": "WRITE",
    "path": "/my-org/knowledge/notes.md",
    "content": "# Notes\n\n..."
  }'
```

### Read a file

```bash
curl -s "https://api.humandelta.ai/v1/fs?path=/my-org/knowledge/notes.md" \
  -H "Authorization: Bearer hd_live_<key>"
```

### Delete a file

```bash
curl -s -X POST https://api.humandelta.ai/v1/fs \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{
    "cmd": "RM",
    "path": "/my-org/knowledge/notes.md"
  }'
```

---

## Documents

### List uploaded documents

```bash
curl -s https://api.humandelta.ai/v1/documents \
  -H "Authorization: Bearer hd_live_<key>"
```

### Upload a document (multipart)

```bash
curl -s -X POST https://api.humandelta.ai/v1/documents \
  -H "Authorization: Bearer hd_live_<key>" \
  -F "file=@/path/to/document.pdf"
```

Response `201`:
```json
{
  "doc_id": "doc_...",
  "status": "pending"
}
```

### Get extracted text

```bash
curl -s "https://api.humandelta.ai/v1/documents/<doc_id>/preview" \
  -H "Authorization: Bearer hd_live_<key>"
```

---

## Errors

All errors return JSON:

```json
{ "detail": "<human-readable message>" }
```

| Status | Meaning |
|--------|---------|
| 400 | Bad Request — invalid body |
| 401 | Unauthorized — missing/invalid key |
| 403 | Forbidden — key lacks required scope |
| 404 | Not Found — resource doesn't exist |
| 429 | Too Many Requests — rate limited |
| 500 | Server Error |

---

## Shell Helper

Run `scripts/humandelta.sh` for a CLI wrapper around these endpoints.

```bash
humandelta.sh indexes list
humandelta.sh indexes create "My Index" https://example.com 100
humandelta.sh search "how do I reset password" 5 web
humandelta.sh fs shell MKDIR /my-org/knowledge
humandelta.sh fs read /my-org/knowledge/notes.md
humandelta.sh docs list
humandelta.sh docs upload /path/to/file.pdf
```
