import React, { useEffect, useMemo, useState } from 'react'
import { api } from '../lib/api'
import StatusBadge from '../components/StatusBadge'
import ConfirmDialog from '../components/ConfirmDialog'
import ImageModal from '../components/ImageModal'
import { TableSkeleton } from '../components/Skeletons'
import { useRealtime } from '../context/RealtimeContext'

const defaultForm = {
  title: '',
  description: '',
  category: 'Pothole',
  status: 'Pending',
  recommendedDepartment: '',
  address: '',
}

export default function Reports() {
  const [reports, setReports] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState('')
  const [status, setStatus] = useState('')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [sort, setSort] = useState('newest')
  const [selectedReport, setSelectedReport] = useState(null)
  const [editingReport, setEditingReport] = useState(null)
  const [imagePreview, setImagePreview] = useState([])
  const [deleteTarget, setDeleteTarget] = useState(null)
  const [form, setForm] = useState(defaultForm)
  const realtime = useRealtime()

  const query = useMemo(() => ({
    q: search,
    category,
    status,
    from,
    to,
    sort,
    limit: 100,
  }), [search, category, status, from, to, sort])

  const loadReports = async () => {
    setLoading(true)
    setError('')
    try {
      const params = new URLSearchParams()
      Object.entries(query).forEach(([key, value]) => {
        if (value) params.set(key, value)
      })
      const res = await api.get(`/api/admin/reports?${params.toString()}`)
      setReports(res.data.reports || [])
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load reports')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { loadReports() }, [query.q, query.category, query.status, query.from, query.to, query.sort])

  useEffect(() => {
    if (!realtime?.lastEvent) return
    if (String(realtime.lastEvent.event || '').startsWith('report')) {
      loadReports()
    }
  }, [realtime?.lastEvent?.timestamp])

  const openEdit = (report) => {
    setEditingReport(report)
    setForm({
      title: report.title || '',
      description: report.description || '',
      category: report.category || 'Pothole',
      status: report.status || 'Pending',
      recommendedDepartment: report.recommendedDepartment || '',
      address: report.address || '',
    })
  }

  const saveReport = async () => {
    await api.put(`/api/admin/report/${editingReport.id || editingReport._id}`, form)
    setEditingReport(null)
    await loadReports()
  }

  const quickUpdate = async (report, updates) => {
    await api.put(`/api/admin/report/${report.id || report._id}`, updates)
    await loadReports()
  }

  const deleteReport = async () => {
    await api.delete(`/api/admin/report/${deleteTarget.id || deleteTarget._id}`)
    setDeleteTarget(null)
    await loadReports()
  }

  return (
    <div className="space-y-6">
      <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        <div className="grid gap-3 md:grid-cols-6">
          <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search by title" className="rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700" />
          <select value={category} onChange={(e) => setCategory(e.target.value)} className="rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700">
            <option value="">All categories</option>
            <option value="Pothole">Pothole</option>
            <option value="Waterlogging">Waterlogging</option>
            <option value="Traffic issue">Traffic</option>
            <option value="Street light issue">Street light</option>
            <option value="Damaged road">Damaged road</option>
            <option value="Other">Other</option>
          </select>
          <select value={status} onChange={(e) => setStatus(e.target.value)} className="rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700">
            <option value="">All status</option>
            <option value="Pending">Pending</option>
            <option value="In Progress">In Progress</option>
            <option value="Resolved">Resolved</option>
          </select>
          <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} className="rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700" />
          <input type="date" value={to} onChange={(e) => setTo(e.target.value)} className="rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700" />
          <select value={sort} onChange={(e) => setSort(e.target.value)} className="rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700">
            <option value="newest">Newest</option>
            <option value="oldest">Oldest</option>
          </select>
        </div>
      </div>

      {error && <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-rose-700 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-200">{error}</div>}

      <div className="overflow-hidden rounded-3xl bg-white shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        {loading ? <TableSkeleton rows={6} cols={6} /> : (
          <table className="min-w-full divide-y divide-slate-200 dark:divide-slate-800">
            <thead className="bg-slate-50 dark:bg-slate-950">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Report</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Status</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Department</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Images</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Created</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
              {reports.map((report) => {
                const images = report.images?.length ? report.images : report.image_ref ? [report.image_ref] : []
                return (
                  <tr data-testid="report-row" key={report.id || report._id} className="align-top">
                    <td className="px-4 py-4">
                      <p className="font-semibold">{report.title}</p>
                      <p className="mt-1 text-sm text-slate-500 dark:text-slate-400 line-clamp-2">{report.description}</p>
                    </td>
                    <td className="px-4 py-4"><StatusBadge value={report.status} /></td>
                    <td className="px-4 py-4 text-sm">{report.recommendedDepartment || 'Unassigned'}</td>
                    <td className="px-4 py-4">
                      <div className="flex gap-2">
                        {images.slice(0, 3).map((src, index) => (
                          <button key={`${src}-${index}`} onClick={() => setImagePreview(images)} className="overflow-hidden rounded-xl border border-slate-200 dark:border-slate-700">
                            <img src={src} alt="Complaint" className="h-12 w-12 object-cover" />
                          </button>
                        ))}
                        {!images.length && <span className="text-sm text-slate-400">No image</span>}
                      </div>
                    </td>
                    <td className="px-4 py-4 text-sm text-slate-500 dark:text-slate-400">{new Date(report.createdAt || report.timestamp || Date.now()).toLocaleString()}</td>
                    <td className="px-4 py-4">
                      <div className="flex flex-wrap gap-2">
                        <button data-testid="report-view" onClick={() => setSelectedReport(report)} className="rounded-lg border border-slate-200 px-3 py-1 text-sm dark:border-slate-700">View</button>
                        <button data-testid="report-update" onClick={() => openEdit(report)} className="rounded-lg border border-slate-200 px-3 py-1 text-sm dark:border-slate-700">Edit</button>
                        <button data-testid="report-update" onClick={() => quickUpdate(report, { status: 'Resolved' })} className="rounded-lg bg-emerald-600 px-3 py-1 text-sm text-white">Resolve</button>
                        <button onClick={() => openEdit({ ...report, status: report.status || 'Pending' })} className="rounded-lg bg-sky-600 px-3 py-1 text-sm text-white">Assign department</button>
                        <button data-testid="report-delete" onClick={() => setDeleteTarget(report)} className="rounded-lg bg-rose-600 px-3 py-1 text-sm text-white">Delete</button>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        title="Delete report?"
        message={`This will permanently delete ${deleteTarget?.title || 'the selected report'}.`}
        confirmLabel="Delete report"
        onCancel={() => setDeleteTarget(null)}
        onConfirm={deleteReport}
      />

      <ImageModal open={Boolean(imagePreview.length)} images={imagePreview} onClose={() => setImagePreview([])} />

      {selectedReport && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-slate-950/60 p-4" onClick={() => setSelectedReport(null)}>
          <div className="w-full max-w-2xl rounded-3xl bg-white p-6 shadow-2xl dark:bg-slate-900" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start justify-between gap-4">
              <div>
                <h3 className="text-2xl font-black">{selectedReport.title}</h3>
                <p className="mt-2 text-sm text-slate-500 dark:text-slate-400">{selectedReport.description}</p>
              </div>
              <button onClick={() => setSelectedReport(null)} className="rounded-xl border border-slate-200 px-3 py-1 text-sm dark:border-slate-700">Close</button>
            </div>
            <div className="mt-4 grid gap-3 md:grid-cols-2 text-sm">
              <div>Status: <StatusBadge value={selectedReport.status} /></div>
              <div>Department: {selectedReport.recommendedDepartment || 'Unassigned'}</div>
              <div>Category: {selectedReport.category}</div>
              <div>Created: {new Date(selectedReport.createdAt || Date.now()).toLocaleString()}</div>
            </div>
          </div>
        </div>
      )}

      {editingReport && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-slate-950/60 p-4" onClick={() => setEditingReport(null)}>
          <div className="w-full max-w-2xl rounded-3xl bg-white p-6 shadow-2xl dark:bg-slate-900" onClick={(e) => e.stopPropagation()}>
            <h3 className="text-2xl font-black">Edit report</h3>
            <div className="mt-4 grid gap-4 md:grid-cols-2">
              {['title', 'description', 'address'].map((key) => (
                <label key={key} className="space-y-2 md:col-span-2">
                  <span className="text-sm font-semibold capitalize">{key}</span>
                  <input value={form[key]} onChange={(e) => setForm((prev) => ({ ...prev, [key]: e.target.value }))} className="w-full rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700" />
                </label>
              ))}
              <label className="space-y-2">
                <span className="text-sm font-semibold">Category</span>
                <select value={form.category} onChange={(e) => setForm((prev) => ({ ...prev, category: e.target.value }))} className="w-full rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700">
                  <option value="Pothole">Pothole</option>
                  <option value="Waterlogging">Waterlogging</option>
                  <option value="Traffic issue">Traffic</option>
                  <option value="Street light issue">Street light</option>
                  <option value="Damaged road">Damaged road</option>
                  <option value="Other">Other</option>
                </select>
              </label>
              <label className="space-y-2">
                <span className="text-sm font-semibold">Status</span>
                <select value={form.status} onChange={(e) => setForm((prev) => ({ ...prev, status: e.target.value }))} className="w-full rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700">
                  <option value="Pending">Pending</option>
                  <option value="In Progress">In Progress</option>
                  <option value="Resolved">Resolved</option>
                </select>
              </label>
              <label className="space-y-2 md:col-span-2">
                <span className="text-sm font-semibold">Department</span>
                <input value={form.recommendedDepartment} onChange={(e) => setForm((prev) => ({ ...prev, recommendedDepartment: e.target.value }))} className="w-full rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700" />
              </label>
            </div>
            <div className="mt-6 flex justify-end gap-3">
              <button onClick={() => setEditingReport(null)} className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold dark:border-slate-700">Cancel</button>
              <button onClick={saveReport} className="rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white dark:bg-slate-200 dark:text-slate-950">Save changes</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
