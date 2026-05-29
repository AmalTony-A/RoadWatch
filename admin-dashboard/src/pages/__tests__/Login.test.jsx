import React from 'react'
import { MemoryRouter } from 'react-router-dom'
import { fireEvent, render, screen } from '@testing-library/react'
import { vi } from 'vitest'
import Login from '../Login'

const navigate = vi.fn()
const login = vi.fn().mockResolvedValue('token')

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom')
  return {
    ...actual,
    useNavigate: () => navigate,
  }
})

vi.mock('../../hooks/useAuth.jsx', () => ({
  useAuth: () => ({ login, token: null, authError: '', loading: false }),
}))

describe('Login page', () => {
  test('submits the seeded admin credentials', async () => {
    render(
      <MemoryRouter>
        <Login />
      </MemoryRouter>,
    )

    fireEvent.click(screen.getByRole('button', { name: /sign in/i }))

    expect(login).toHaveBeenCalledWith('admin@roadwatch.local', 'Admin@12345')
  })
})
