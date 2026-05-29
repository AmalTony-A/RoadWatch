import React from 'react'
import { NavLink } from 'react-router-dom'

const linkClass = ({ isActive }) => (
  `block rounded-xl px-4 py-3 text-sm font-semibold transition ${isActive ? 'bg-white text-slate-950 shadow-sm dark:bg-slate-800 dark:text-white' : 'text-slate-200 hover:bg-white/10'}`
)

export default function Sidebar({ open, onClose }) {
  return (
    <aside className={`fixed inset-y-0 left-0 z-40 w-72 transform border-r border-white/10 bg-slate-950 px-4 py-5 text-white transition md:static md:translate-x-0 ${open ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}`}>
      <div className="flex items-center justify-between px-2 pb-5">
        <div>
          <p className="text-xs uppercase tracking-[0.3em] text-cyan-300/80">RoadWatch</p>
          <h1 className="text-2xl font-black">Admin</h1>
        </div>
        <button onClick={onClose} className="rounded-lg border border-white/10 px-3 py-1 text-xs md:hidden">Close</button>
      </div>
      <nav className="space-y-2">
        <NavLink to="/" end className={linkClass}>Overview</NavLink>
        <NavLink to="/reports" className={linkClass}>Reports</NavLink>
        <NavLink to="/users" className={linkClass}>Users</NavLink>
        <NavLink to="/analytics" className={linkClass}>Analytics</NavLink>
        <NavLink to="/monitoring" className={linkClass}>Monitoring</NavLink>
      </nav>
      <div className="mt-8 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-slate-200">
        <p className="font-semibold text-white">Live operations</p>
        <p className="mt-1 text-slate-300">Realtime reports, users, and health metrics.</p>
      </div>
    </aside>
  )
}
