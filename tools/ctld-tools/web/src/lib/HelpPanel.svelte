<script lang="ts">
  // In-app help, in the user's language.
  //
  // Deliberately not a static text: the counts, the family list and the data-table inventory are all
  // read from the schema and the catalogue currently open. That means it cannot go stale — add a
  // setting or a family to the schema and the help describes it without anyone editing prose. It also
  // doubles as an inventory: "what is actually in the config I have open?"
  import type { SchemaInfo, Snapshot } from './api'
  import { familyDescription, familyLabel } from './families'
  import { t } from './i18n.svelte'
  import { settingLabel } from './labels'
  import type { Family } from './model'

  let {
    families,
    schema,
    snapshot,
    onclose,
  }: {
    families: Family[]
    schema: SchemaInfo | null
    snapshot: Snapshot | null
    onclose: () => void
  } = $props()

  const settingCount = $derived(families.reduce((n, f) => n + f.standard.length + f.advanced.length, 0))

  /** Every structured table in the open catalogue, with how much is in it. */
  const tables = $derived(
    families.flatMap((f) =>
      f.data.map((key) => {
        const value = snapshot?.values[key]
        const isList = Array.isArray(value)
        const count = isList ? value.length : value && typeof value === 'object' ? Object.keys(value).length : 0
        return {
          key,
          name: settingLabel(key, schema?.keys[key]?.label),
          family: familyLabel(f.key, schema?.familyMeta),
          count: isList ? t('web.help.data_entries', { n: count }) : t('web.help.data_sections', { n: count }),
        }
      }),
    ),
  )

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose()
  }
</script>

<svelte:window {onkeydown} />

<div class="overlay" role="dialog" aria-modal="true" aria-labelledby="help-title">
  <div class="modal">
    <header>
      <h2 id="help-title">{t('web.help.title')}</h2>
      <button class="ghost close" aria-label={t('web.help.close')} onclick={onclose}>✕</button>
    </header>

    <p class="intro">{t('web.help.intro')}</p>

    <section>
      <h3>{t('web.help.workflow_title')}</h3>
      <ol class="steps">
        <li>{t('web.help.workflow_load')}</li>
        <li>{t('web.help.workflow_adjust')}</li>
        <li>{t('web.help.workflow_inject')}</li>
      </ol>
    </section>

    <!-- Counts and the family list only appear once a catalogue is loaded. The help is reachable
         from the moment the app paints, i.e. possibly before the boot fetch has landed, and
         "0 settings across 0 families" would be a lie rather than a loading state. -->
    {#if families.length}
      <section>
        <h3>{t('web.help.families_title')}</h3>
        <p>{t('web.help.families_body', { settings: settingCount, families: families.length })}</p>
        <!-- Straight from the schema's `families:` section, so it stays in step with the nav. -->
        <dl class="families">
          {#each families as f (f.key)}
            <dt>{familyLabel(f.key, schema?.familyMeta)}</dt>
            <dd>{familyDescription(f.key, schema?.familyMeta) ?? ''}</dd>
          {/each}
        </dl>
      </section>
    {/if}

    <section>
      <h3>{t('web.help.landmarks_title')}</h3>
      <ul class="landmarks">
        <li>{t('web.help.landmark_name')}</li>
        <li>{t('web.help.landmark_units')}</li>
        <li>{t('web.help.landmark_changed')}</li>
        <li>{t('web.help.landmark_reset')}</li>
        <li>{t('web.help.landmark_advanced')}</li>
        <li>{t('web.help.landmark_search')}</li>
        <li>{t('web.help.landmark_lang')}</li>
      </ul>
    </section>

    {#if tables.length}
      <section>
        <h3>{t('web.help.data_title')}</h3>
        <p>{t('web.help.data_body')}</p>
        <table class="inventory">
          <tbody>
            {#each tables as tbl (tbl.key)}
              <tr>
                <td>{tbl.name} <code class="rawkey">{tbl.key}</code></td>
                <td class="fam">{tbl.family}</td>
                <td class="count">{tbl.count}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </section>
    {/if}

    <section>
      <h3>{t('web.help.validation_title')}</h3>
      <p>{t('web.help.validation_body')}</p>
    </section>

    <section>
      <h3>{t('web.help.saving_title')}</h3>
      <p>{t('web.help.saving_body')}</p>
    </section>

    <section class="rule">
      <h3>{t('web.help.snapshot_title')}</h3>
      <p>{t('web.help.snapshot_body')}</p>
    </section>

    <div class="actions"><button class="primary" onclick={onclose}>{t('web.help.close')}</button></div>
  </div>
</div>

<style>
  .overlay {
    position: fixed;
    inset: 0;
    background: rgba(8, 12, 14, 0.78);
    display: flex;
    align-items: flex-start;
    justify-content: center;
    z-index: 20;
    padding: 2.5rem 1rem;
    overflow: auto;
  }
  .modal {
    background: var(--panel);
    border: 1px solid var(--hair);
    border-top: 2px solid var(--accent);
    border-radius: var(--radius);
    padding: 1.25rem 1.6rem 1.5rem;
    max-width: 54rem;
    width: 100%;
    box-shadow: 0 14px 44px rgba(0, 0, 0, 0.5);
  }
  header {
    display: flex;
    align-items: baseline;
    gap: 1rem;
    margin-bottom: 0.6rem;
  }
  h2 {
    font-family: var(--font-display);
    font-size: var(--fs-lg);
    letter-spacing: 0.4px;
    margin: 0;
  }
  .close {
    margin-left: auto;
    border-color: transparent;
    color: var(--ink-faint);
  }
  h3 {
    font-family: var(--font-display);
    font-size: var(--fs-sm);
    letter-spacing: 1px;
    text-transform: uppercase;
    color: var(--accent);
    margin: 1.4rem 0 0.5rem;
    display: flex;
    align-items: center;
    gap: 0.7rem;
  }
  h3::after {
    content: '';
    flex: 1;
    height: 1px;
    background: linear-gradient(90deg, var(--hair), transparent);
  }
  p,
  li {
    color: var(--ink-dim);
    max-width: 74ch;
  }
  .intro {
    margin: 0;
    color: var(--ink);
  }
  .steps,
  .landmarks {
    margin: 0;
    padding-left: 1.3rem;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }
  /* Family list: two columns so sixteen entries stay scannable. */
  .families {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 0.35rem 1rem;
    margin: 0.7rem 0 0;
    font-size: var(--fs-sm);
  }
  .families dt {
    font-family: var(--font-display);
    color: var(--ink);
    letter-spacing: 0.3px;
  }
  .families dd {
    margin: 0;
    color: var(--ink-dim);
  }
  .inventory {
    width: 100%;
    border-collapse: collapse;
    font-size: var(--fs-sm);
    margin-top: 0.6rem;
  }
  .inventory td {
    padding: 0.28rem 0.5rem 0.28rem 0;
    border-bottom: 1px solid var(--hair-soft);
    color: var(--ink);
  }
  .inventory tr:last-child td {
    border-bottom: none;
  }
  .inventory .fam,
  .inventory .count {
    color: var(--ink-dim);
    white-space: nowrap;
  }
  .inventory .count {
    text-align: right;
    font-family: var(--font-mono);
    font-variant-numeric: tabular-nums;
  }
  /* The complete-snapshot rule is the one thing that bites people; give it a frame. */
  .rule {
    margin-top: 1.4rem;
    padding: 0.2rem 0.9rem 0.8rem;
    border: 1px solid var(--warn);
    background: var(--warn-soft);
    border-radius: var(--radius);
  }
  .rule h3 {
    color: var(--warn);
    margin-top: 0.9rem;
  }
  .actions {
    margin-top: 1.5rem;
    text-align: right;
  }
</style>
