import React, { useEffect, useState } from 'react'
import { api } from '../lib/api'
import ConfirmDialog from '../components/ConfirmDialog'
import { TableSkeleton } from '../components/Skeletons'

export default function Users() {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [role, setRole] = useState('')
  const [page, setPage] = useState(0)
  const [pageInfo, setPageInfo] = useState({ total: 0, limit: 10 })
  const [profile, setProfile] = useState(null)
  const [deleteTarget, setDeleteTarget] = useState(null)

  const load = async () => {
    setLoading(true)
    setError('')
    try {
      const params = new URLSearchParams({ page: String(page), limit: '10' })
      if (search) params.set('q', search)
      if (role) params.set('role', role)
      const res = await api.get(`/api/admin/users?${params.toString()}`)
      setUsers(res.data.users || [])
      setPageInfo({ total: res.data.total || 0, limit: res.data.limit || 10 })
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load users')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [search, role, page])

  const updateRole = async (user, nextRole) => {
    await api.put(`/api/admin/user/${user._id}/role`, { role: nextRole })
    load()
  }

  const nextRoleFor = (currentRole) => {
    if (currentRole === 'user') return 'moderator'
    if (currentRole === 'moderator') return 'admin'
    return 'user'
  }

  const toggleBan = async (user) => {
    await api.put(`/api/admin/user/${user._id}/ban`, { banned: !user.banned })
    load()
  }

  const deleteUser = async () => {
    await api.delete(`/api/admin/user/${deleteTarget._id}`)
    setDeleteTarget(null)
    load()
  }

  const totalPages = Math.max(1, Math.ceil(pageInfo.total / pageInfo.limit))

  return (
    <div className="space-y-6">
      <div className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        <div className="grid gap-3 md:grid-cols-3">
          <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search users" className="rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700" />
          <select value={role} onChange={(e) => setRole(e.target.value)} className="rounded-xl border border-slate-200 bg-transparent px-4 py-2 dark:border-slate-700">
            <option value="">All roles</option>
            <option value="user">User</option>
            <option value="moderator">Moderator</option>
            <option value="admin">Admin</option>
          </select>
          <button onClick={load} className="rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white dark:bg-slate-200 dark:text-slate-950">Refresh</button>
        </div>
      </div>

      {error && <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-rose-700 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-200">{error}</div>}

      <div className="overflow-hidden rounded-3xl bg-white shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        {loading ? <TableSkeleton rows={6} cols={5} /> : (
          <table className="min-w-full divide-y divide-slate-200 dark:divide-slate-800">
            <thead className="bg-slate-50 dark:bg-slate-950">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Name</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Email</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Role</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Status</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
              {users.map((user) => (
                <tr data-testid="user-row" key={user._id}>
                  <td className="px-4 py-4 font-semibold">{user.name}</td>
                  <td className="px-4 py-4 text-sm text-slate-500 dark:text-slate-400">{user.email}</td>
                  <td className="px-4 py-4 text-sm">{user.role}</td>
                  <td className="px-4 py-4 text-sm">{user.banned ? 'Banned' : 'Active'}</td>
                  <td className="px-4 py-4">
                    <div className="flex flex-wrap gap-2">
                      <button data-testid="view-user" onClick={() => setProfile(user)} className="rounded-lg border border-slate-200 px-3 py-1 text-sm dark:border-slate-700">View</button>
                      <button data-testid="promote-button" onClick={() => updateRole(user, nextRoleFor(user.role))} className="rounded-lg bg-cyan-600 px-3 py-1 text-sm text-white">
                        {user.role === 'admin' ? 'Set User' : user.role === 'moderator' ? 'Promote to Admin' : 'Promote to Moderator'}
                      </button>
                      <button data-testid="ban-button" onClick={() => toggleBan(user)} className="rounded-lg bg-amber-600 px-3 py-1 text-sm text-white">{user.banned ? 'Unban' : 'Ban'}</button>
                      <button data-testid="delete-user" onClick={() => setDeleteTarget(user)} className="rounded-lg bg-rose-600 px-3 py-1 text-sm text-white">Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="flex items-center justify-between rounded-2xl bg-white px-4 py-3 shadow-sm ring-1 ring-slate-200 dark:bg-slate-900 dark:ring-slate-800">
        <p className="text-sm text-slate-500 dark:text-slate-400">Page {page + 1} of {totalPages} · {pageInfo.total} users</p>
        <div className="flex gap-2">
          <button disabled={page === 0} onClick={() => setPage((value) => Math.max(0, value - 1))} className="rounded-lg border border-slate-200 px-3 py-1 text-sm disabled:opacity-50 dark:border-slate-700">Prev</button>
          <button disabled={page + 1 >= totalPages} onClick={() => setPage((value) => value + 1)} className="rounded-lg border border-slate-200 px-3 py-1 text-sm disabled:opacity-50 dark:border-slate-700">Next</button>
        </div>
      </div>

      {profile && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-slate-950/60 p-4" onClick={() => setProfile(null)}>
          <div className="w-full max-w-xl rounded-3xl bg-white p-6 shadow-2xl dark:bg-slate-900" onClick={(e) => e.stopPropagation()}>
            <h3 className="text-2xl font-black">{profile.name}</h3>
            <div className="mt-4 grid gap-3 md:grid-cols-2 text-sm">
              <div>Email: {profile.email}</div>
              <div>Role: {profile.role}</div>
              <div>Status: {profile.banned ? 'Banned' : 'Active'}</div>
              <div>Created: {new Date(profile.createdAt || Date.now()).toLocaleString()}</div>
            </div>
            <div className="mt-6 flex justify-end">
              <button onClick={() => setProfile(null)} className="rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white dark:bg-slate-200 dark:text-slate-950">Close</button>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        title="Delete user?"
        message={`Delete ${deleteTarget?.name || 'selected user'}? This cannot be undone.`}
        confirmLabel="Delete user"
        onCancel={() => setDeleteTarget(null)}
        onConfirm={deleteUser}
      />
    </div>
  )
}
