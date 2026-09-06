# Authenticated sync API

The Go backend embeds PocketBase and serves its standard API and admin UI on
the same port as `POST /api/sync`. No separate PocketBase process or
`POCKETBASE_URL` is required. PocketBase's system migrations provide the
`users` auth collection, and a committed Go migration creates `sync_states`
with these fields:

* `owner`: relation to `users` (required, unique)
* `cursor`: number (required)
* `items`: JSON

Collection rules limit records to their owner. The custom endpoint validates
the PocketBase bearer token directly against the embedded database and only
accepts tokens issued by `users`.

Persistent data defaults to `pb_data`. In production start with
`serve --http=0.0.0.0:8080 --dir=/persistent/pb_data`; the Docker image uses
`/pb_data` as a volume. Create the first admin with the PocketBase
`admin create EMAIL PASSWORD` command.

Request:

```json
{"clientId":"stable-installation-id","cursor":4,"baseCursor":7,"changes":[{"type":"result","id":"stable-object-id","data":{"score":95}},{"type":"note","id":"n1","deleted":true}]}
```

Response is `{"cursor":9,"changes":[...]}`. Each returned change has a
monotonically increasing `version`. First pull with `changes: []`, merge by
`type` + `id` (including tombstones), persist the returned cursor, then push
with `baseCursor` equal to that cursor. A stale push receives HTTP 409 plus the
current cursor and changes to merge. IDs are supplied by clients and remain
stable across devices; tombstones are retained indefinitely.
