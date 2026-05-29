import React from 'react'

export default function NotificationPanel({ open, notifications = [], onClose, onMarkAllRead }) {
  if (!open) return null

  return (
    <div className="fixed inset-y-0 right-0 z-40 w-full max-w-md border-l border-slate-200 bg-white shadow-2xl dark:border-slate-800 dark:bg-slate-950">
      <div className="flex items-center justify-between border-b border-slate-200 px-4 py-4 dark:border-slate-800">
        <div>
          <h2 className="text-lg font-bold text-slate-900 dark:text-white">Notifications</h2>
          <p className="text-sm text-slate-500 dark:text-slate-400">Live activity from the backend</p>
        </div>
        <button onClick={onClose} className="rounded-lg border border-slate-200 px-3 py-1 text-sm dark:border-slate-700">Close</button>
      </div>
      <div className="flex items-center justify-between px-4 py-3">
        <button onClick={onMarkAllRead} className="rounded-xl bg-cyan-600 px-3 py-2 text-sm font-semibold text-white">Mark all read</button>
      </div>
      <div className="max-h-[calc(100vh-140px)] overflow-y-auto px-4 pb-4 space-y-3">
        {notifications.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-slate-300 p-6 text-sm text-slate-500 dark:border-slate-700">No live notifications yet.</div>
        ) : notifications.map((item) => (
          <div key={item.id} className={`rounded-2xl border p-4 ${item.read ? 'border-slate-200 bg-slate-50 dark:border-slate-800 dark:bg-slate-900' : 'border-cyan-200 bg-cyan-50/80 dark:border-cyan-700/60 dark:bg-cyan-950/30'}`}>
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-semibold text-slate-900 dark:text-white">{item.title}</p>
                <p className="mt-1 text-sm text-slate-600 dark:text-slate-300">{item.description}</p>
              </div>
              {!item.read && <span className="rounded-full bg-cyan-600 px-2 py-1 text-xs font-semibold text-white">New</span>}
            </div>
            <p className="mt-2 text-xs uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400">{new Date(item.timestamp).toLocaleString()}</p>
          </div>
        ))}
      </div>
    </div>
  )
}
