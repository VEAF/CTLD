<script lang="ts">
  // Re-migration dialog (ADR 0011 point 5): shown when a loaded config's version differs from the
  // current CTLD default. Nothing is ever merged silently — so the dialog's job is to say that
  // plainly, then let the MM see what changed without drowning them in three key lists.
  import type { VersionGap } from './api'
  import { plural, t } from './i18n.svelte'
  import { humanize } from './labels'

  let { gap, onclose }: { gap: VersionGap; onclose: () => void } = $props()

  function short(v: unknown): string {
    if (v === null || v === undefined) return '—'
    if (typeof v === 'object') return Array.isArray(v) ? `[${v.length}]` : '{…}'
    return String(v)
  }
</script>

<div class="overlay" role="dialog" aria-modal="true" aria-labelledby="gap-title">
  <div class="modal">
    <h2 id="gap-title">{t('web.gap.title')}</h2>
    <p class="body">
      {t('web.gap.body', { from_version: gap.fromVersion ?? '?', to_version: gap.toVersion ?? '?' })}
    </p>

    {#if gap.added.length}
      <details>
        <summary>{plural('web.gap.added', gap.added.length)}</summary>
        <ul>
          {#each gap.added as k (k)}
            <li>{humanize(k)} <code class="rawkey">{k}</code></li>
          {/each}
        </ul>
      </details>
    {/if}

    {#if gap.removed.length}
      <details>
        <summary>{plural('web.gap.removed', gap.removed.length)}</summary>
        <ul>
          {#each gap.removed as k (k)}
            <li>{humanize(k)} <code class="rawkey">{k}</code></li>
          {/each}
        </ul>
      </details>
    {/if}

    {#if gap.changed.length}
      <details>
        <summary>{plural('web.gap.changed', gap.changed.length)}</summary>
        <ul>
          {#each gap.changed as c (c.key)}
            <li>
              {humanize(c.key)} <code class="rawkey">{c.key}</code>
              <span class="diff">{short(c.old)} → {short(c.new)}</span>
            </li>
          {/each}
        </ul>
      </details>
    {/if}

    <div class="actions"><button class="primary" onclick={onclose}>{t('web.gap.close')}</button></div>
  </div>
</div>

<style>
  .overlay {
    position: fixed;
    inset: 0;
    background: rgba(8, 12, 14, 0.72);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
    padding: 1rem;
  }
  .modal {
    background: var(--panel);
    border: 1px solid var(--hair);
    border-top: 2px solid var(--accent);
    border-radius: var(--radius);
    padding: 1.25rem 1.5rem;
    max-width: 42rem;
    max-height: 80vh;
    overflow: auto;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);
  }
  h2 {
    font-family: var(--font-display);
    font-size: var(--fs-lg);
    letter-spacing: 0.4px;
    margin: 0 0 0.5rem;
  }
  .body {
    margin: 0 0 1rem;
    color: var(--ink-dim);
    max-width: 62ch;
  }
  details {
    border-top: 1px solid var(--hair-soft);
    padding: 0.5rem 0;
  }
  summary {
    cursor: pointer;
    font-family: var(--font-display);
    font-size: var(--fs-base);
    letter-spacing: 0.3px;
  }
  ul {
    margin: 0.5rem 0 0;
    padding-left: 1.1rem;
    font-size: var(--fs-sm);
    color: var(--ink-dim);
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
  }
  .diff {
    font-family: var(--font-mono);
    font-size: var(--fs-xs);
    color: var(--ink-faint);
  }
  .actions {
    margin-top: 1.25rem;
    text-align: right;
  }
</style>
