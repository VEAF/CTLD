<script lang="ts">
  // Editor for positional zone arrays (troopZones / wpZones / AIZones). Converts to named
  // records for editing (via the backend field schema) and back to positional on change.
  import type { ZoneField } from './api'
  import { namedToZone, zoneToNamed } from './model'
  import RecordListEditor from './RecordListEditor.svelte'
  import type { Field } from './tables'

  let {
    zones,
    fields,
    onchange,
  }: {
    zones: unknown[][]
    fields: ZoneField[]
    onchange: (v: unknown[][]) => void
  } = $props()

  const recFields = $derived<Field[]>(
    fields.map((f) => ({ name: f.name, type: f.type === 'int' ? 'number' : 'string', choices: f.choices })),
  )
  const named = $derived(fields.length ? zones.map((z) => zoneToNamed(z, fields)) : [])

  function handle(records: Record<string, unknown>[]) {
    onchange(records.map((r) => namedToZone(r, fields)))
  }
  function blank(): Record<string, unknown> {
    const rec: Record<string, unknown> = {}
    for (const f of fields) rec[f.name] = f.type === 'int' ? 0 : ''
    return rec
  }
</script>

<RecordListEditor records={named} fields={recFields} {blank} onchange={handle} />
