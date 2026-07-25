<script lang="ts">
  // Re-migration popup (ADR 0011 point 5): shown when a loaded configUser's version differs
  // from the current CTLD default, surfacing the diffs before re-injecting. Never a silent merge.
  import type { VersionGap } from './api'

  let { gap, onclose }: { gap: VersionGap; onclose: () => void } = $props()

  function short(v: unknown): string {
    if (v === null || v === undefined) return '∅'
    if (typeof v === 'object') return Array.isArray(v) ? `[${v.length}]` : '{…}'
    return String(v)
  }
</script>

<div class="overlay" role="dialog" aria-modal="true" aria-label="version gap">
  <div class="modal">
    <h2>CTLD version changed</h2>
    <p>
      This config was authored for <b>{gap.fromVersion ?? '?'}</b>; the current CTLD default is
      <b>{gap.toVersion ?? '?'}</b>. Review the differences from the current default before re-injecting.
    </p>

    {#if gap.added.length}
      <section>
        <h3>New in the current default ({gap.added.length})</h3>
        <ul>{#each gap.added as k (k)}<li>{k}</li>{/each}</ul>
      </section>
    {/if}
    {#if gap.removed.length}
      <section>
        <h3>No longer in the default ({gap.removed.length})</h3>
        <ul>{#each gap.removed as k (k)}<li>{k}</li>{/each}</ul>
      </section>
    {/if}
    {#if gap.changed.length}
      <section>
        <h3>Differs from the current default ({gap.changed.length})</h3>
        <ul>{#each gap.changed as c (c.key)}<li><code>{c.key}</code>: {short(c.old)} → {short(c.new)}</li>{/each}</ul>
      </section>
    {/if}

    <div class="actions"><button onclick={onclose}>Review &amp; continue</button></div>
  </div>
</div>

<style>
  .overlay {
    position: fixed;
    inset: 0;
    background: rgba(28, 35, 48, 0.55);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
  }
  .modal {
    background: #fff;
    border-radius: 8px;
    padding: 1.25rem 1.5rem;
    max-width: 40rem;
    max-height: 80vh;
    overflow: auto;
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.25);
  }
  .modal h2 {
    margin-top: 0;
  }
  .modal h3 {
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: #5a6473;
    margin: 1rem 0 0.35rem;
  }
  .modal ul {
    margin: 0;
    padding-left: 1.2rem;
    font-size: 0.85rem;
  }
  .modal code {
    font-family: ui-monospace, monospace;
  }
  .actions {
    margin-top: 1.25rem;
    text-align: right;
  }
  .actions button {
    padding: 0.4rem 1rem;
    border: 1px solid #1c2330;
    background: #1c2330;
    color: #fff;
    border-radius: 4px;
    cursor: pointer;
  }
</style>
