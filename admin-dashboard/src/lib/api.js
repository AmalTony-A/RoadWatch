import axios from 'axios'

export const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:8001'

export const api = axios.create({
  baseURL: API_BASE,
  timeout: 15000,
  withCredentials: true,
})

function readStoredValue(...keys) {
  if (typeof window === 'undefined') return ''
  for (const key of keys) {
    const value = window.localStorage.getItem(key)
    if (value) return value
  }
  return ''
}

function isAuthEndpoint(url = '') {
  return ['/api/auth/login', '/api/auth/signup', '/api/auth/refresh', '/api/auth/logout', '/api/auth/csrf-token'].some((path) => url.includes(path))
}

api.interceptors.request.use((config) => {
  const token = readStoredValue('token', 'rw_token')
  const csrfToken = readStoredValue('csrfToken', 'csrf_token')

  config.headers = config.headers || {}

  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }

  if (csrfToken) {
    config.headers['X-CSRF-Token'] = csrfToken
  }

  return config
})

export function configureApi({ tokenProvider, refreshToken, onAuthFailure } = {}) {
  const responseInterceptor = api.interceptors.response.use(
    (response) => response,
    async (error) => {
      const status = error?.response?.status
      const originalRequest = error.config || {}

      if (status === 401 && refreshToken && !originalRequest._retry && !isAuthEndpoint(originalRequest.url || '')) {
        originalRequest._retry = true
        try {
          const newToken = await refreshToken()
          if (newToken) {
            originalRequest.headers = originalRequest.headers || {}
            originalRequest.headers.Authorization = `Bearer ${newToken}`
            return api.request(originalRequest)
          }
        } catch (refreshError) {
          if (onAuthFailure) onAuthFailure(refreshError)
          return Promise.reject(refreshError)
        }
      }

      if (status === 401 && onAuthFailure) {
        onAuthFailure(error)
      }
      return Promise.reject(error)
    }
  )

  return () => {
    api.interceptors.response.eject(responseInterceptor)
  }
}
