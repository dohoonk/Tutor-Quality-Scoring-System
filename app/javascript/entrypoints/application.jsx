import React from 'react'
import { createRoot } from 'react-dom/client'
import TutorDashboard from '../components/TutorDashboard'
import AdminDashboard from '../components/AdminDashboard'

// React entry point for the application
// Mounts React components based on the route
document.addEventListener('DOMContentLoaded', () => {
  const rootElement = document.getElementById('react-root')
  
  if (!rootElement) {
    console.log('No React root element found')
    return
  }

  const componentName = rootElement.getAttribute('data-component')
  const root = createRoot(rootElement)

  switch (componentName) {
    case 'TutorDashboard':
      const tutorId = rootElement.getAttribute('data-tutor-id')
      root.render(<TutorDashboard tutorId={tutorId} />)
      console.log(`✓ React mounted: TutorDashboard for tutor ${tutorId}`)
      break
    
    case 'AdminDashboard':
      const adminId = rootElement.getAttribute('data-admin-id')
      root.render(<AdminDashboard adminId={adminId} />)
      console.log(`✓ React mounted: AdminDashboard for admin ${adminId}`)
      break
    
    default:
      console.log(`No React component found for: ${componentName}`)
  }
})

