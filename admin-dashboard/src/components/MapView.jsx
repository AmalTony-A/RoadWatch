import React, { useEffect, useRef } from 'react'
import L from 'leaflet'

function markerColor(category) {
  if (category === 'Pothole') return '#ef4444'
  if (category === 'Waterlogging') return '#3b82f6'
  if (category === 'Traffic issue') return '#f97316'
  return '#64748b'
}

function markerIcon(color) {
  return L.divIcon({
    className: 'rw-marker',
    html: `<span style="display:block;width:14px;height:14px;border-radius:999px;background:${color};border:2px solid white;box-shadow:0 0 0 1px rgba(15,23,42,0.35);"></span>`,
    iconSize: [14, 14],
    iconAnchor: [7, 7],
  })
}

function toNumber(value) {
  if (value === null || value === undefined || value === '') return null
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : null
}

function normalizeCoordinates(report) {
  const lat = toNumber(report?.latitude ?? report?.location?.lat)
  const lng = toNumber(report?.longitude ?? report?.location?.lng)
  if (lat === null || lng === null) return null
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null
  return [lat, lng]
}

export default function MapView({ reports = [] }) {
  const containerRef = useRef(null)
  const mapRef = useRef(null)
  const markersLayerRef = useRef(null)
  const resizeObserverRef = useRef(null)

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return undefined

    const map = L.map(containerRef.current, {
      center: [12.99, 80.23],
      zoom: 11,
      zoomAnimation: false,
      fadeAnimation: false,
      markerZoomAnimation: false,
    })

    mapRef.current = map
    markersLayerRef.current = L.layerGroup().addTo(map)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map)

    if (typeof ResizeObserver !== 'undefined') {
      resizeObserverRef.current = new ResizeObserver(() => {
        if (mapRef.current) mapRef.current.invalidateSize()
      })
      resizeObserverRef.current.observe(containerRef.current)
    }

    return () => {
      if (resizeObserverRef.current) {
        resizeObserverRef.current.disconnect()
        resizeObserverRef.current = null
      }
      if (mapRef.current) {
        mapRef.current.off()
        mapRef.current.remove()
        mapRef.current = null
      }
      markersLayerRef.current = null
      if (containerRef.current && containerRef.current._leaflet_id) {
        delete containerRef.current._leaflet_id
      }
    }
  }, [])

  useEffect(() => {
    const map = mapRef.current
    const markersLayer = markersLayerRef.current
    if (!map || !markersLayer) return

    markersLayer.clearLayers()

    const validBounds = []
    reports.forEach((report) => {
      const coords = normalizeCoordinates(report)
      if (!coords) return

      validBounds.push(coords)
      const icon = markerIcon(markerColor(report.category))
      const popup = `
        <div style="min-width:180px">
          <div style="font-weight:700">${report.title || report.description || 'Untitled report'}</div>
          <div style="margin-top:4px">Status: ${report.status || 'Pending'}</div>
          <div>Department: ${report.recommendedDepartment || 'Unassigned'}</div>
          <div>Created: ${new Date(report.createdAt || report.timestamp || Date.now()).toLocaleString()}</div>
        </div>
      `

      const marker = L.marker(coords, { icon })
      marker.on('add', () => {
        try {
          const el = marker.getElement && marker.getElement()
          if (el) el.dataset.testid = 'map-marker'
        } catch (e) {
          // ignore
        }
      })
      marker.addTo(markersLayer).bindPopup(popup)
    })

    if (validBounds.length > 0) {
      map.fitBounds(validBounds, { padding: [30, 30], maxZoom: 15 })
    }
  }, [reports])

  return <div data-testid="leaflet-map" ref={containerRef} style={{ height: 300 }} className="rounded" />
}
