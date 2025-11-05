import React, { useState, useEffect, useRef } from 'react'
import { 
  LoadingSpinner, 
  SkeletonDashboard, 
  EmptyAlertState, 
  ErrorState,
  AccessibleButton,
  MobileSearchableTable
} from './ui'

// Tooltip Component with improved accessibility
const Tooltip = ({ text }) => {
  const [show, setShow] = useState(false)
  const [position, setPosition] = useState({ top: 0, left: 0 })
  const buttonRef = useRef(null)
  
  const updatePosition = () => {
    if (buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect()
      setPosition({
        top: rect.top - 8, // Position above the button
        left: rect.left + rect.width / 2 // Center horizontally
      })
    }
  }
  
  const handleMouseEnter = () => {
    updatePosition()
    setShow(true)
  }
  
  return (
    <>
      <div className="relative inline-block">
        <button
          ref={buttonRef}
          type="button"
          onMouseEnter={handleMouseEnter}
          onMouseLeave={() => setShow(false)}
          onFocus={handleMouseEnter}
          onBlur={() => setShow(false)}
          className="ml-1 text-gray-400 hover:text-gray-600 cursor-help transition-colors focus-ring"
          aria-label="More information"
        >
          <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clipRule="evenodd" />
          </svg>
        </button>
      </div>
      {show && (
        <div 
          className="fixed w-64 p-3 bg-gray-900 text-white text-xs rounded-lg shadow-lg z-[9999] pointer-events-none"
          style={{
            top: `${position.top}px`,
            left: `${position.left}px`,
            transform: 'translate(-50%, -100%)',
            marginTop: '-8px'
          }}
        >
          {text}
          <div className="absolute top-full left-1/2 transform -translate-x-1/2 -mt-1 border-4 border-transparent border-t-gray-900"></div>
        </div>
      )}
    </>
  )
}

const AdminDashboard = ({ adminId }) => {
  const [tutorList, setTutorList] = useState([])
  const [selectedTutor, setSelectedTutor] = useState(null)
  const [tutorMetrics, setTutorMetrics] = useState(null)
  const [tutorAlerts, setTutorAlerts] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [detailLoading, setDetailLoading] = useState(false)

  useEffect(() => {
    fetchTutorList()
  }, [])

  const fetchTutorList = async () => {
    setLoading(true)
    setError(null)
    
    try {
      const response = await fetch('/api/admin/tutors/risk_list')
      if (response.ok) {
        const data = await response.json()
        setTutorList(data)
      } else {
        throw new Error('Failed to fetch tutor list')
      }
    } catch (err) {
      console.error('Error fetching tutor list:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const selectTutor = async (tutorId) => {
    setDetailLoading(true)
    
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
    } finally {
      setDetailLoading(false)
    }
  }

  const getRiskBadge = (fsqs, ths, tcrs) => {
    const badges = []
    
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

  // Get risk level for filtering
  const getRiskLevel = (tutor) => {
    const badges = getRiskBadge(tutor.fsqs, tutor.ths, tutor.tcrs)
    if (badges.some(b => b.color === 'red')) return 'high'
    if (badges.some(b => b.color === 'yellow')) return 'medium'
    return 'low'
  }

  // Get status badges for filtering
  const getStatusBadges = (tutor) => {
    const badges = getRiskBadge(tutor.fsqs, tutor.ths, tutor.tcrs)
    return badges.map(badge => badge.label)
  }

  // Loading State
  if (loading) {
    return (
      <div className="p-4 md:p-6 max-w-7xl mx-auto">
        <SkeletonDashboard />
      </div>
    )
  }

  // Error State
  if (error) {
    return (
      <div className="p-4 md:p-6 max-w-7xl mx-auto">
        <ErrorState onRetry={fetchTutorList} />
      </div>
    )
  }

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto animate-fade-in">
      <header className="mb-6 md:mb-8">
        <h1 className="text-2xl md:text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-gray-600 mt-1">Monitor tutor performance and manage interventions</p>
      </header>

      {/* Risk Overview Table */}
      <section className="mb-6 md:mb-8 animate-slide-in-up">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-4 gap-2">
          <h2 className="text-xl md:text-2xl font-semibold">Tutor Risk Overview</h2>
          <span className="text-sm text-gray-600">{tutorList.length} tutors</span>
        </div>
        
        <MobileSearchableTable
          data={tutorList}
          keyExtractor={(tutor) => tutor.id}
          emptyState={<EmptyAlertState />}
          searchableFields={['name']}
          filters={[
            {
              key: 'risk_level',
              label: 'Risk Level',
              getValue: (tutor) => getRiskLevel(tutor),
              options: [
                { value: 'high', label: 'High Risk' },
                { value: 'medium', label: 'Medium Risk' },
                { value: 'low', label: 'Low Risk' }
              ]
            },
            {
              key: 'status',
              label: 'Status',
              getValue: (tutor) => getStatusBadges(tutor),
              options: [
                { value: 'Low First Session Quality', label: 'Low First Session Quality' },
                { value: 'First Session Warning', label: 'First Session Warning' },
                { value: 'Reliability Risk', label: 'Reliability Risk' },
                { value: 'Monitor Reliability', label: 'Monitor Reliability' },
                { value: 'Churn Risk', label: 'Churn Risk' },
                { value: 'Monitor Churn', label: 'Monitor Churn' },
                { value: 'Stable', label: 'Stable' }
              ]
            },
            {
              key: 'has_alerts',
              label: 'Alerts',
              options: [
                { value: 'yes', label: 'Has Alerts' },
                { value: 'no', label: 'No Alerts' }
              ]
            }
          ]}
          defaultSort={{ column: 'risk_score', direction: 'desc' }}
          onRowClick={(tutor) => selectTutor(tutor.id)}
          mobileBreakpoint="md"
          columns={[
            {
              key: 'name',
              label: 'Tutor Name',
              sortable: true,
              render: (tutor) => (
                <span className="font-medium text-gray-900">{tutor.name}</span>
              )
            },
            {
              key: 'status',
              label: 'Status',
              sortable: false,
              render: (tutor) => {
                const badges = getRiskBadge(tutor.fsqs, tutor.ths, tutor.tcrs)
                return (
                  <div className="flex flex-wrap gap-1">
                    {badges.map((badge, idx) => (
                      <span
                        key={idx}
                        className={`px-2 py-1 rounded text-xs font-medium ${
                          badge.color === 'red' ? 'bg-red-100 text-red-800' :
                          badge.color === 'yellow' ? 'bg-yellow-100 text-yellow-800' :
                          'bg-green-100 text-green-800'
                        }`}
                      >
                        {badge.label}
                      </span>
                    ))}
                  </div>
                )
              }
            },
            {
              key: 'fsqs',
              label: (
                <span className="flex items-center">
                  FSQS
                  <Tooltip text="First Session Quality Score (FSQS) measures the quality of initial sessions with new students. A higher score (70-100) indicates strong rapport-building, clear goal-setting, and encouraging communication. Scores below 50 suggest areas to improve such as reducing confusion, using positive language, or providing better session structure." />
                </span>
              ),
              sortable: true,
              render: (tutor) => (
                tutor.fsqs !== null ? (
                  <span>{tutor.fsqs.toFixed(1)}</span>
                ) : (
                  <span className="text-gray-400">N/A</span>
                )
              )
            },
            {
              key: 'ths',
              label: (
                <span className="flex items-center">
                  THS
                  <Tooltip text="Tutor Health Score (THS) measures 7-day reliability metrics including tutor-initiated reschedules, no-shows, and behavioral lateness patterns. Higher scores (75+) indicate stable reliability, while scores below 55 suggest high reliability risk requiring attention." />
                </span>
              ),
              sortable: true,
              render: (tutor) => (
                tutor.ths !== null ? (
                  <span>{tutor.ths.toFixed(1)}</span>
                ) : (
                  <span className="text-gray-400">N/A</span>
                )
              )
            },
            {
              key: 'tcrs',
              label: (
                <span className="flex items-center">
                  TCRS
                  <Tooltip text="Tutor Churn Risk Score (TCRS) predicts tutor disengagement based on 14-day engagement metrics including availability drop, session completion decline, and repeat student rate. Scores ≥0.6 indicate high churn risk, 0.3-0.59 suggest monitoring needed, and <0.3 indicates stable engagement." />
                </span>
              ),
              sortable: true,
              render: (tutor) => (
                tutor.tcrs !== null ? (
                  <span>{tutor.tcrs.toFixed(2)}</span>
                ) : (
                  <span className="text-gray-400">N/A</span>
                )
              )
            },
            {
              key: 'alerts',
              label: 'Alerts',
              sortable: true,
              render: (tutor) => (
                tutor.alert_count > 0 ? (
                  <span className="inline-flex items-center px-2 py-1 bg-red-100 text-red-800 rounded text-xs font-medium">
                    {tutor.alert_count} open
                  </span>
                ) : (
                  <span className="text-gray-400">—</span>
                )
              )
            },
            {
              key: 'actions',
              label: 'Actions',
              sortable: false,
              render: (tutor) => (
                <AccessibleButton
                  onClick={(e) => {
                    e.stopPropagation()
                    selectTutor(tutor.id)
                  }}
                  variant="link"
                  size="sm"
                  ariaLabel={`View details for ${tutor.name}`}
                >
                  View Details
                </AccessibleButton>
              )
            }
          ]}
        />
      </section>

      {/* Tutor Detail Panel */}
      {selectedTutor && (
        <section className="mb-6 md:mb-8 animate-slide-in-up" style={{ animationDelay: '0.1s' }}>
          <div className="bg-gray-50 p-4 md:p-6 rounded-lg border-2 border-blue-200">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-4 gap-2">
              <h2 className="text-xl md:text-2xl font-semibold">
                Tutor Details: {tutorMetrics?.name || 'Loading...'}
              </h2>
              <AccessibleButton
                onClick={() => {
                  setSelectedTutor(null)
                  setTutorMetrics(null)
                  setTutorAlerts([])
                }}
                variant="ghost"
                size="sm"
                ariaLabel="Close tutor details"
                className="text-gray-500 hover:text-gray-700"
              >
                ✕ Close
              </AccessibleButton>
            </div>

            {detailLoading ? (
              <div className="flex justify-center py-12">
                <LoadingSpinner size="lg" />
              </div>
            ) : tutorMetrics ? (
              <>
                {/* Metric Cards */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6 mb-6">
                  {/* FSQS Card */}
                  <div className="bg-white rounded-lg shadow-md p-4 md:p-6 hover-lift">
                    <h3 className="text-base md:text-lg font-semibold mb-2 flex items-center">
                      First Session Quality Score
                      <Tooltip text="First Session Quality Score (FSQS) measures the quality of initial sessions with new students. A higher score (70-100) indicates strong rapport-building, clear goal-setting, and encouraging communication. Scores below 50 suggest areas to improve such as reducing confusion, using positive language, or providing better session structure." />
                    </h3>
                    <div className="text-3xl md:text-4xl font-bold mb-2">
                      {tutorMetrics.fsqs !== null ? tutorMetrics.fsqs.toFixed(1) : 'N/A'}
                    </div>
                    <div className={`text-sm font-medium transition-colors ${
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
                  <div className="bg-white rounded-lg shadow-md p-4 md:p-6 hover-lift">
                    <h3 className="text-base md:text-lg font-semibold mb-2 flex items-center">
                      Tutor Health Score (7d)
                      <Tooltip text="Tutor Health Score (THS) measures 7-day reliability metrics including tutor-initiated reschedules, no-shows, and behavioral lateness patterns. Higher scores (75+) indicate stable reliability, while scores below 55 suggest high reliability risk requiring attention." />
                    </h3>
                    <div className="text-3xl md:text-4xl font-bold mb-2">
                      {tutorMetrics.ths !== null ? tutorMetrics.ths.toFixed(1) : 'N/A'}
                    </div>
                    <div className={`text-sm font-medium transition-colors ${
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
                  <div className="bg-white rounded-lg shadow-md p-4 md:p-6 hover-lift">
                    <h3 className="text-base md:text-lg font-semibold mb-2 flex items-center">
                      Churn Risk Score (14d)
                      <Tooltip text="Tutor Churn Risk Score (TCRS) predicts tutor disengagement based on 14-day engagement metrics including availability drop, session completion decline, and repeat student rate. Scores ≥0.6 indicate high churn risk, 0.3-0.59 suggest monitoring needed, and <0.3 indicates stable engagement." />
                    </h3>
                    <div className="text-3xl md:text-4xl font-bold mb-2">
                      {tutorMetrics.tcrs !== null ? tutorMetrics.tcrs.toFixed(2) : 'N/A'}
                    </div>
                    <div className={`text-sm font-medium transition-colors ${
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
                  <div className="bg-white rounded-lg shadow-md p-4 md:p-6 mb-6 hover-lift">
                    <h3 className="text-lg font-semibold mb-4">Session Quality Trend</h3>
                    <div className="flex items-end gap-1 md:gap-2 h-32">
                      {tutorMetrics.sqs_history.map((item, index) => {
                        const maxScore = Math.max(...tutorMetrics.sqs_history.map(s => s.value), 100)
                        const height = (item.value / maxScore) * 100
                        const color = item.value < 60 ? 'bg-red-500' : 
                                      item.value <= 75 ? 'bg-yellow-500' : 'bg-green-500'
                        return (
                          <div key={index} className="flex-1 flex flex-col items-center group">
                            <div
                              className={`w-full ${color} rounded-t transition-all hover:opacity-80`}
                              style={{ height: `${height}%` }}
                              title={`SQS: ${item.value}`}
                              aria-label={`Session ${index + 1}: SQS ${item.value}`}
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
                {tutorAlerts.length > 0 ? (
                  <div className="bg-white rounded-lg shadow-md p-4 md:p-6 hover-lift">
                    <h3 className="text-lg font-semibold mb-4">Past Interventions</h3>
                    <div className="space-y-3">
                      {tutorAlerts.map((alert) => (
                        <div key={alert.id} className="border-l-4 border-blue-500 pl-4 py-2 transition-all hover:bg-gray-50 rounded-r">
                          <div className="flex flex-col sm:flex-row justify-between items-start gap-2">
                            <div className="flex-1">
                              <div className="font-medium text-gray-900">
                                {alert.alert_type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                              </div>
                              <div className="text-sm text-gray-600">
                                Triggered: {new Date(alert.triggered_at).toLocaleDateString()}
                                {alert.resolved_at && ` • Resolved: ${new Date(alert.resolved_at).toLocaleDateString()}`}
                              </div>
                            </div>
                            <span className={`flex-shrink-0 px-2 py-1 rounded text-xs font-medium transition-colors ${
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
                ) : (
                  <div className="bg-white rounded-lg shadow-md p-4 md:p-6">
                    <EmptyAlertState />
                  </div>
                )}
              </>
            ) : null}
          </div>
        </section>
      )}
    </div>
  )
}

export default AdminDashboard
