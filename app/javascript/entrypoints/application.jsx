import React from 'react'
import { createRoot } from 'react-dom/client'
import TutorDashboard from '../components/TutorDashboard'
import AdminDashboard from '../components/AdminDashboard'
import { ToastProvider, ErrorBoundary } from '../components/ui'

// React entry point for the application
// Mounts React components based on the route with global providers
document.addEventListener('DOMContentLoaded', () => {
  const rootElement = document.getElementById('react-root')
  
  if (!rootElement) {
    console.log('No React root element found')
    return
  }

  const componentName = rootElement.getAttribute('data-component')
  const root = createRoot(rootElement)

  // Determine which component to render
  let Component = null
  let props = {}

  switch (componentName) {
    case 'TutorDashboard':
      Component = TutorDashboard
      props = { tutorId: rootElement.getAttribute('data-tutor-id') }
      console.log(`✓ React mounting: TutorDashboard for tutor ${props.tutorId}`)
      break
    
    case 'AdminDashboard':
      Component = AdminDashboard
      props = { adminId: rootElement.getAttribute('data-admin-id') }
      console.log(`✓ React mounting: AdminDashboard for admin ${props.adminId}`)
      break
    
    default:
      console.log(`No React component found for: ${componentName}`)
      return
  }

  // Render with global providers (ErrorBoundary and ToastProvider)
  root.render(
    <ErrorBoundary>
      <ToastProvider>
        <Component {...props} />
      </ToastProvider>
    </ErrorBoundary>
  )
})

