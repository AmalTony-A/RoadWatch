import React, { useEffect, useState } from 'react'
import { Outlet, useNavigate } from 'react-router-dom'
import Sidebar from '../components/Sidebar'
import Topbar from '../components/Topbar'
import NotificationPanel from '../components/NotificationPanel'
import useTheme from '../hooks/useTheme'
import { useAuth } from '../hooks/useAuth'
import { useRealtime } from '../context/RealtimeContext'

export default function AppShell() {
  const [menuOpen, setMenuOpen] = useState(false)
  const [notificationsOpen, setNotificationsOpen] = useState(false)
  const [toast, setToast] = useState(null)
  const { darkMode, toggleTheme } = useTheme()
  const { logout } = useAuth()
  const realtime = useRealtime()
  const navigate = useNavigate()

  useEffect(() => {
    if (!realtime?.lastEvent) return
    const eventName = realtime.lastEvent.event || 'Update'
    setToast({
      id: `${eventName}-${Date.now()}`,
      title: eventName,
      time: new Date().toLocaleTimeString(),
    })
    const timer = setTimeout(() => setToast(null), 2500)
    return () => clearTimeout(timer)
  }, [realtime?.lastEvent?.timestamp])

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  return (
    <div className="min-h-screen bg-slate-100 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <div className="flex min-h-screen">
        <Sidebar open={menuOpen} onClose={() => setMenuOpen(false)} />
        <div className="flex min-h-screen flex-1 flex-col">
          <Topbar
            onMenu={() => setMenuOpen((value) => !value)}
            onToggleTheme={toggleTheme}
            darkMode={darkMode}
            onLogout={handleLogout}
            notificationCount={realtime?.unreadCount || 0}
            connected={realtime?.connected || false}
          />
          <div className="flex-1 px-4 py-6 md:px-6">
            <Outlet />
          </div>
        </div>
      </div>

      <button
        data-testid="notifications-button"
        onClick={() => setNotificationsOpen(true)}
        className="fixed bottom-6 right-6 z-30 rounded-full bg-cyan-600 px-4 py-3 text-sm font-semibold text-white shadow-lg"
      >
        Notifications {realtime?.unreadCount ? `(${realtime.unreadCount})` : ''}
      </button>

      <NotificationPanel
        open={notificationsOpen}
        notifications={realtime?.notifications || []}
        onClose={() => setNotificationsOpen(false)}
        onMarkAllRead={realtime?.markAllRead || (() => {})}
      />

      {toast && (
        <div className="fixed right-6 top-6 z-50 rounded-2xl border border-cyan-200 bg-white/95 px-4 py-3 shadow-lg dark:border-cyan-700 dark:bg-slate-900/95">
          <p className="text-sm font-semibold text-slate-900 dark:text-white">Realtime event</p>
          <p className="text-sm text-slate-600 dark:text-slate-300">{toast.title}</p>
          <p className="text-xs uppercase tracking-[0.2em] text-slate-400">{toast.time}</p>
        </div>
      )}
    </div>
  )
}
