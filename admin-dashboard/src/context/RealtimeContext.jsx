import React, { createContext, useContext, useEffect, useMemo, useRef, useState } from 'react'
import { io } from 'socket.io-client'
import { API_BASE } from '../lib/api'
import { useAuth } from '../hooks/useAuth'

const RealtimeContext = createContext(null)

function normalizeEvent(event, payload) {
  const timestamp = new Date().toISOString()
  if (event.startsWith('report')) {
    return {
      id: `${event}-${timestamp}`,
      kind: 'report',
      title:
        event === 'reportDeleted'
          ? 'Report deleted'
          : event === 'reportCreated'
            ? 'New complaint created'
            : 'Report updated',
      description: payload?.title || payload?.description || 'A report changed',
      timestamp,
      payload,
      read: false,
    }
  }

  if (event === 'userLoggedIn') {
    return {
      id: `${event}-${timestamp}`,
      kind: 'user',
      title: 'User logged in',
      description: payload?.user?.email || 'A user signed in',
      timestamp,
      payload,
      read: false,
    }
  }

  if (event === 'userRegistered') {
    return {
      id: `${event}-${timestamp}`,
      kind: 'user',
      title: 'User registered',
      description: payload?.user?.email || 'A user registered',
      timestamp,
      payload,
      read: false,
    }
  }

  return {
    id: `${event}-${timestamp}`,
    kind: 'system',
    title: event,
    description: 'Realtime update received',
    timestamp,
    payload,
    read: false,
  }
}

export function RealtimeProvider({ children }) {
  const { token } = useAuth()
  const [connected, setConnected] = useState(false)
  const [lastEvent, setLastEvent] = useState(null)
  const [notifications, setNotifications] = useState([])
  const socketRef = useRef(null)

  useEffect(() => {
    if (!token) {
      setConnected(false)
      setNotifications([])
      setLastEvent(null)
      return undefined
    }

    // prevent duplicate sockets
    if (socketRef.current) {
      try { socketRef.current.disconnect(); } catch (e) {}
      socketRef.current = null
    }

    const socket = io(API_BASE, {
      path: '/socket.io',
      withCredentials: true,
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000,
      transports: ['polling'],
    })
    socketRef.current = socket

    const pushNotification = (event, payload) => {
      const normalized = normalizeEvent(event, payload)
      setLastEvent({ event, payload, timestamp: normalized.timestamp })
      setNotifications((current) => [normalized, ...current].slice(0, 30))
    }

    socket.on('connect', () => {
      console.log('Realtime connected')
      setConnected(true)
    })
    socket.on('disconnect', (reason) => {
      console.log('Realtime disconnected', reason)
      setConnected(false)
    })
    socket.on('connect_error', (err) => {
      console.log('Realtime connect_error', err && err.message)
      setConnected(false)
    })
    socket.on('reconnect_attempt', (attempt) => {
      console.log('Realtime reconnect attempt', attempt)
    })

    ;[
      'report:created',
      'reportCreated',
      'report:updated',
      'reportUpdated',
      'report:deleted',
      'reportDeleted',
      'userLoggedIn',
      'userRegistered',
    ].forEach((eventName) => {
      socket.on(eventName, (payload) => pushNotification(eventName, payload))
    })

    return () => {
      try {
        if (socketRef.current) {
          socketRef.current.off()
          socketRef.current.disconnect()
          socketRef.current = null
        }
      } catch (e) {
        // ignore
      }
    }
  }, [token])

  const markAllRead = () => {
    setNotifications((current) => current.map((item) => ({ ...item, read: true })))
  }

  const unreadCount = notifications.filter((item) => !item.read).length

  const value = useMemo(() => ({
    connected,
    lastEvent,
    notifications,
    unreadCount,
    markAllRead,
  }), [connected, lastEvent, notifications, unreadCount])

  return <RealtimeContext.Provider value={value}>{children}</RealtimeContext.Provider>
}

export function useRealtime() {
  return useContext(RealtimeContext)
}
