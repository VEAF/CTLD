<script lang="ts">
  // The persistent answer to "is my config good to ship?".
  //
  // Previously the findings were rendered only on the Data screen, as `where: message` — a
  // technical dump on one screen out of two. Here the panel is always mounted, findings are named
  // by their human label, and clicking one takes the MM to the setting it concerns.
  import type { Finding } from './api'
  import { plural, t } from './i18n.svelte'

  let {
    findings,
    labelOf,
    ongoto,
  }: {
    findings: Finding[]
    /** Resolve a setting's display name (schema label, else derived from the key). */
    labelOf: (key: string) => string
    /** Navigate to the setting a finding concerns (family + reveal). */
    ongoto: (key: string) => void
  } = $props()

  const errors = $derived(findings.filter((f) => f.severity === 'error'))
  const warnings = $derived(findings.filter((f) => f.severity !== 'error'))
</script>

{#if !findings.length}
  <p class="clean">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round">
      <circle cx="12" cy="12" r="9" /><path d="M8 12l3 3 5-6" />
    </svg>
    {t('web.validation.ok')}
  </p>
{:else}
  <section class="panel" class:has-errors={errors.length > 0} aria-label="validation">
    {#if errors.length}
      <h3 class="err-title">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round">
          <path d="M12 3.5 21 20H3z" /><path d="M12 9.5v4.5M12 17v.01" />
        </svg>
        {plural('web.validation.problems', errors.length)}
      </h3>
      <ul>
        {#each errors as f (f.where + f.key + f.message)}
          <li>
            <button class="ghost finding" onclick={() => ongoto(f.key)}>
              <span class="what">{f.key ? labelOf(f.key) : f.where}</span>
              <span class="msg">{f.message}</span>
              {#if f.key}<code class="rawkey">{f.key}</code>{/if}
            </button>
          </li>
        {/each}
      </ul>
      <p class="blocks">{t('web.validation.blocks_inject')}</p>
    {/if}

    {#if warnings.length}
      <h3 class="warn-title">{plural('web.validation.warnings', warnings.length)}</h3>
      <ul>
        {#each warnings as f (f.where + f.key + f.message)}
          <li>
            <button class="ghost finding" onclick={() => ongoto(f.key)}>
              <span class="what">{f.key ? labelOf(f.key) : f.where}</span>
              <span class="msg">{f.message}</span>
              {#if f.key}<code class="rawkey">{f.key}</code>{/if}
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </section>
{/if}

<style>
  .clean {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    margin: 0 0 1rem;
    padding: 0.65rem 0.9rem;
    border: 1px solid var(--ok);
    background: var(--ok-soft);
    border-radius: var(--radius);
    color: var(--ok);
    font-size: var(--fs-base);
  }
  .clean svg {
    width: 18px;
    height: 18px;
    flex: none;
  }
  .panel {
    margin: 0 0 1rem;
    padding: 0.7rem 0.9rem 0.85rem;
    border: 1px solid var(--warn);
    background: var(--warn-soft);
    border-radius: var(--radius);
  }
  .panel.has-errors {
    border-color: var(--err);
    background: var(--err-soft);
  }
  h3 {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-family: var(--font-display);
    font-size: var(--fs-base);
    letter-spacing: 0.3px;
    margin: 0 0 0.5rem;
  }
  h3 svg {
    width: 17px;
    height: 17px;
  }
  .err-title {
    color: var(--err);
  }
  .warn-title {
    color: var(--warn);
    margin-top: 0.8rem;
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }
  .finding {
    width: 100%;
    text-align: left;
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0.5rem;
    padding: 0.3rem 0.4rem;
    border-color: transparent;
    font-family: var(--font-body);
    font-size: var(--fs-sm);
    color: var(--ink);
  }
  .finding:hover {
    background: rgba(255, 255, 255, 0.04);
    border-color: var(--hair);
  }
  .what {
    font-family: var(--font-display);
    letter-spacing: 0.2px;
  }
  .msg {
    color: var(--ink-dim);
  }
  .blocks {
    margin: 0.6rem 0 0;
    font-size: var(--fs-sm);
    color: var(--ink-dim);
  }
</style>
