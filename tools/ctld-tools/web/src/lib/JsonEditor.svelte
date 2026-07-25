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
<p class="hint">Generic editor — this structure is edited as raw JSON.</p>

<style>
  .json {
    width: 100%;
    min-height: 18rem;
    font-family: ui-monospace, monospace;
    font-size: 0.8rem;
    padding: 0.5rem;
    border: 1px solid #c3ccda;
    border-radius: 4px;
    resize: vertical;
  }
  .err {
    color: #a12020;
    font-size: 0.8rem;
    margin: 0.25rem 0 0;
  }
  .hint {
    color: #8a93a2;
    font-size: 0.75rem;
    margin-top: 0.5rem;
  }
</style>
