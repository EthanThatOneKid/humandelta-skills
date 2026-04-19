---
name: humandelta-api
description: >
  Use when the agent needs to index websites, run vector search over org knowledge,
  manage uploaded documents, or explore/write the org KB virtual filesystem.
  All endpoints are under https://api.humandelta.ai.
  Auth: Authorization: Bearer hd_live_<key>  (org-scoped; no org slug in URL).
---

# Human Delta API  —  full agent reference

Base URL : https://api.humandelta.ai
Auth     : Authorization: Bearer hd_live_...
Content  : application/json (except multipart for /v1/documents upload)

Key rules:
- Every /v1/* endpoint is scoped to the org that owns the API key.
- Optional key scopes: fs:read, fs:write. Omit for full access.
- Indexing is async: POST returns index_id immediately; poll GET until status=completed.
- Search is synchronous: POST returns results directly.
- /v1/fs requires at least fs:read scope for reads; fs:write for write/delete.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INDEXES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

POST /v1/indexes  — create and start a crawl job

Request body (JSON):
{
  "source_type": "website",          // required; only "website" supported today
  "name": "Help Center",             // required; human label for this index
  "website": {
    "url": "https://docs.example.com",  // required; seed URL to crawl
    "max_pages": 100                    // optional; default 100, max 500
                                        // requests above 500 → 400 error
  }
}

Response 200:
{
  "index_id": "idx_abc123",
  "status": "queued"
}

───────────────────────────────────────────────

GET /v1/indexes/{index_id}  — poll crawl status

Response 200:
{
  "index_id": "idx_abc123",
  "name": "Help Center",
  "status": "completed",             // queued | running | completed | failed | cancelled
  "source_type": "website",
  "source_url": "https://docs.example.com",
  "pages_discovered": 42,
  "pages_indexed": 40,
  "created_at": "2026-04-18T10:00:00Z",
  "completed_at": "2026-04-18T10:03:12Z",
  "stages": {
    "discover": "completed",         // each stage: pending | running | completed | failed
    "fetch":    "completed",
    "parse":    "completed",
    "chunk":    "completed",
    "embed":    "completed",
    "store":    "completed"
  }
}

Polling pattern: check every 3-5 s; stop when status ∈ {completed, failed, cancelled}.

───────────────────────────────────────────────

GET /v1/indexes  — list all indexes for this org

Response 200: { "indexes": [ /* same shape as GET /v1/indexes/{id} */ ] }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SEARCH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

POST /v1/search  — vector similarity search

Request body (JSON):
{
  "query":   "How do I reset my password?",  // required
  "top_k":   5,                              // optional; 1-20, default 5
  "sources": ["web", "documents"]            // optional; default both
                                             // "web"       = indexed website pages
                                             // "documents" = uploaded files (PDF, CSV, …)
}

Response 200:
{
  "results": [
    {
      "chunk_id":    "chk_xyz",
      "score":       0.91,               // cosine similarity 0-1; higher = more relevant
      "text":        "To reset your password, visit …",
      "source_url":  "https://docs.example.com/account/reset",
      "page_title":  "Account & Password",
      "source_type": "web",             // "web" | "document"
      "match_type":  "semantic"         // always "semantic" for now
    }
  ]
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VIRTUAL FILESYSTEM  (POST /v1/fs)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The KB is exposed as a read-only virtual tree (plus writable /agent/).
All ops go to:  POST /v1/fs  with JSON body { "op": "...", ...params }

VFS directory structure:
/
├── source/
│   └── website/
│       └── <domain>/         # one dir per indexed URL domain
│           └── <page-slug>   # page content as text/markdown
├── uploads/                  # org-uploaded documents (PDF→text, images, CSV, …)
├── agent/                    # org shared memory — readable by all, writable with fs:write
│   └── (any path you write)
└── skills/                   # read-only skill definitions (if configured)

─── op: shell ───────────────────────────────

{ "op": "shell", "cmd": "<command>" }

Runs a constrained shell over the virtual tree.
Allowed commands: tree, ls, cat, find, grep, head, wc, echo
Examples:
  { "op": "shell", "cmd": "tree /source -L 3" }
  { "op": "shell", "cmd": "ls /uploads" }
  { "op": "shell", "cmd": "cat /source/website/docs.example.com/getting-started" }
  { "op": "shell", "cmd": "grep -r 'billing' /source" }
  { "op": "shell", "cmd": "find /agent -name '*.md'" }

Response: { "output": "<stdout as plain text>" }

─── op: read ────────────────────────────────

{ "op": "read", "path": "/source/website/docs.example.com/getting-started" }

Returns full file content.
Response: { "content": "<file text>" }

─── op: stat ────────────────────────────────

{ "op": "stat", "path": "/source/website" }

Returns directory listing or file metadata.
Response (directory): { "entries": [{ "name": "docs.example.com", "type": "dir" }] }
Response (file):      { "name": "getting-started", "type": "file", "size": 4821 }
Response (missing):   { "exists": false }

─── op: write  (requires fs:write scope) ────

{ "op": "write", "path": "/agent/notes/summary.md", "content": "# Summary\n..." }

Only /agent/* paths are writable. Creates parent dirs automatically.
Response: { "ok": true }

─── op: delete  (requires fs:write scope) ───

{ "op": "delete", "path": "/agent/notes/summary.md" }

Only /agent/* paths are deletable.
Response: { "ok": true }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DOCUMENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

POST /v1/documents  — upload a file (multipart/form-data)

Field: file  — the file to upload
Allowed types: PDF, PNG, JPEG, WEBP, TXT, MD, CSV
Max size: 10 MB

Response 200:
{
  "doc_id":   "doc_abc123",
  "doc_name": "report.pdf",
  "status":   "processing"   // processing | ready | failed
}

───────────────────────────────────────────────

GET /v1/documents  — list all uploaded documents

Response 200: { "documents": [{ "doc_id", "doc_name", "status", "created_at" }] }

───────────────────────────────────────────────

GET /v1/documents/{doc_id}/preview  — get extracted text

Response 200: { "text": "<extracted plain text from the file>" }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ERRORS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All errors return JSON: { "detail": "<human-readable message>" }

400 Bad Request   — invalid body (missing required field, max_pages > 500, etc.)
401 Unauthorized  — missing or invalid API key
403 Forbidden     — key lacks required scope (e.g. fs:write)
404 Not Found     — resource does not exist
429 Too Many Req  — rate limit exceeded; back off and retry
500 Server Error  — transient; safe to retry after 5 s
