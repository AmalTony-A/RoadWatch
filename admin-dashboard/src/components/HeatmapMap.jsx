import React, { useEffect, useRef } from 'react'
import L from 'leaflet'

function toNumber(value) {
  if (value === null || value === undefined || value === '') return null
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : null
}

function isValidCoordinate(lat, lng) {
  return lat !== null && lng !== null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}

export default function HeatmapMap({ points = [] }) {
  const mapRef = useRef(null)
  const containerRef = useRef(null)
  const pointsLayerRef = useRef(null)
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
    pointsLayerRef.current = L.layerGroup().addTo(map)

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
      pointsLayerRef.current = null
      if (containerRef.current && containerRef.current._leaflet_id) {
        delete containerRef.current._leaflet_id
      }
    }
  }, [])

  useEffect(() => {
    const map = mapRef.current
    const pointsLayer = pointsLayerRef.current
    if (!map || !pointsLayer) return

    pointsLayer.clearLayers()

    const validBounds = []
    points.forEach((point) => {
      const lat = toNumber(point?.lat)
      const lng = toNumber(point?.lng)
      if (!isValidCoordinate(lat, lng)) return

      const weightValue = toNumber(point?.weight)
      const weight = weightValue === null ? 1 : Math.max(0, weightValue)

      validBounds.push([lat, lng])
      L.circleMarker([lat, lng], {
        radius: 8 + (weight * 2),
        color: '#0f172a',
        fillColor: '#06b6d4',
        fillOpacity: 0.35,
        weight: 1,
      }).addTo(pointsLayer).bindPopup(`${point.title || 'Untitled'}<br/>${point.status || 'Unknown'}<br/>${point.department || 'Unassigned'}`)
    })

    if (validBounds.length > 0) {
      map.fitBounds(validBounds, { padding: [30, 30], maxZoom: 15 })
    }
  }, [points])

  return <div ref={containerRef} className="h-96 w-full rounded-2xl" />
}
