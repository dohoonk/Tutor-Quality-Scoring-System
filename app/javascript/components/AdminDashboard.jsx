import React from 'react'

const AdminDashboard = ({ adminId }) => {
  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-4">Admin Dashboard</h1>
      <p className="text-gray-600">Admin ID: {adminId}</p>
      <p className="mt-4 text-green-600">✓ React is mounted successfully!</p>
    </div>
  )
}

export default AdminDashboard

