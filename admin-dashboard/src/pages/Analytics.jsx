import React, { useEffect, useMemo, useState } from 'react'
import { Bar, Doughnut, Line } from 'react-chartjs-2'
import { Chart, CategoryScale, LinearScale, BarElement, LineElement, PointElement, ArcElement, Tooltip, Legend, Filler } from 'chart.js'
import { api } from '../lib/api'
import HeatmapMap from '../components/HeatmapMap'
import { useRealtime } from '../context/RealtimeContext'

Chart.register(CategoryScale, LinearScale, BarElement, LineElement, PointElement, ArcElement, Tooltip, Legend, Filler)

export default function Analytics() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const realtime = useRealtime()

  const load = () => {
    api.get('/api/admin/analytics')
      .then((res) => setData(res.data))
      .catch((err) => setError(err.response?.data?.message || err.message || 'Failed to load analytics'))
  }

  useEffect(() => {
    load()
  }, [])

  useEffect(() => {
    if (!realtime?.lastEvent) return
    if (['reportCreated', 'reportUpdated', 'reportDeleted', 'userLoggedIn'].includes(String(realtime.lastEvent.event || ''))
      || String(realtime.lastEvent.event || '').startsWith('report')) {
      load()
    }
  }, [realtime?.lastEvent?.timestamp])

  const categoryData = useMemo(() => ({
    labels: Object.keys(data?.reportsByCategory || {}),
    datasets: [{ data: Object.values(data?.reportsByCategory || {}), backgroundColor: ['#ef4444', '#3b82f6', '#f97316', '#10b981', '#8b5cf6'] }],
  }), [data])

  const monthlyData = useMemo(() => ({
    labels: Object.keys(data?.monthlyReports || {}).sort(),
    datasets: [{ label: 'Reports', data: Object.entries(data?.monthlyReports || {}).sort(([a], [b]) => a.localeCompare(b)).map(([, value]) => value), borderColor: '#0f172a', backgroundColor: 'rgba(15, 23, 42, 0.1)', fill: true }],
  }), [data])

  const userGrowthData = useMemo(() => ({
    labels: Object.keys(data?.userGrowth || {}).sort(),
    datasets: [{ label: 'Users', data: Object.entries(data?.userGrowth || {}).sort(([a], [b]) => a.localeCompare(b)).map(([, value]) => value), borderColor: '#06b6d4', backgroundColor: 'rgba(6, 182, 212, 0.12)', fill: true }],
  }), [data])

  const resolutionData = useMemo(() => ({
    labels: ['Resolved', 'Open'],
    datasets: [{ data: [data?.resolutionRate || 0, 100 - (data?.resolutionRate || 0)], backgroundColor: ['#22c55e', '#e2e8f0'] }],
  }), [data])

  return (
    <div className="space-y-6">
      {error && <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-rose-700 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-200">{error}</div>}
      <div className="grid gap-4 md:grid-cols-4">
        <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">Total Reports: <span className="text-2xl font-black">{data?.totalReports ?? 0}</span></div>
        <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">Users: <span className="text-2xl font-black">{data?.totalUsers ?? 0}</span></div>
        <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">Resolution Rate: <span className="text-2xl font-black">{data?.resolutionRate ?? 0}%</span></div>
        <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">Generated: <span className="block text-sm text-slate-500 dark:text-slate-400">{data?.generatedAt ? new Date(data.generatedAt).toLocaleString() : '—'}</span></div>
      </div>

      <div className="grid gap-6 xl:grid-cols-2">
        <div data-testid="analytics-chart" className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
          <h2 className="mb-4 text-xl font-bold">Reports by Category</h2>
          <Doughnut data={categoryData} />
        </div>
        <div data-testid="analytics-chart" className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
          <h2 className="mb-4 text-xl font-bold">Monthly Reports</h2>
          <Bar data={monthlyData} options={{ responsive: true }} />
        </div>
        <div data-testid="analytics-chart" className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
          <h2 className="mb-4 text-xl font-bold">Resolution Rate</h2>
          <Doughnut data={resolutionData} />
        </div>
        <div data-testid="analytics-chart" className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
          <h2 className="mb-4 text-xl font-bold">User Growth</h2>
          <Line data={userGrowthData} options={{ responsive: true }} />
        </div>
      </div>

      <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        <h2 className="mb-4 text-xl font-bold">Complaint Heatmap</h2>
        <HeatmapMap points={data?.heatmap || []} />
      </div>
    </div>
  )
}
