import { useEffect, useRef } from 'react'
import { io } from 'socket.io-client'
import { useAuth } from './useAuth'

export default function useSocket(onEvent) {
  const { API } = useAuth()
  const socketRef = useRef(null)

  useEffect(() => {
    const socket = io(API, {
      path: '/socket.io',
      withCredentials: true,
      transports: ['polling'],
    })
    socketRef.current = socket
    socket.on('connect', () => {
      console.log('Realtime connected')
      onEvent && onEvent('connect')
    })
    socket.on('disconnect', () => {
      console.log('Realtime disconnected')
      onEvent && onEvent('disconnect')
    })
    socket.on('connect_error', (err) => {
      console.log(err)
      onEvent && onEvent('connect_error', err)
    })
    socket.on('report:created', (p) => onEvent && onEvent('report:created', p))
    socket.on('reportCreated', (p) => onEvent && onEvent('reportCreated', p))
    socket.on('report:updated', (p) => onEvent && onEvent('report:updated', p))
    socket.on('reportUpdated', (p) => onEvent && onEvent('reportUpdated', p))
    socket.on('report:deleted', (p) => onEvent && onEvent('report:deleted', p))
    socket.on('reportDeleted', (p) => onEvent && onEvent('reportDeleted', p))
    socket.on('userLoggedIn', (p) => onEvent && onEvent('userLoggedIn', p))
    socket.on('userRegistered', (p) => onEvent && onEvent('userRegistered', p))
    return () => { socket.disconnect(); socketRef.current = null }
  }, [API, onEvent])

  return socketRef
}
