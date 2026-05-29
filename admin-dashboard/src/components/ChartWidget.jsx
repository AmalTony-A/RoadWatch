import React from 'react'
import { Pie } from 'react-chartjs-2'
import { Chart, ArcElement, Tooltip, Legend } from 'chart.js'
Chart.register(ArcElement, Tooltip, Legend)

export default function ChartWidget({ data }) {
  const labels = Object.keys(data || {})
  const values = labels.map(k => data[k])
  const chartData = { labels, datasets: [{ data: values, backgroundColor: ['#60a5fa','#f97316','#34d399','#f87171','#a78bfa'] }] }
  return (
    <div className="mx-auto max-w-xs">
      <h3 className="font-bold mb-2">Reports by Category</h3>
      <div className="h-56">
        <Pie
          data={chartData}
          options={{
            maintainAspectRatio: false,
            plugins: {
              legend: {
                position: 'top',
              },
            },
          }}
        />
      </div>
    </div>
  )
}
