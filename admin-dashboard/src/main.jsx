import React, { Suspense, lazy } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import './styles.css'
import 'leaflet/dist/leaflet.css'
import AppShell from './layout/AppShell'
import { AuthProvider, useAuth } from './hooks/useAuth'
import { RealtimeProvider } from './context/RealtimeContext'

const Login = lazy(() => import('./pages/Login'))
const Dashboard = lazy(() => import('./pages/Dashboard'))
const Reports = lazy(() => import('./pages/Reports'))
const Users = lazy(() => import('./pages/Users'))
const Analytics = lazy(() => import('./pages/Analytics'))
const Monitoring = lazy(() => import('./pages/Monitoring'))
const NotFound = lazy(() => import('./pages/NotFound'))

function PrivateRoute({ children }) {
  const { token } = useAuth()
  return token ? children : <Navigate to="/login" replace />
}

function App() {
  return (
    <AuthProvider>
      <RealtimeProvider>
      <BrowserRouter>
        <Suspense fallback={<div className="p-6 text-sm text-slate-500 dark:text-slate-400">Loading...</div>}>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/" element={<PrivateRoute><AppShell /></PrivateRoute>}>
              <Route index element={<Dashboard />} />
              <Route path="reports" element={<Reports />} />
              <Route path="users" element={<Users />} />
              <Route path="analytics" element={<Analytics />} />
              <Route path="monitoring" element={<Monitoring />} />
              <Route path="*" element={<NotFound />} />
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Suspense>
      </BrowserRouter>
      </RealtimeProvider>
    </AuthProvider>
  )
}

createRoot(document.getElementById('root')).render(<App />)
