import React from 'react'

const styles = {
  Pending: 'bg-amber-100 text-amber-800 dark:bg-amber-500/20 dark:text-amber-200',
  'In Progress': 'bg-sky-100 text-sky-800 dark:bg-sky-500/20 dark:text-sky-200',
  Resolved: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-500/20 dark:text-emerald-200',
  default: 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-200',
}

export default function StatusBadge({ value }) {
  const className = styles[value] || styles.default
  return <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${className}`}>{value}</span>
}
