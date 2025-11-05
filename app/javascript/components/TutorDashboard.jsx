import React from 'react'

const TutorDashboard = ({ tutorId }) => {
  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-4">Tutor Dashboard</h1>
      <p className="text-gray-600">Tutor ID: {tutorId}</p>
      <p className="mt-4 text-green-600">✓ React is mounted successfully!</p>
    </div>
  )
}

export default TutorDashboard

