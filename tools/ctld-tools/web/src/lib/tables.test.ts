import { describe, expect, it } from 'vitest'
import { TROOP_FIELDS } from './tables'

describe('TROOP_FIELDS', () => {
  it('types every troop count as an integer', () => {
    // `jtac` shipped as `boolean` while the data holds counts (1, 2). The editor then rendered a
    // checkbox that never matched the value, and writing it replaced the count with true/false.
    // `'integer'`, not `'number'`: a soldier/launcher count is whole by nature
    // (FIX-CTLD-TOOLS-INTEGER-FIELDS ticket 02).
    const counts = TROOP_FIELDS.filter((f) => f.name !== 'name')
    expect(counts.length).toBeGreaterThan(0)
    for (const f of counts) expect(f.type, f.name).toBe('integer')
  })

  it('covers every field a troop group can use', () => {
    // Mirrors the keys asserted on the backend side (test_web_app.py); a group field with no column
    // is invisible in the editor, which is how the JTAC groups came to look identical.
    const declared = new Set(TROOP_FIELDS.map((f) => f.name))
    for (const key of ['name', 'inf', 'mg', 'at', 'aa', 'mortar', 'jtac']) {
      expect(declared, key).toContain(key)
    }
  })
})
