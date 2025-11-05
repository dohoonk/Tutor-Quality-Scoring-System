import React, { useState, useEffect } from 'react'

const AdminDashboard = ({ adminId }) => {
  const [tutorList, setTutorList] = useState([])
  const [selectedTutor, setSelectedTutor] = useState(null)
  const [tutorMetrics, setTutorMetrics] = useState(null)
  const [tutorAlerts, setTutorAlerts] = useState([])
  const [loading, setLoading] = useState(true)
  const [sortColumn, setSortColumn] = useState('risk_score') // Default sort by risk
  const [sortDirection, setSortDirection] = useState('desc') // desc = high to low

  useEffect(() => {
    fetchTutorList()
  }, [])

  const fetchTutorList = async () => {
    setLoading(true)
    try {
      const response = await fetch('/api/admin/tutors/risk_list')
      if (response.ok) {
        const data = await response.json()
        setTutorList(data)
      }
    } catch (error) {
      console.error('Error fetching tutor list:', error)
    } finally {
      setLoading(false)
    }
  }

  const selectTutor = async (tutorId) => {
    try {
      const [metricsRes, alertsRes] = await Promise.all([
        fetch(`/api/admin/tutor/${tutorId}/metrics`),
        fetch(`/api/admin/tutor/${tutorId}/intervention_log`)
      ])

      if (metricsRes.ok) {
        const metrics = await metricsRes.json()
        setTutorMetrics(metrics)
      }

      if (alertsRes.ok) {
        const alerts = await alertsRes.json()
        setTutorAlerts(alerts)
      }

      setSelectedTutor(tutorId)
    } catch (error) {
      console.error('Error fetching tutor details:', error)
    }
  }

  const handleSort = (column) => {
    if (sortColumn === column) {
      // Toggle direction if clicking the same column
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      // New column, default to descending for scores, ascending for name
      setSortColumn(column)
      setSortDirection(column === 'name' ? 'asc' : 'desc')
    }
  }

  const sortedTutorList = [...tutorList].sort((a, b) => {
    let aVal = a[sortColumn]
    let bVal = b[sortColumn]
    
    // Handle null values (put them at the end)
    if (aVal === null || aVal === undefined) return 1
    if (bVal === null || bVal === undefined) return -1
    
    // String comparison for name
    if (sortColumn === 'name') {
      aVal = aVal.toLowerCase()
      bVal = bVal.toLowerCase()
      return sortDirection === 'asc' 
        ? aVal.localeCompare(bVal)
        : bVal.localeCompare(aVal)
    }
    
    // Numeric comparison for scores
    return sortDirection === 'asc' ? aVal - bVal : bVal - aVal
  })

  const getRiskBadge = (fsqs, ths, tcrs) => {
    const badges = []
    
    // FSQS: Higher is better (0-100 scale)
    if (fsqs !== null && fsqs <= 50) {
      badges.push({ label: 'Low First Session Quality', color: 'red' })
    } else if (fsqs !== null && fsqs <= 70) {
      badges.push({ label: 'First Session Warning', color: 'yellow' })
    }
    
    if (ths !== null && ths < 55) {
      badges.push({ label: 'Reliability Risk', color: 'red' })
    } else if (ths !== null && ths < 75) {
      badges.push({ label: 'Monitor Reliability', color: 'yellow' })
    }
    
    if (tcrs !== null && tcrs >= 0.6) {
      badges.push({ label: 'Churn Risk', color: 'red' })
    } else if (tcrs !== null && tcrs >= 0.3) {
      badges.push({ label: 'Monitor Churn', color: 'yellow' })
    }

    if (badges.length === 0) {
      badges.push({ label: 'Stable', color: 'green' })
    }

    return badges
  }

  const SortIcon = ({ column }) => {
    if (sortColumn !== column) {
      return <span className="ml-1 text-gray-400">⇅</span>
    }
    return sortDirection === 'asc' 
      ? <span className="ml-1 text-gray-700">↑</span>
      : <span className="ml-1 text-gray-700">↓</span>
  }

  if (loading) {
    return (
      <div className="p-6">
        <div className="text-center">Loading...</div>
      </div>
    )
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Admin Dashboard</h1>

      {/* Risk Overview Table */}
      <div className="mb-8">
        <h2 className="text-2xl font-semibold mb-4">Tutor Risk Overview</h2>
        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                  onClick={() => handleSort('name')}
                >
                  <div className="flex items-center">
                    Tutor Name
                    <SortIcon column="name" />
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                  onClick={() => handleSort('fsqs')}
                >
                  <div className="flex items-center">
                    FSQS
                    <SortIcon column="fsqs" />
                  </div>
                </th>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                  onClick={() => handleSort('ths')}
                >
                  <div className="flex items-center">
                    THS
                    <SortIcon column="ths" />
                  </div>
                </th>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                  onClick={() => handleSort('tcrs')}
                >
                  <div className="flex items-center">
                    TCRS
                    <SortIcon column="tcrs" />
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Alerts
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {sortedTutorList.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-4 text-center text-gray-500">
                    No tutors found
                  </td>
                </tr>
              ) : (
                sortedTutorList.map((tutor) => {
                  const badges = getRiskBadge(tutor.fsqs, tutor.ths, tutor.tcrs)
                  return (
                    <tr key={tutor.id} className={selectedTutor === tutor.id ? 'bg-blue-50' : ''}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        {tutor.name}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <div className="flex flex-wrap gap-1">
                          {badges.map((badge, idx) => (
                            <span
                              key={idx}
                              className={`px-2 py-1 rounded text-xs ${
                                badge.color === 'red' ? 'bg-red-100 text-red-800' :
                                badge.color === 'yellow' ? 'bg-yellow-100 text-yellow-800' :
                                'bg-green-100 text-green-800'
                              }`}
                            >
                              {badge.label}
                            </span>
                          ))}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {tutor.fsqs !== null ? tutor.fsqs.toFixed(1) : 'N/A'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {tutor.ths !== null ? tutor.ths.toFixed(1) : 'N/A'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {tutor.tcrs !== null ? tutor.tcrs.toFixed(2) : 'N/A'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        {tutor.alert_count > 0 ? (
                          <span className="px-2 py-1 bg-red-100 text-red-800 rounded text-xs font-medium">
                            {tutor.alert_count} open
                          </span>
                        ) : (
                          <span className="text-gray-400">—</span>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <button
                          onClick={() => selectTutor(tutor.id)}
                          className="text-blue-600 hover:text-blue-800 font-medium"
                        >
                          View Details
                        </button>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Tutor Detail Panel */}
      {selectedTutor && tutorMetrics && (
        <div className="mb-8">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-2xl font-semibold">
              Tutor Details: {tutorMetrics.name}
            </h2>
            <button
              onClick={() => setSelectedTutor(null)}
              className="text-gray-500 hover:text-gray-700"
            >
              ✕ Close
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
            {/* FSQS Card */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold mb-2">First Session Quality Score</h3>
              <div className="text-3xl font-bold mb-2">
                {tutorMetrics.fsqs !== null ? tutorMetrics.fsqs.toFixed(1) : 'N/A'}
              </div>
              <div className={`text-sm ${
                tutorMetrics.fsqs <= 50 ? 'text-red-600' :
                tutorMetrics.fsqs <= 70 ? 'text-yellow-600' :
                'text-green-600'
              }`}>
                {tutorMetrics.fsqs <= 50 ? '⚠️ Low Quality' :
                 tutorMetrics.fsqs <= 70 ? '⚠️ Fair' :
                 '✓ Good'}
              </div>
            </div>

            {/* THS Card */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold mb-2">Tutor Health Score (7d)</h3>
              <div className="text-3xl font-bold mb-2">
                {tutorMetrics.ths !== null ? tutorMetrics.ths.toFixed(1) : 'N/A'}
              </div>
              <div className={`text-sm ${
                tutorMetrics.ths < 55 ? 'text-red-600' :
                tutorMetrics.ths < 75 ? 'text-yellow-600' :
                'text-green-600'
              }`}>
                {tutorMetrics.ths < 55 ? '⚠️ High Risk' :
                 tutorMetrics.ths < 75 ? '⚠️ Monitor' :
                 '✓ Stable'}
              </div>
            </div>

            {/* TCRS Card */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold mb-2">Churn Risk Score (14d)</h3>
              <div className="text-3xl font-bold mb-2">
                {tutorMetrics.tcrs !== null ? tutorMetrics.tcrs.toFixed(2) : 'N/A'}
              </div>
              <div className={`text-sm ${
                tutorMetrics.tcrs >= 0.6 ? 'text-red-600' :
                tutorMetrics.tcrs >= 0.3 ? 'text-yellow-600' :
                'text-green-600'
              }`}>
                {tutorMetrics.tcrs >= 0.6 ? '⚠️ High Risk' :
                 tutorMetrics.tcrs >= 0.3 ? '⚠️ Monitor' :
                 '✓ Stable'}
              </div>
            </div>
          </div>

          {/* SQS Trend */}
          {tutorMetrics.sqs_history && tutorMetrics.sqs_history.length > 0 && (
            <div className="bg-white rounded-lg shadow-md p-6 mb-6">
              <h3 className="text-lg font-semibold mb-4">Session Quality Trend</h3>
              <div className="flex items-end gap-2 h-32">
                {tutorMetrics.sqs_history.map((item, index) => {
                  const maxScore = Math.max(...tutorMetrics.sqs_history.map(s => s.value), 100)
                  const height = (item.value / maxScore) * 100
                  const color = item.value < 60 ? 'bg-red-500' : 
                                item.value <= 75 ? 'bg-yellow-500' : 'bg-green-500'
                  return (
                    <div key={index} className="flex-1 flex flex-col items-center">
                      <div
                        className={`w-full ${color} rounded-t`}
                        style={{ height: `${height}%` }}
                        title={`SQS: ${item.value}`}
                      />
                    </div>
                  )
                })}
              </div>
              <div className="text-sm text-gray-600 mt-2">
                Last {tutorMetrics.sqs_history.length} sessions
              </div>
            </div>
          )}

          {/* Intervention Log */}
          {tutorAlerts.length > 0 && (
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold mb-4">Past Interventions</h3>
              <div className="space-y-3">
                {tutorAlerts.map((alert) => (
                  <div key={alert.id} className="border-l-4 border-blue-500 pl-4 py-2">
                    <div className="flex justify-between items-start">
                      <div>
                        <div className="font-medium text-gray-900">
                          {alert.alert_type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                        </div>
                        <div className="text-sm text-gray-600">
                          Triggered: {new Date(alert.triggered_at).toLocaleDateString()}
                          {alert.resolved_at && ` • Resolved: ${new Date(alert.resolved_at).toLocaleDateString()}`}
                        </div>
                      </div>
                      <span className={`px-2 py-1 rounded text-xs ${
                        alert.severity === 'high' ? 'bg-red-100 text-red-800' :
                        alert.severity === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                        'bg-blue-100 text-blue-800'
                      }`}>
                        {alert.severity}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default AdminDashboard
