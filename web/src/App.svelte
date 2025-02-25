<script lang="ts">
  import { onMount } from "svelte";

  import { Chart, registerables, type ChartData } from "chart.js";
  import zoomPlugin from "chartjs-plugin-zoom"; // Import the zoom plugin
  Chart.register(...registerables, zoomPlugin); // Register the zoom plugin

  type StockData = {
    date: string;
    open_price: number;
    close_price: number;
    high_price: number;
    low_price: number;
    volume: number;
  };

  // biome-ignore lint/style/useConst: barChartElement MUST not be const to bind
  let chartElement: HTMLCanvasElement | null = $state(null);

  let data: StockData[] = $state([]);
  let chartData: ChartData | null = null;

  // biome-ignore lint/style/useConst: state variable is bound.
  let num_sims = $state(4);
  // biome-ignore lint/style/useConst: state variable is bound.
  let days = $state(30);

  let chart: Chart | null = null;

  const palette = [
    "9E579D",
    "FC85AE",
    "FFB200",
    "EB5B00",
    "D91656",
    "640D5F",
    "6C3428",
    "BA704F",
    "DFA878",
    "CEE6F3",
    "7886C7",
  ];
  // Function to generate a random color
  function getRandomColor() {
    return `#${palette[Math.floor(Math.random() * palette.length)]}`;
  }

  let baseLabelLength = 0;

  function processChartData(stockData: StockData[]) {
    const newChartData = {
      labels: stockData.map((item) => item.date),
      datasets: [
        {
          label: "IBM Closing Price",
          data: stockData.map((item) => item.close_price),
          borderColor: "rgba(54, 162, 235, 1)",
          borderWidth: 2,
          fill: false, // Remove fill for a cleaner line chart
          tension: 0.25,
          pointRadius: 0,
        },
      ],
    };
    chartData = newChartData;
    baseLabelLength = stockData.length;
  }

  // Function to generate future dates - starts after the given date
  function generateFutureDates(startDate: Date, numDays: number): string[] {
    const dates: string[] = [];
    const currentDate = new Date(startDate);

    // Increment by one day first to start from the next day
    currentDate.setDate(currentDate.getDate() + 2);

    for (let i = 0; i < numDays; i++) {
      const year = currentDate.getFullYear();
      const month = String(currentDate.getMonth() + 1).padStart(2, "0"); // Months are 0-indexed
      const day = String(currentDate.getDate()).padStart(2, "0");
      dates.push(`${year}-${month}-${day}`); // Format as YYYY-MM-DD

      // Increment the date for the next iteration
      currentDate.setDate(currentDate.getDate() + 1);
    }

    return dates;
  }

  async function fetchStream() {
    if (chart === null || chartData === null) {
      return;
    }
    chart.data.datasets = [chartData.datasets[0]];
    chart.data.labels = chart.data.labels?.slice(0, baseLabelLength);
    chart.update();

    let buffer = "";
    try {
      const response = await fetch("/simulate", {
        method: "POST",
        body: JSON.stringify({ num_simulations: num_sims, num_days: days }),
      });

      if (!response.ok) {
        throw new Error(`HTTP error: ${response.status}`);
      }

      if (!response.body) {
        throw new Error("ReadableStream not supported");
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      const lastDateStr = data[data.length - 1].date as string;
      const lastDate = new Date(lastDateStr);
      const futureDates = generateFutureDates(lastDate, days);
      const lastClosePrice = data[data.length - 1].close_price;

      // Update chart with future dates only once before processing simulations
      if (chart) {
        // Add future dates to the labels
        if (chart.data.labels) {
          chart.data.labels = [...chart.data.labels, ...futureDates];
        }

        // Extend the original dataset with nulls for the future dates
        chart.data.datasets[0].data = [
          ...chart.data.datasets[0].data,
          ...Array(futureDates.length).fill(null),
        ];

        // Update the chart immediately after adding the dates
        chart.update();
      }

      // Process the stream
      while (true) {
        const { value, done } = await reader.read();

        if (done) {
          console.log("Stream complete."); // Debugging
          break;
        }

        // Decode the chunk and add it to our buffer
        buffer += decoder.decode(value, { stream: true });

        // Process complete lines in the buffer
        let newlineIndex = buffer.indexOf("\n");
        while (newlineIndex !== -1) {
          const line = buffer.slice(0, newlineIndex);
          buffer = buffer.slice(newlineIndex + 1);

          if (line.trim()) {
            try {
              // Safely parse the line as a JavaScript array
              const simulation = new Function(`return ${line}`)();

              if (chart) {
                const newColor = getRandomColor();
                const newDataset = {
                  label: `Simulation ${chart.data.datasets.length}`,
                  data: Array(data.length).fill(null),
                  borderColor: newColor,
                  borderWidth: 2,
                  fill: false,
                  tension: 0.25,
                  pointRadius: 1,
                };
                newDataset.data[data.length - 1] = lastClosePrice;
                newDataset.data.push(...simulation);
                chart.data.datasets.push(newDataset);
                chart.update();
              }
            } catch (e) {
              console.error("Error parsing JavaScript array:", e);
            }
          }
          newlineIndex = buffer.indexOf("\n");
        }
      }
    } catch (error) {
      console.error("Error:", error);
    }
  }

  async function fetchData() {
    const respdata = await fetch("/getData");
    const json = await respdata.json();
    data = json.IBM;

    processChartData(data);
  }

  onMount(async () => {
    await fetchData();
    if (chartElement && chartData) {
      chart = new Chart(chartElement, {
        type: "line",
        data: chartData,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            zoom: {
              pan: {
                enabled: true,
                mode: "x",
              },
              zoom: {
                wheel: {
                  enabled: true,
                },
                pinch: {
                  enabled: true,
                },
                drag: {
                  enabled: true,
                  modifierKey: "shift",
                },
                mode: "x",
              },
            },
          },
          scales: {
            x: {
              title: {
                display: true,
                text: "Date",
              },
            },
            y: {
              beginAtZero: false,
              title: {
                display: true,
                text: "Closing price",
              },
            },
          },
        },
      });
    }
  });
</script>

<main>
  <div class="container mx-auto flex flex-col items-center h-screen">
    <h1 class="text-3xl font-bold">Monte Carlo Stock Simulation</h1>

    {#if data.length > 0}
      <p>Fetched {data.length} items</p>
      <div class="chart-container">
        <canvas bind:this={chartElement}></canvas>
      </div>
    {/if}

    <form>
      <label for="num_sims">Number of simulations:</label>
      <input type="number" name="num_sims" bind:value={num_sims} max="10" />
      <br />
      <label for="days"> Number of days:</label>
      <input type="number" name="days" bind:value={days} max="730" />
      <br />
      <button
        type="submit"
        onclick={async (e) => {
          e.preventDefault();
          await fetchStream();
        }}>Submit</button
      >
    </form>
  </div>
</main>
