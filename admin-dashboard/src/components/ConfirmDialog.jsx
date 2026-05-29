import React from 'react'

export default function ConfirmDialog({ open, title, message, confirmLabel = 'Delete', onConfirm, onCancel, danger = true }) {
  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 px-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl dark:bg-slate-900">
        <h3 className="text-lg font-bold text-slate-900 dark:text-white">{title}</h3>
        <p className="mt-2 text-sm text-slate-600 dark:text-slate-300">{message}</p>
        <div className="mt-6 flex justify-end gap-3">
          <button onClick={onCancel} className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 dark:border-slate-700 dark:text-slate-200">Cancel</button>
          <button onClick={onConfirm} className={`rounded-xl px-4 py-2 text-sm font-semibold text-white ${danger ? 'bg-rose-600' : 'bg-slate-900 dark:bg-slate-700'}`}>
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
