import React, { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../lib/api'
import { useRealtime } from '../context/RealtimeContext'
import { CardSkeleton } from '../components/Skeletons'
import MapView from '../components/MapView'

export default function Dashboard() {
  const [stats, setStats] = useState(null)
  const [reports, setReports] = useState([])
  const [activities, setActivities] = useState([])
  const [systemInfo, setSystemInfo] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const realtime = useRealtime()

  const load = async () => {
    setLoading(true)
    setError('')
    try {
      const [statsRes, reportsRes, activityRes, systemRes] = await Promise.all([
        api.get('/api/admin/dashboard-stats'),
        api.get('/api/admin/reports?limit=6'),
        api.get('/api/admin/activity-log?limit=6'),
        api.get('/api/admin/system-info'),
      ])
      setStats(statsRes.data)
      setReports(reportsRes.data.reports || [])
      setActivities(activityRes.data.activities || [])
      setSystemInfo(systemRes.data)
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load dashboard')
    } finally {
      setLoading(false)
    }
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

  const statCards = useMemo(() => ([
    { label: 'Total Reports', value: stats?.totalReports ?? 0 },
    { label: 'Pending', value: stats?.pendingReports ?? 0 },
    { label: 'Resolved', value: stats?.resolvedReports ?? 0 },
    { label: 'Users', value: stats?.users?.total ?? 0 },
  ]), [stats])

  return (
    <div className="space-y-6">
      <div data-testid="dashboard-stats" className="grid gap-4 md:grid-cols-4">
        {loading ? Array.from({ length: 4 }).map((_, index) => <CardSkeleton key={index} />) : statCards.map((card) => (
          <div key={card.label} className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
            <p className="text-sm text-slate-500 dark:text-slate-400">{card.label}</p>
            <p className="mt-2 text-3xl font-black">{card.value}</p>
          </div>
        ))}
      </div>

      {error && <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-rose-700 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-200">{error}</div>}

      <div className="grid gap-6 xl:grid-cols-[1.6fr_1fr]">
        <section className="space-y-6">
          <div data-testid="activity-feed" className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
            <div className="mb-4 flex items-center justify-between gap-3">
              <div>
                <h2 className="text-xl font-bold">Recent Reports</h2>
                <p className="text-sm text-slate-500 dark:text-slate-400">Latest complaints and moderation activity</p>
              </div>
              <Link to="/reports" className="rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white dark:bg-slate-200 dark:text-slate-950">Open Reports</Link>
            </div>
            <div className="space-y-3">
              {reports.map((report) => (
                <div key={report.id || report._id} className="flex flex-col gap-2 rounded-2xl border border-slate-200 p-4 dark:border-slate-800 md:flex-row md:items-center md:justify-between">
                  <div>
                    <p className="font-semibold">{report.title}</p>
                    <p className="text-sm text-slate-500 dark:text-slate-400">{report.description}</p>
                  </div>
                  <div className="text-sm text-slate-500 dark:text-slate-400">{report.status} · {report.recommendedDepartment}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
            <div className="mb-4 flex items-center justify-between">
              <div>
                <h2 className="text-xl font-bold">Live Map</h2>
                <p className="text-sm text-slate-500 dark:text-slate-400">Complaint locations and status markers</p>
              </div>
            </div>
            <MapView reports={reports} />
          </div>
        </section>

        <aside className="space-y-6">
          <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
            <h2 className="text-xl font-bold">Live Activity</h2>
            <div className="mt-4 space-y-3">
              {activities.map((activity, index) => (
                <div key={index} className="rounded-2xl bg-slate-50 p-3 text-sm dark:bg-slate-800/60">
                  <p className="font-semibold">{activity.description || activity.action}</p>
                  <p className="text-slate-500 dark:text-slate-400">{new Date(activity.timestamp).toLocaleString()}</p>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
            <h2 className="text-xl font-bold">System Health</h2>
            <div className="mt-4 space-y-3 text-sm">
              <div className="flex justify-between"><span>Uptime</span><span>{systemInfo?.uptime_seconds || 0}s</span></div>
              <div className="flex justify-between"><span>Memory</span><span>{systemInfo?.memory_usage_mb || 0} MB</span></div>
              <div className="flex justify-between"><span>CPU</span><span>{systemInfo?.cpu_usage_ms || 0} ms</span></div>
              <div className="flex justify-between"><span>Database</span><span>{systemInfo?.database_connected ? 'Healthy' : 'Offline'}</span></div>
            </div>
          </div>
        </aside>
      </div>
    </div>
  )
}
