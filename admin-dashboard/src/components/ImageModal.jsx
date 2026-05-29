import React from 'react'

export default function ImageModal({ open, images = [], onClose }) {
  if (!open) return null

  const safeImages = images.filter(Boolean)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 p-4" onClick={onClose}>
      <div className="max-h-[90vh] w-full max-w-4xl overflow-y-auto rounded-2xl bg-white p-4 shadow-2xl dark:bg-slate-900" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between border-b border-slate-200 pb-3 dark:border-slate-700">
          <h3 className="text-lg font-bold text-slate-900 dark:text-white">Image Preview</h3>
          <button onClick={onClose} className="rounded-lg border border-slate-200 px-3 py-1 text-sm dark:border-slate-700">Close</button>
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-2">
          {safeImages.length > 0 ? safeImages.map((src, index) => (
            <img key={`${src}-${index}`} src={src} alt={`Complaint ${index + 1}`} className="h-72 w-full rounded-xl object-cover" />
          )) : (
            <div className="rounded-xl border border-dashed border-slate-300 p-8 text-center text-slate-500 dark:border-slate-700">No image available</div>
          )}
        </div>
      </div>
    </div>
  )
}
