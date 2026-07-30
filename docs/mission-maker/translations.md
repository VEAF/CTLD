# Translations

CTLD talks to your players in their own language. Every message the script shows — F10 menu
entries, radio calls, status text — goes through a translation layer, so you can pick the
language your mission runs in and override any individual string without touching CTLD's code.

If you want the internals (how `ctld.tr()` resolves a string, how translators maintain the
dictionaries, how to contribute a new language), see the
[Internationalisation guide](../developer/i18n.md) in the developer docs. This page covers only
what a mission maker needs.

## Available languages

CTLD ships with four built-in dictionaries:

| Code | Language |
| --- | --- |
| `en` | English (reference) |
| `fr` | French |
| `es` | Spanish |
| `ko` | Korean |

English is the reference: it always has every string, so it is used as the fallback whenever a
translation is missing.

## Choosing the language

The active language is the **`i18n_lang` setting** — set it like any other setting, in `ctld-tools`
or by hand in your configuration snapshot:

```yaml
mm_facing:
  i18n_lang: fr
```

Valid values are `en` (the default), `fr`, `es` and `ko`. This is a mission-level choice: it applies
to every player on the server.

!!! note "The legacy selector still works"
    Older missions selected the language by editing the top of `src/CTLD_i18n.lua`
    (`ctld.i18n_lang = "fr"`), and that still works — CTLD reads the `i18n_lang` setting first, and
    falls back to that module global, then to `en`. Prefer the setting: it needs no source edit and
    survives a CTLD upgrade.

## How fallback works

You never have to worry about a blank or missing message. If a string is absent or empty in the
active language, CTLD falls back automatically, in order:

1. the active language dictionary,
2. the English dictionary,
3. the English text itself.

A message is **never** empty or `nil`.

## Overriding specific strings

You can change any single string from your mission — no need to edit a CTLD source file. Declare
`ctld.i18n_overrides` in your `CTLD_userConfig.lua`:

```lua
-- CTLD_userConfig.lua
ctld = ctld or {}

-- Override specific strings, per language
ctld.i18n_overrides = {
    fr = {
        ["Pack Vehicles"] = "Empaqueter vehicules",
        ["Drop Beacon"]   = "Poser balise radio",
    },
    en = {
        ["CTLD Commands"] = "Helicopter Commands",
    },
}
```

The key on the left is the English text CTLD uses internally; the value on the right is what
players see. Overrides are applied once at startup, on top of the built-in dictionaries. You can
override any language independently of which one is active — so you can, for example, tweak the
English wording even while running the mission in French.

## Related pages

- [Configuration](configuration.md) — global settings and per-aircraft capabilities
- [Zone setup](zones.md) — troop, logistics, extract and waypoint zones
- [Crate catalogue](crates-catalogue.md) — the crates pilots can spawn
