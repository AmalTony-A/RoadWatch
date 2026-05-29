import axios from 'axios'

export const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:8001'

export const api = axios.create({
  baseURL: API_BASE,
  timeout: 15000,
  withCredentials: true,
})

function readCookie(name) {
  if (typeof document === 'undefined') return ''
  const match = document.cookie.split('; ').find((entry) => entry.startsWith(`${name}=`))
  return match ? decodeURIComponent(match.split('=').slice(1).join('=')) : ''
}

function isAuthEndpoint(url = '') {
  return ['/api/auth/login', '/api/auth/signup', '/api/auth/refresh', '/api/auth/logout', '/api/auth/csrf-token'].some((path) => url.includes(path))
}

export function configureApi({ tokenProvider, refreshToken, onAuthFailure } = {}) {
  const requestInterceptor = api.interceptors.request.use((config) => {
    const token = tokenProvider?.()
    if (token) {
      config.headers = config.headers || {}
      config.headers.Authorization = `Bearer ${token}`
    }

    const method = String(config.method || 'get').toLowerCase()
    if (!['get', 'head', 'options'].includes(method) && !isAuthEndpoint(config.url || '')) {
      const csrfToken = readCookie('csrf_token')
      if (csrfToken) {
        config.headers = config.headers || {}
        config.headers['X-CSRF-Token'] = csrfToken
      }
    }

    return config
  })

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
    api.interceptors.request.eject(requestInterceptor)
    api.interceptors.response.eject(responseInterceptor)
  }
}
