# Authenticated sync API

Set `POCKETBASE_URL` to enable `POST /api/sync`. The optional
`POCKETBASE_SYNC_COLLECTION` defaults to `sync_states`. PocketBase must have an
auth collection named `users` and a `sync_states` collection with these fields:

* `owner`: relation to `users` (required, unique)
* `cursor`: number (required)
* `items`: JSON

Set list/view/update/delete rules to `owner = @request.auth.id` and create to
`@request.data.owner = @request.auth.id`. The API passes the user's PocketBase
bearer token through and validates it with `users/auth-refresh`; sync is denied
when authentication or PocketBase configuration is absent.

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
