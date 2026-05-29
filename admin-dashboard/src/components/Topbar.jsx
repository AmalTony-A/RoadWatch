import React from 'react'

export default function Topbar({ onMenu, onToggleTheme, darkMode, onLogout, notificationCount, connected }) {
  return (
    <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/90 px-4 py-4 backdrop-blur dark:border-slate-800 dark:bg-slate-950/90">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <button onClick={onMenu} className="rounded-xl border border-slate-200 px-3 py-2 text-sm font-semibold dark:border-slate-700 md:hidden">Menu</button>
          <div>
            <p className="text-xs uppercase tracking-[0.25em] text-slate-500 dark:text-slate-400">RoadWatch Admin Dashboard</p>
            <div className="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-300">
                <span data-testid="realtime-status-dot" className={`h-2.5 w-2.5 rounded-full ${connected ? 'bg-emerald-500' : 'bg-rose-500'}`} />
                <span data-testid="realtime-status">{connected ? 'Realtime connected' : 'Realtime offline'}</span>
              </div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={onToggleTheme} className="rounded-xl border border-slate-200 px-3 py-2 text-sm font-semibold dark:border-slate-700">
            {darkMode ? 'Light mode' : 'Dark mode'}
          </button>
          <div data-testid="notifications-button" className="rounded-xl border border-slate-200 px-3 py-2 text-sm font-semibold dark:border-slate-700">
            Notifications {notificationCount ? `(${notificationCount})` : ''}
          </div>
          <button onClick={onLogout} className="rounded-xl bg-slate-950 px-3 py-2 text-sm font-semibold text-white dark:bg-slate-200 dark:text-slate-950">Logout</button>
        </div>
      </div>
    </header>
  )
}
