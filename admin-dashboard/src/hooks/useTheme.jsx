import { useEffect, useState } from 'react'

export default function useTheme() {
  const [darkMode, setDarkMode] = useState(() => sessionStorage.getItem('rw_theme') === 'dark')

  useEffect(() => {
    document.documentElement.classList.toggle('dark', darkMode)
    sessionStorage.setItem('rw_theme', darkMode ? 'dark' : 'light')
  }, [darkMode])

  const toggleTheme = () => setDarkMode((value) => !value)

  return { darkMode, toggleTheme }
}
