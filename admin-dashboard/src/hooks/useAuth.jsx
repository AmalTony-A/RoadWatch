import React, { createContext, useContext, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { api, API_BASE, configureApi } from '../lib/api'

const AuthContext = createContext(null)

const TOKEN_KEY = 'token'
const CSRF_KEY = 'csrfToken'

function readToken() {
  if (typeof window === 'undefined') return ''
  return window.localStorage.getItem(TOKEN_KEY) || window.localStorage.getItem('rw_token') || ''
}

function storeAuth(token, csrfToken) {
  if (typeof window === 'undefined') return
  if (token) {
    window.localStorage.setItem(TOKEN_KEY, token)
    window.localStorage.setItem('rw_token', token)
  }
  if (csrfToken) {
    window.localStorage.setItem(CSRF_KEY, csrfToken)
  }
}

function clearAuth() {
  if (typeof window === 'undefined') return
  window.localStorage.removeItem(TOKEN_KEY)
  window.localStorage.removeItem(CSRF_KEY)
  window.localStorage.removeItem('rw_token')
}

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => readToken())
  const [authError, setAuthError] = useState('')
  const [loading, setLoading] = useState(false)
  const cleanupRef = useRef(null)

  useLayoutEffect(() => {
    cleanupRef.current?.()
    cleanupRef.current = configureApi({
      refreshToken: async () => {
        const res = await api.post('/api/auth/refresh', {})
        const nextToken = res.data?.token
        if (!nextToken) {
          throw new Error('Unable to refresh session')
        }
        storeAuth(nextToken, res.data?.csrfToken || '')
        setToken(nextToken)
        return nextToken
      },
      onAuthFailure: () => {
        clearAuth()
        setToken(null)
      },
    })

    return () => {
      cleanupRef.current?.()
      cleanupRef.current = null
    }
  }, [])

  const login = async (email, password) => {
    setLoading(true)
    setAuthError('')
    try {
      const res = await api.post('/api/auth/login', { email, password })

      const t = res.data?.token
      if (!t) throw new Error('Backend did not return a token')

      storeAuth(t, res.data?.csrfToken || '')
      setToken(t)
      return t

    } catch (err) {
      const message = err.response?.data?.message || err.message || 'Login failed'
      setAuthError(message)
      throw new Error(message)
    } finally {
      setLoading(false)
    }
  }

  const logout = () => {
    setAuthError('')
    api.post('/api/auth/logout').catch(() => {}).finally(() => {
      clearAuth()
      setToken(null)
    })
  }

  const value = useMemo(() => ({
    token,
    login,
    logout,
    authError,
    loading,
    API: API_BASE,
  }), [token, authError, loading])

  return (
    <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
  )
}

export function useAuth() {
  return useContext(AuthContext)
}