# Scaling Notes

Nexus: Downfall should stay universe-first as it grows.

## Data ownership

- Global account data stays global: `users`, auth tokens and account-level preferences.
- Play state belongs to a universe: planets, fleets, missions, reports, rankings, clans, diplomacy, notifications and timed jobs must carry or be derivable from `universe_id`.
- Hot tables should prefer a direct `universe_id` column even when it can be reached through joins. This keeps authorization, rankings, cleanup, migrations and future partitioning simple.

## Persistence model

- PostgreSQL is the authority for durable game state.
- Resource balances are stored as integer whole units to avoid floating-point drift before commerce and combat arrive.
- LiveView may project resources locally for smooth UI, but mutations such as construction, fleet launch and trade must settle pending production inside the same database transaction that spends resources.

## Timed gameplay

- Oban is the persistent agenda for delayed work.
- Use domain queues instead of a single generic queue: `construction`, `fleet`, `combat`, `notifications`, `maintenance`.
- Workers must be idempotent. A retried or duplicate job should not apply the same gameplay result twice.
- Transport missions spend fuel and cargo in a single locked dispatch transaction, then perform one locked target update on arrival and one fleet status update on return. Load scales with mission transitions, not connected clients; LiveView only renders PubSub updates and a local progress timer.
- Planetary defense construction uses one durable queue per planet and one Oban completion per built unit. Queue inserts lock only the owning planet, the planet's defense rows and that planet's queue positions, so load scales with player build actions instead of connected clients. Under spikes, delayed workers slow construction completion but do not duplicate defenses because each active queue item is locked before mutation.

## Realtime topics

Use narrow PubSub topics so broadcasts do not fan out across a whole server:

- `universe:{id}:ranking`
- `user:{id}:notifications`
- `planet:{id}`
- `system:{id}`
- `fleet:{id}`

## Future partitioning

Start with one cluster and one database. Keep `universe_id` on hot entities so a future migration can move busy universes to dedicated schemas, databases or node pools without rewriting gameplay logic.
