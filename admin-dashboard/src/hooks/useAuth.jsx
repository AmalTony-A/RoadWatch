import React, { createContext, useContext, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { api, API_BASE, configureApi } from '../lib/api'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => sessionStorage.getItem('rw_token'))
  const [authError, setAuthError] = useState('')
  const [loading, setLoading] = useState(false)
  const cleanupRef = useRef(null)

  useLayoutEffect(() => {
    cleanupRef.current?.()
    cleanupRef.current = configureApi({
      tokenProvider: () => sessionStorage.getItem('rw_token'),
      refreshToken: async () => {
        const res = await api.post('/api/auth/refresh', {})
        const nextToken = res.data?.token
        if (!nextToken) {
          throw new Error('Unable to refresh session')
        }
        sessionStorage.setItem('rw_token', nextToken)
        setToken(nextToken)
        return nextToken
      },
      onAuthFailure: () => {
        sessionStorage.removeItem('rw_token')
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

      sessionStorage.setItem('rw_token', t)
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
    sessionStorage.removeItem('rw_token')
    setToken(null)
    setAuthError('')
    api.post('/api/auth/logout').catch(() => {})
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