<script lang="ts">
  import { onMount } from "svelte";

  let data = $state([]);

  async function fetchData() {
    const respdata = await fetch("http://localhost:3006/test");
    const json = await respdata.json();
    console.log(json);
    data = json.IBM;

    const respdata2 = await fetch("http://localhost:3006/request", {
      method: "POST",
      body: JSON.stringify({ num_simulations: 10000 }),
    });

    const json2 = await respdata2.text();
    console.log(json2);
  }

  onMount(fetchData);
</script>

<main>
  <div
    class="container mx-auto flex flex-col justify-center items-center h-screen"
  >
    <h1 class="text-3xl font-bold">Monte Carlo Stock Simulation</h1>

    {#if data.length > 0}
      <p>
        Fetched {data.length} items
      </p>
    {/if}
  </div>
</main>

<style>
</style>
