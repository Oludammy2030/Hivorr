# Worker and Transactional Outbox

**Status:** The worker process, lease-based outbox consumer, retry/backoff,
dead-lettering, and queue-health endpoint are implemented and tested. No
production handlers are registered yet, so every real event type is
dead-lettered with a clear error until a handler lands. The worker is not
deployed to any environment.

## 1. Delivery model

1. A request changes state and inserts `platform.outbox` in the **same database
   transaction**.
2. The worker claims a batch with `for update skip locked`, leases each row, and
   commits the claim.
3. Each event is dispatched to exactly one handler registered for its
   `event_type`.
4. Success sets `processed_at`. Failure increments `attempts`, sets
   `last_error`, and schedules `available_at` with exponential backoff.
5. At `WORKER_MAX_ATTEMPTS` the row is dead-lettered (`dead_lettered_at`). A row
   with no registered handler is dead-lettered immediately.

Delivery is **at-least-once**. A crash after the side effect but before
`processed_at` causes redelivery. Every handler must therefore be idempotent and
key it on `event.id`; the worker passes the same id to every delivery.

## 2. Leases

- A claim sets `locked_at` and `locked_by`.
- A claim older than `WORKER_LEASE_MS` is reclaimable by another worker, so a
  crashed process does not block the queue.
- `complete`, `fail`, and `deadLetter` only update a row still owned by the
  claiming `WORKER_ID`. A worker whose lease was stolen cannot overwrite the new
  owner's result.
- **`WORKER_ID` must be unique per process.** The default includes the hostname
  and PID. Set it explicitly only when the platform already supplies a unique
  instance id.

## 3. Retry policy

`available_at = now() + min(base × 2^attempts, 1 hour)`.

The delay has no jitter so retry timing is deterministic and testable. The
attempt cap is `WORKER_MAX_ATTEMPTS` (default 5). Dead letters are retained, are
never deleted automatically, and are excluded from claims.

## 4. Handler contract

```ts
handlers.register("identity.user_registered", async (event, context) => {
  // event.id is stable across redeliveries; use it as the idempotency key.
  // event.payload is untrusted input: validate it before use.
  // context.signal aborts on shutdown; pass it to long provider calls.
  // context.attempt starts at 1.
})
```

Rules:

- Validate `payload` with a schema. Never trust an event payload.
- Do not log payloads, email addresses, phone numbers, or provider secrets.
- Treat a missing handler as a defect: it dead-letters immediately.
- A permanent provider rejection should throw only if it is genuinely retryable;
  otherwise dead-letter deliberately rather than burning the attempt budget.

## 5. Queue health

The worker serves, on `WORKER_HEALTH_HOST:WORKER_HEALTH_PORT`:

| Path | Meaning |
| --- | --- |
| `GET /health/live` | Process is alive. No database access. |
| `GET /health/ready` | Database reachable; returns queue counts. |
| `GET /health/queue` | `pending`, `leased`, `deadLettered`, `oldestPendingAt`. |

The payload contains counts and one timestamp only. The endpoint has no
authentication and must stay on the private Fly.io network or behind an
authenticated internal route; it must never be exposed on a public hostname.

## 6. Operational queries

Inspect the backlog (read-only):

```sql
select event_type,
       count(*) filter (where processed_at is null and dead_lettered_at is null) as pending,
       count(*) filter (where dead_lettered_at is not null) as dead_lettered,
       min(occurred_at) filter (where processed_at is null and dead_lettered_at is null) as oldest_pending
from platform.outbox
group by event_type
order by dead_lettered desc, pending desc;
```

Inspect dead letters:

```sql
select id, event_type, aggregate_type, aggregate_id, attempts,
       last_error, occurred_at, dead_lettered_at
from platform.outbox
where dead_lettered_at is not null
order by dead_lettered_at desc
limit 50;
```

A deliberate re-queue resets delivery state. The worker will then retry the
event, so confirm the handler is fixed and the side effect is idempotent first:

```sql
update platform.outbox
set processed_at = null,
    dead_lettered_at = null,
    locked_at = null,
    locked_by = null,
    attempts = 0,
    last_error = null,
    available_at = now()
where id = '<event-id>';
```

This is an operator action, not an application path. Record it in the incident
or change log.

## 7. Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `WORKER_DATABASE_URL` | `DATABASE_URL` | Least-privilege worker connection |
| `WORKER_POLL_INTERVAL_MS` | `1000` | Idle poll interval |
| `WORKER_BATCH_SIZE` | `20` | Maximum events claimed per batch |
| `WORKER_LEASE_MS` | `60000` | Claim lease before another worker may reclaim |
| `WORKER_MAX_ATTEMPTS` | `5` | Attempts before dead-lettering |
| `WORKER_RETRY_BASE_MS` | `5000` | First backoff step |
| `WORKER_HEALTH_PORT` | `3001` | Health listener port |
| `WORKER_HEALTH_HOST` | `0.0.0.0` | Health listener address |
| `WORKER_ID` | host + pid | Unique instance identity |

The worker role may select and update outbox rows and read queue health. It may
not insert outbox events: only the API produces them.

## 8. Tests

- `pnpm test` — retry policy and registry unit tests.
- `pnpm test:worker` — claim, complete, backoff, dead-letter, lease recovery,
  missing handler, idempotent replay, and health against PostgreSQL.
- `pnpm test:db` — migration, column, grant, and privilege assertions.
