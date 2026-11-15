# NASA observation history — local TimescaleDB demonstration

We use TimescaleDB, maintained by Tiger Data, to store timestamped **retrieval checks** of the public NASA SDO metadata endpoint. A hypertable plus `time_bucket` answers: how many checks did we make, and how many distinct image hashes did those checks represent? Repeated downloads are not necessarily new observations.

This is a local, self-hosted demonstration. It is **not Tiger Cloud**, not an ongoing production ingestion service, and not learner analytics. The companion page serves a labelled JSON snapshot exported from the database. It does not query this database over the Internet.

## What was verified

- TimescaleDB **2.32.0**, PostgreSQL 17 container.
- `SHOW timescaledb.license` returned `apache`. We use the Apache-licensed core features, not community/enterprise features under the separate Timescale License. The distribution image contains components under different licenses; do not describe every TimescaleDB feature or the managed service as Apache-licensed.
- `observations` is a hypertable; actual public endpoint checks were inserted and queried by minute.
- Export: [`../mission-lab/data/history.json`](../mission-lab/data/history.json). Two real checks returned one distinct image hash. No synthetic dates, samples or radiation measurements were inserted.
- Container network is disabled, no ports are published, and SQL is run through `docker exec` over its local Unix socket. There is no public unauthenticated database endpoint.

## Reproduce

```sh
docker run --name komaku-observations --network none \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=komaku -d \
  timescale/timescaledb@sha256:6a6b7d7a346d7c6be03a310c240706f3bbc6d7adbdf3fbc07823570b34337f5e \
  -c timescaledb.license=apache

docker exec komaku-observations pg_isready -U postgres -d komaku
python services/observation-history/record.py
node services/mission-lab/scripts/build-context.mjs
```

Run the container creation only once. Existing container data survives stop/start, but is lost if the container is removed; production durability needs a persistent volume, backups, authentication and a deployment design. The JSON export remains in Git. The demo is intentionally isolated from the learner's device and production game.

Sources: [TimescaleDB code and licenses](https://github.com/timescale/timescaledb), [Apache core license](https://github.com/timescale/timescaledb/blob/main/LICENSE), [Tiger Data documentation](https://www.tigerdata.com/docs/). Code and documentation were developed with AI assistance; NASA source values are retrieved, not AI-generated.
