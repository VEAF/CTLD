<script lang="ts">
  // Generic fallback editor: any structured value edited as JSON. Guarantees every Data
  // family renders *something* (the no-editing-gaps rule); bespoke editors override it.
  let { value, onchange }: { value: unknown; onchange: (v: unknown) => void } = $props()

  // svelte-ignore state_referenced_locally
  let text = $state(JSON.stringify(value, null, 2))
  let err = $state<string | null>(null)

  function commit() {
    try {
      const parsed = JSON.parse(text)
      err = null
      onchange(parsed)
    } catch (e) {
      err = `Invalid JSON: ${(e as Error).message}`
    }
  }
</script>

<textarea class="json" bind:value={text} onchange={commit} spellcheck="false"></textarea>
{#if err}<p class="err" role="alert">{err}</p>{/if}
<p class="hint">
  This table has no dedicated editor yet, so it is edited in its raw form. Keep the punctuation
  (braces, brackets, commas) exactly as it is and change only the values.
</p>

<style>
  .json {
    width: 100%;
    min-height: 18rem;
    font-family: var(--font-mono);
    font-size: var(--fs-sm);
    line-height: 1.45;
    padding: 0.6rem;
    resize: vertical;
  }
  .err {
    color: var(--err);
    font-size: var(--fs-sm);
    margin: 0.3rem 0 0;
  }
  .hint {
    color: var(--ink-faint);
    font-size: var(--fs-sm);
    margin: 0.5rem 0 0;
    max-width: 68ch;
  }
</style>
