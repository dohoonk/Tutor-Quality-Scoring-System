/** @jsxImportSource react */
import { useState, useEffect } from 'react'

const TutorDashboard = ({ tutorId }) => {
  const [fsrsLatest, setFsrsLatest] = useState(null)
  const [fsrsHistory, setFsrsHistory] = useState([])
  const [performanceSummary, setPerformanceSummary] = useState(null)
  const [sessionList, setSessionList] = useState([])
  const [loading, setLoading] = useState(true)
  const [showPastSessions, setShowPastSessions] = useState(false)

  useEffect(() => {
    if (!tutorId) return

    const fetchData = async () => {
      setLoading(true)
      try {
        // Fetch all data in parallel
        const [fsrsLatestRes, fsrsHistoryRes, performanceSummaryRes, sessionListRes] = await Promise.all([
          fetch(`/api/tutor/${tutorId}/fsrs_latest`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/fsrs_history`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/performance_summary`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/session_list`).catch(() => null)
        ])

        if (fsrsLatestRes?.ok) {
          const data = await fsrsLatestRes.json()
          setFsrsLatest(data)
        }

        if (fsrsHistoryRes?.ok) {
          const data = await fsrsHistoryRes.json()
          setFsrsHistory(data)
        }

        if (performanceSummaryRes?.ok) {
          const data = await performanceSummaryRes.json()
          setPerformanceSummary(data)
        }

        if (sessionListRes?.ok) {
          const data = await sessionListRes.json()
          setSessionList(data)
        }
      } catch (error) {
        console.error('Error fetching data:', error)
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [tutorId])

  const getScoreLabel = (score, scoreType) => {
    if (scoreType === 'fsrs') {
      if (score >= 50) return { label: 'Risk', color: 'red' }
      if (score >= 30) return { label: 'Warning', color: 'yellow' }
      return { label: 'Good', color: 'green' }
    } else if (scoreType === 'sqs') {
      if (score < 60) return { label: 'Risk', color: 'red' }
      if (score <= 75) return { label: 'Warning', color: 'yellow' }
      return { label: 'OK', color: 'green' }
    }
    return { label: 'Unknown', color: 'gray' }
  }

  const calculateAverage = (scores) => {
    if (!scores || scores.length === 0) return 0
    const sum = scores.reduce((acc, item) => acc + (item.score || 0), 0)
    return (sum / scores.length).toFixed(1)
  }

  const calculateImprovement = (scores) => {
    if (!scores || scores.length < 2) return null
    const recent = scores.slice(0, Math.ceil(scores.length / 2))
    const previous = scores.slice(Math.ceil(scores.length / 2))
    const recentAvg = recent.reduce((acc, item) => acc + (item.score || 0), 0) / recent.length
    const previousAvg = previous.reduce((acc, item) => acc + (item.score || 0), 0) / previous.length
    if (previousAvg === 0) return null
    const change = ((recentAvg - previousAvg) / previousAvg) * 100
    return change.toFixed(1)
  }

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A'
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  }

  if (loading) {
    return (
      <div className="p-6">
        <div className="text-center">Loading...</div>
      </div>
    )
  }

  const avgFsrs = calculateAverage(fsrsHistory)
  const improvement = calculateImprovement(fsrsHistory)
  const fsrsLabel = fsrsLatest ? getScoreLabel(fsrsLatest.score, 'fsrs') : null

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Tutor Dashboard</h1>

      {/* FSRS Feedback Section */}
      {fsrsLatest && (
        <div className="mb-8">
          <h2 className="text-2xl font-semibold mb-4">First Session Quality Feedback</h2>
          
          <div className="bg-white rounded-lg shadow-md p-6 mb-4">
            <div className="grid grid-cols-2 gap-4 mb-6">
              {/* FSRS Indicator */}
              <div className="border-r pr-4">
                <div className="text-sm text-gray-600 mb-1">FSRS Score</div>
                <div className="flex items-center gap-2">
                  <span className="text-3xl font-bold">{fsrsLatest.score}</span>
                  <span className={`px-3 py-1 rounded-full text-sm font-medium ${
                    fsrsLabel?.color === 'red' ? 'bg-red-100 text-red-800' :
                    fsrsLabel?.color === 'yellow' ? 'bg-yellow-100 text-yellow-800' :
                    'bg-green-100 text-green-800'
                  }`}>
                    {fsrsLabel?.label}
                  </span>
                </div>
              </div>

              {/* FSRS Trend Summary */}
              <div>
                <div className="text-sm text-gray-600 mb-1">Average FSRS (Last 5)</div>
                <div className="flex items-center gap-2">
                  <span className="text-3xl font-bold">{avgFsrs}</span>
                  {improvement && (
                    <span className={`text-sm font-medium ${
                      improvement > 0 ? 'text-red-600' : 'text-green-600'
                    }`}>
                      {improvement > 0 ? '↑' : '↓'} {Math.abs(improvement)}%
                    </span>
                  )}
                </div>
              </div>
            </div>

            {/* What Went Well */}
            {fsrsLatest.feedback?.what_went_well && (
              <div className="mb-4">
                <h3 className="text-lg font-semibold text-green-700 mb-2">✓ What Went Well</h3>
                <p className="text-gray-700">{fsrsLatest.feedback.what_went_well}</p>
              </div>
            )}

            {/* One Improvement Idea */}
            {fsrsLatest.feedback?.improvement_idea && (
              <div>
                <h3 className="text-lg font-semibold text-blue-700 mb-2">💡 One Improvement Idea</h3>
                <p className="text-gray-700">{fsrsLatest.feedback.improvement_idea}</p>
              </div>
            )}
          </div>

          {/* FSRS Trend Sparkline */}
          {fsrsHistory.length > 0 && (
            <div className="bg-white rounded-lg shadow-md p-6 mb-4">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-semibold">FSRS Trend</h3>
                <button
                  onClick={() => setShowPastSessions(!showPastSessions)}
                  className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                >
                  View Past First Sessions →
                </button>
              </div>
              
              {/* Simple Sparkline (using bars) */}
              <div className="flex items-end gap-2 h-24 mb-4">
                {fsrsHistory.map((item, index) => {
                  const maxScore = Math.max(...fsrsHistory.map(h => h.score || 0), 50)
                  const height = ((item.score || 0) / maxScore) * 100
                  const color = item.score >= 50 ? 'bg-red-500' : item.score >= 30 ? 'bg-yellow-500' : 'bg-green-500'
                  return (
                    <div key={index} className="flex-1 flex flex-col items-center">
                      <div
                        className={`w-full ${color} rounded-t`}
                        style={{ height: `${height}%` }}
                        title={`Score: ${item.score}`}
                      />
                    </div>
                  )
                })}
              </div>

              <div className="text-sm text-gray-600">
                Average: {avgFsrs} | {improvement && (
                  <span className={improvement > 0 ? 'text-red-600' : 'text-green-600'}>
                    {improvement > 0 ? 'Worsening' : 'Improving'} by {Math.abs(improvement)}% vs previous period
                  </span>
                )}
              </div>
            </div>
          )}

          {/* Past First Sessions Side Panel */}
          {showPastSessions && (
            <div className="fixed inset-y-0 right-0 w-96 bg-white shadow-xl z-50 overflow-y-auto">
              <div className="p-6">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-xl font-semibold">Past First Sessions</h3>
                  <button
                    onClick={() => setShowPastSessions(false)}
                    className="text-gray-500 hover:text-gray-700"
                  >
                    ✕
                  </button>
                </div>
                <div className="space-y-4">
                  {fsrsHistory.map((item, index) => (
                    <div key={index} className="border rounded-lg p-4">
                      <div className="flex justify-between items-center mb-2">
                        <span className="font-medium">{item.student_name || 'Unknown Student'}</span>
                        <span className={`px-2 py-1 rounded text-sm ${
                          item.score >= 50 ? 'bg-red-100 text-red-800' :
                          item.score >= 30 ? 'bg-yellow-100 text-yellow-800' :
                          'bg-green-100 text-green-800'
                        }`}>
                          {item.score}
                        </span>
                      </div>
                      <div className="text-sm text-gray-600 mb-2">
                        {formatDate(item.date)}
                      </div>
                      {item.feedback && (
                        <div className="text-sm">
                          <div className="text-green-700 mb-1">
                            <strong>What went well:</strong> {item.feedback.what_went_well || 'N/A'}
                          </div>
                          <div className="text-blue-700">
                            <strong>Improvement:</strong> {item.feedback.improvement_idea || 'N/A'}
                          </div>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Performance Summary Section */}
      {performanceSummary && (
        <div className="mb-8">
          <h2 className="text-2xl font-semibold mb-4">Performance Summary</h2>
          <div className="bg-white rounded-lg shadow-md p-6">
            <p className="text-gray-700 mb-4">{performanceSummary.summary}</p>
            
            {/* SQS Trend Visualization */}
            {sessionList.length > 0 && (
              <div className="mt-4">
                <h3 className="text-lg font-semibold mb-2">SQS Trend</h3>
                <div className="flex items-end gap-2 h-32">
                  {sessionList.slice(0, 10).map((session, index) => {
                    if (!session.sqs) return null
                    const maxSqs = Math.max(...sessionList.map(s => s.sqs || 0), 100)
                    const height = (session.sqs / maxSqs) * 100
                    const sqsLabel = getScoreLabel(session.sqs, 'sqs')
                    const color = sqsLabel.color === 'red' ? 'bg-red-500' : 
                                 sqsLabel.color === 'yellow' ? 'bg-yellow-500' : 'bg-green-500'
                    return (
                      <div key={index} className="flex-1 flex flex-col items-center">
                        <div
                          className={`w-full ${color} rounded-t`}
                          style={{ height: `${height}%` }}
                          title={`SQS: ${session.sqs}`}
                        />
                      </div>
                    )
                  })}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Recent Sessions Table */}
      <div className="mb-8">
        <h2 className="text-2xl font-semibold mb-4">Recent Sessions</h2>
        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Student
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  SQS
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  FSRS Tag
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Notes
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {sessionList.length === 0 ? (
                <tr>
                  <td colSpan="5" className="px-6 py-4 text-center text-gray-500">
                    No sessions found
                  </td>
                </tr>
              ) : (
                sessionList.map((session) => {
                  const sqsLabel = session.sqs ? getScoreLabel(session.sqs, 'sqs') : null
                  return (
                    <tr key={session.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {formatDate(session.date)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {session.student_name}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        {session.sqs ? (
                          <span className={`px-2 py-1 rounded text-sm ${
                            sqsLabel?.color === 'red' ? 'bg-red-100 text-red-800' :
                            sqsLabel?.color === 'yellow' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-green-100 text-green-800'
                          }`}>
                            {session.sqs} ({sqsLabel?.label})
                          </span>
                        ) : (
                          <span className="text-gray-400">N/A</span>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        {session.first_session && session.fsrs ? (
                          <span className={`px-2 py-1 rounded text-sm ${
                            session.fsrs >= 50 ? 'bg-red-100 text-red-800' :
                            session.fsrs >= 30 ? 'bg-yellow-100 text-yellow-800' :
                            'bg-green-100 text-green-800'
                          }`}>
                            FSRS: {session.fsrs}
                          </span>
                        ) : (
                          <span className="text-gray-400">—</span>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {session.first_session ? 'First Session' : '—'}
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

export default TutorDashboard
