import React from 'react'

export function CardSkeleton() {
  return <div className="h-24 animate-pulse rounded-2xl bg-slate-200 dark:bg-slate-800" />
}

export function TableSkeleton({ rows = 5, cols = 5 }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-800">
      {Array.from({ length: rows }).map((_, rowIndex) => (
        <div key={rowIndex} className="grid gap-3 border-b border-slate-200 p-4 dark:border-slate-800" style={{ gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))` }}>
          {Array.from({ length: cols }).map((__, colIndex) => (
            <div key={colIndex} className="h-4 animate-pulse rounded bg-slate-200 dark:bg-slate-800" />
          ))}
        </div>
      ))}
    </div>
  )
}
