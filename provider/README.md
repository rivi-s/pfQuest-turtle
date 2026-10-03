# pfQuest HearthDB provider for Turtle WoW

This addon supplies pfQuest with asynchronous quest, entity, item, spawn, and
search data from a read-only SQLite database through HearthDB. It is loaded with
the HDB editions of pfQuest and pfQuest-turtle.

The current runtime is ENUS-only. Large generated Lua database tables are not
loaded by either addon. Small map metadata tables remain in Lua for coordinate
conversion and map presentation.

## Runtime requirements

- A vanilla 1.12 Turtle WoW client
- HearthDB installed in the client
- The matching HDB editions of pfQuest and pfQuest-turtle
- `data/pfquest-turtle.sqlite` packaged with this provider

The provider opens SQLite read-only and submits queries through HearthDB's
asynchronous API. `/pfqhdb` reports provider status. `/pfqhdb cacheclear` clears
the provider's in-memory query caches.

## Build the database

```sh
python3 tools/build_database.py \
  --source /path/to/pfQuest \
  --locales enUS \
  --output data/pfquest.sqlite
```

Add `--turtle-source /path/to/pfQuest-turtle` and use the
`pfquest-turtle.sqlite` output name to build the complete Turtle edition.

The alpha build defaults to ENUS only. Additional locales can be added later as
a comma-separated `--locales` list without changing the database schema or
runtime query contract.

The exporter applies the effective base and Turtle overwrite files before
writing SQLite rows. Validate a completed build with:

```sh
sqlite3 data/pfquest-turtle.sqlite 'PRAGMA integrity_check;'
```

Generated `.sqlite` and staging `.tsv` files are ignored by Git. Distribute the
database as a release artifact or package output rather than committing it to
source history.
