---
name: humandelta-api
description: >
  Use when the agent needs to index websites, run vector search over org knowledge,
  manage uploaded documents, or explore/write the org KB virtual filesystem.
  All endpoints are under https://api.humandelta.ai.
  Auth: Authorization: Bearer hd_live_<key>  (org-scoped; no org slug in URL).
metadata:
  author: etok.zo.computer
  compatibility: Created for Zo Computer
---

# Human Delta API Skill

## Indexes

### Create and start a crawl job

```bash
curl -s -X POST https://api.humandelta.ai/v1/indexes \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "website",
    "name": "Help Center",
    "website": {
      "url": "https://docs.example.com",
      "max_pages": 100
    }
  }'
```

Poll `GET /v1/indexes/{index_id}` every 3–5 s until `status` is `completed`, `failed`, or `cancelled`.

### List all indexes

```bash
curl -s https://api.humandelta.ai/v1/indexes \
  -H "Authorization: Bearer hd_live_<key>"
```

## Search

### Vector similarity search

```bash
curl -s -X POST https://api.humandelta.ai/v1/search \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "How do I reset my password?",
    "top_k": 5,
    "sources": ["web", "documents"]
  }'
```

## Virtual Filesystem (VFS)

Base: `POST https://api.humandelta.ai/v1/fs` with `{ "op": "...", ...params }`

Writable paths: `/agent/*` (requires `fs:write` scope)

### Shell

```bash
curl -s -X POST https://api.humandelta.ai/v1/fs \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{ "op": "shell", "cmd": "tree /source -L 3" }'
```

### Read

```bash
curl -s -X POST https://api.humandelta.ai/v1/fs \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{ "op": "read", "path": "/source/website/docs.example.com/getting-started" }'
```

### Write (requires fs:write scope)

```bash
curl -s -X POST https://api.humandelta.ai/v1/fs \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{ "op": "write", "path": "/agent/notes/summary.md", "content": "# Summary\n..." }'
```

### Delete (requires fs:write scope)

```bash
curl -s -X POST https://api.humandelta.ai/v1/fs \
  -H "Authorization: Bearer hd_live_<key>" \
  -H "Content-Type: application/json" \
  -d '{ "op": "delete", "path": "/agent/notes/summary.md" }'
```

## Documents

### Upload a file (multipart)

```bash
curl -s -X POST https://api.humandelta.ai/v1/documents \
  -H "Authorization: Bearer hd_live_<key>" \
  -F "file=@/path/to/report.pdf"
```

### List documents

```bash
curl -s https://api.humandelta.ai/v1/documents \
  -H "Authorization: Bearer hd_live_<key>"
```

### Get extracted text

```bash
curl -s https://api.humandelta.ai/v1/documents/{doc_id}/preview \
  -H "Authorization: Bearer hd_live_<key>"
```

## Key Rules

- Every `/v1/*` endpoint is scoped to the org that owns the API key.
- Optional key scopes: `fs:read`, `fs:write`. Omit for full access.
- Indexing is async: `POST` returns `index_id` immediately; poll `GET` until `status=completed`.
- Search is synchronous: `POST` returns results directly.
- VFS `/agent/*` paths are writable with `fs:write` scope.
- Errors return `{ "detail": "<message>" }`.
