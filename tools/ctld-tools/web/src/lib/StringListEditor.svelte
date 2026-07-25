<script lang="ts">
  // Edit a list of strings (pilot names, loadable-vehicle lists, …). Optional datalist
  // for autocomplete (e.g. DCS type names). Owns a local copy, emits on change.
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
    <div class="item">
      <input value={item} list={listId} {placeholder} onchange={(e) => edit(i, e.currentTarget.value)} />
      <button class="rm" title="remove" onclick={() => remove(i)}>✕</button>
    </div>
  {/each}
  <button class="add" onclick={add}>+ add</button>
</div>

<style>
  .list {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  .item {
    display: flex;
    gap: 0.35rem;
  }
  .item input {
    flex: 1;
    padding: 0.25rem 0.4rem;
    border: 1px solid #c3ccda;
    border-radius: 4px;
    font-size: 0.85rem;
  }
  .rm {
    color: #a12020;
    border-color: #e0c3c3;
  }
  .add {
    align-self: flex-start;
  }
</style>
