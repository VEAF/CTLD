<script lang="ts">
  // Edit a list of strings (pilot names, loadable-vehicle lists, …). Optional datalist
  // for autocomplete (e.g. DCS type names). Owns a local copy, emits on change.
  import { t } from './i18n.svelte'

  let {
    items,
    listId,
    placeholder,
    onchange,
  }: {
    items: string[]
    listId?: string
    placeholder?: string
    onchange: (v: string[]) => void
  } = $props()

  // svelte-ignore state_referenced_locally
  let model = $state<string[]>([...(items ?? [])])

  function commit() {
    onchange([...model])
  }
  function edit(i: number, v: string) {
    model[i] = v
    commit()
  }
  function add() {
    model.push('')
    commit()
  }
  function remove(i: number) {
    model.splice(i, 1)
    commit()
  }
</script>

<div class="list">
  {#each model as item, i (i)}
    {@const removeLabel = t('web.table.remove', { what: item || t('web.table.this_entry') })}
    <div class="item">
      <input class={listId ? 'combo' : undefined} value={item} list={listId} {placeholder} onchange={(e) => edit(i, e.currentTarget.value)} />
      <button class="danger" title={removeLabel} aria-label={removeLabel} onclick={() => remove(i)}>✕</button>
    </div>
  {/each}
  <button class="add" onclick={add}>{t('web.table.add')}</button>
</div>

<style>
  .list {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }
  .item {
    display: flex;
    gap: 0.35rem;
  }
  .item input {
    flex: 1;
    min-width: 10rem;
  }
  .add {
    align-self: flex-start;
    margin-top: 0.2rem;
  }
</style>
