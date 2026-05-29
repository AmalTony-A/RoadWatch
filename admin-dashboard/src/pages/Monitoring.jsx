import React, { useEffect, useState } from 'react'
import { api } from '../lib/api'

export default function Monitoring() {
  const [info, setInfo] = useState(null)
  const [apiLatency, setApiLatency] = useState(null)
  const [error, setError] = useState('')

  const load = async () => {
    setError('')
    const start = performance.now()
    try {
      const res = await api.get('/api/admin/system-info')
      setInfo(res.data)
      setApiLatency(Math.round(performance.now() - start))
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load system info')
    }
  }

  useEffect(() => { load() }, [])

  return (
    <div className="space-y-6">
      {error && <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-rose-700 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-200">{error}</div>}
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">Uptime: <span className="text-2xl font-black">{info?.uptime_seconds || 0}s</span></div>
        <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">Memory: <span className="text-2xl font-black">{info?.memory_usage_mb || 0} MB</span></div>
        <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">CPU: <span className="text-2xl font-black">{info?.cpu_usage_ms || 0} ms</span></div>
        <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">API response: <span className="text-2xl font-black">{apiLatency ?? '—'} ms</span></div>
      </div>

      <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        <h2 className="text-xl font-bold">Database health</h2>
        <div className="mt-4 grid gap-3 md:grid-cols-3 text-sm">
          <div>Connected: {info?.database_connected ? 'Yes' : 'No'}</div>
          <div>Database: {info?.database_type || 'Unknown'}</div>
          <div>Demo mode: {info?.demo_mode ? 'On' : 'Off'}</div>
        </div>
      </div>

      <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold">Data sources</h2>
          <button onClick={load} className="rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white dark:bg-slate-200 dark:text-slate-950">Refresh</button>
        </div>
        <div className="mt-4 grid gap-3 md:grid-cols-3 text-sm">
          <div>Reports: {info?.data_sources?.reports ?? 0}</div>
          <div>Users: {info?.data_sources?.users ?? 0}</div>
          <div>Activity logs: {info?.data_sources?.activity_logs ?? 0}</div>
        </div>
      </div>
    </div>
  )
}
