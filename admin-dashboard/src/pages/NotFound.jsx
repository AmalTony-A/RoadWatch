import React from 'react'
import { Link } from 'react-router-dom'

export default function NotFound() {
  return (
    <div className="mx-auto flex min-h-[60vh] max-w-2xl flex-col items-center justify-center text-center">
      <h1 className="text-4xl font-black">Page not found</h1>
      <p className="mt-3 text-slate-500 dark:text-slate-400">The page you requested does not exist.</p>
      <Link to="/" className="mt-6 rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white dark:bg-slate-200 dark:text-slate-950">Back to dashboard</Link>
    </div>
  )
}
