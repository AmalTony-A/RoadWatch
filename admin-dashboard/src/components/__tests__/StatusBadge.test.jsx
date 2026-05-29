import React from 'react'
import { render, screen } from '@testing-library/react'
import StatusBadge from '../StatusBadge'

describe('StatusBadge', () => {
  test('renders resolved badge', () => {
    render(<StatusBadge value="Resolved" />)
    expect(screen.getByText('Resolved')).toBeInTheDocument()
  })
})
