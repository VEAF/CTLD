# 01 — offer the settings the schema declares and the catalogue does not

**Status:** done

## What changed

- `/api/catalog` and `/api/defaults` include settings declared in the schema with a `default` that
  the **engine catalogue** does not carry. Keyed off the default catalogue, not the open one: it is a
  property of the engine, and `/api/defaults` has to answer before anything is loaded — the UI
  fetches it while booting. An existing test caught exactly that.
- The snapshot offers such a setting only while the open document has not set it; once set it lives
  in the Mission Maker's catalogue and listing it twice would be a bug.
- `put_setting` files a `standard:` setting under `mm_facing` instead of `advanced`.

## Why the defaults endpoint matters as much as the catalogue one

Without the schema default in `/api/defaults`, the UI compares the value against nothing and shows
the language as permanently modified — a false "changed" marker on a setting nobody touched.

## Tests

- The language is offered, with its four choices, and `standard: true`.
- It is not marked as changed before being touched (the defaults path).
- Setting it lands in `mm_facing`, and the key is not listed twice afterwards.
- It stays out of the completeness check, so no rc1–rc3 configuration starts reporting it.
