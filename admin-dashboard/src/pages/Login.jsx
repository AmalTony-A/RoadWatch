import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth.jsx'

export default function Login() {
  const [email, setEmail] = useState('admin@roadwatch.local')
  const [password, setPassword] = useState('Admin@12345')
  const { login, token, authError, loading } = useAuth()
  const nav = useNavigate()
  const [localError, setLocalError] = useState('')

  useEffect(() => {
    if (token) {
      nav('/', { replace: true })
    }
  }, [token, nav])

  const submit = async (e) => {
    e.preventDefault()
    setLocalError('')
    try {
      await login(email, password)
      nav('/', { replace: true })
    } catch (err) {
      setLocalError(err.message || 'Login failed')
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50">
      <form onSubmit={submit} className="bg-white p-8 rounded shadow w-96">
        <h2 className="text-xl font-bold mb-4">RoadWatch Admin Login</h2>
        <label className="block mb-2">Email</label>
        <input data-testid="login-email" value={email} onChange={e=>setEmail(e.target.value)} className="w-full p-2 border rounded mb-3" autoComplete="username" />
        <label className="block mb-2">Password</label>
        <input data-testid="login-password" type="password" value={password} onChange={e=>setPassword(e.target.value)} className="w-full p-2 border rounded mb-4" autoComplete="current-password" />
        {(localError || authError) && (
          <div className="mb-4 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {localError || authError}
          </div>
        )}
        <button data-testid="login-submit" disabled={loading} className="w-full bg-blue-600 text-white py-2 rounded disabled:opacity-60">
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  )
}
