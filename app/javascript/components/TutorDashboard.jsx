import React, { useState, useEffect } from 'react'
import { 
  LoadingSpinner, 
  SkeletonDashboard, 
  EmptySessionState, 
  EmptyFSQSState, 
  ErrorState,
  AccessibleButton,
  MobileTable,
  BarChart
} from './ui'

// Hook to detect if screen is desktop size (md breakpoint: 768px+)
const useIsDesktop = () => {
  const [isDesktop, setIsDesktop] = useState(false)

  useEffect(() => {
    const checkIsDesktop = () => {
      setIsDesktop(window.innerWidth >= 768) // md breakpoint
    }

    checkIsDesktop()
    window.addEventListener('resize', checkIsDesktop)
    return () => window.removeEventListener('resize', checkIsDesktop)
  }, [])

  return isDesktop
}

// Tooltip Component with improved accessibility
const Tooltip = ({ text }) => {
  const [show, setShow] = useState(false)
  
  return (
    <div className="relative inline-block">
      <button
        type="button"
        onMouseEnter={() => setShow(true)}
        onMouseLeave={() => setShow(false)}
        onFocus={() => setShow(true)}
        onBlur={() => setShow(false)}
        className="ml-1 text-gray-400 hover:text-gray-600 cursor-help transition-colors focus-ring"
        aria-label="More information"
      >
        <svg className="w-4 h-4 inline-block" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
        </svg>
      </button>
      {show && (
        <div className="absolute z-[9999] w-72 p-3 bg-gray-900 text-white text-sm rounded-lg shadow-lg -top-2 left-6 transform -translate-y-full animate-fade-in">
          <div className="absolute -bottom-2 left-2 w-0 h-0 border-l-8 border-r-8 border-t-8 border-transparent border-t-gray-900"></div>
          {text}
        </div>
      )}
    </div>
  )
}

const TutorDashboard = ({ tutorId }) => {
  const isDesktop = useIsDesktop()
  const [fsqsLatest, setFsqsLatest] = useState(null)
  const [fsqsHistory, setFsqsHistory] = useState([])
  const [performanceSummary, setPerformanceSummary] = useState(null)
  const [sessionList, setSessionList] = useState([])
  const [sqsActionableFeedback, setSqsActionableFeedback] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [showPastSessions, setShowPastSessions] = useState(false)
  const [aiFeedback, setAiFeedback] = useState({}) // { itemType: { loading, data, error } }

  useEffect(() => {
    if (!tutorId) return

    const fetchData = async () => {
      setLoading(true)
      setError(null)
      
      try {
        // Fetch all data in parallel
        const [fsqsLatestRes, fsqsHistoryRes, performanceSummaryRes, sessionListRes, sqsActionableFeedbackRes] = await Promise.all([
          fetch(`/api/tutor/${tutorId}/fsqs_latest`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/fsqs_history`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/performance_summary`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/session_list`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/sqs_actionable_feedback`).catch(() => null)
        ])

        if (fsqsLatestRes?.ok) {
          const data = await fsqsLatestRes.json()
          setFsqsLatest(data)
        }

        if (fsqsHistoryRes?.ok) {
          const data = await fsqsHistoryRes.json()
          setFsqsHistory(data)
        }

        if (performanceSummaryRes?.ok) {
          const data = await performanceSummaryRes.json()
          setPerformanceSummary(data)
        }

        if (sessionListRes?.ok) {
          const data = await sessionListRes.json()
          setSessionList(data)
        }

        if (sqsActionableFeedbackRes?.ok) {
          const data = await sqsActionableFeedbackRes.json()
          setSqsActionableFeedback(data)
        }
      } catch (err) {
        console.error('Error fetching data:', err)
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [tutorId])

  const handleGetAIFeedback = async (itemType) => {
    if (!tutorId) return

    // Set loading state
    setAiFeedback(prev => ({
      ...prev,
      [itemType]: { loading: true, data: null, error: null }
    }))

    try {
      const response = await fetch(`/api/tutor/${tutorId}/ai_feedback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        },
        body: JSON.stringify({ actionable_item_type: itemType })
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || data.message || 'Failed to fetch AI feedback')
      }

      setAiFeedback(prev => ({
        ...prev,
        [itemType]: { loading: false, data: data, error: null }
      }))
    } catch (err) {
      setAiFeedback(prev => ({
        ...prev,
        [itemType]: { loading: false, data: null, error: err.message }
      }))
    }
  }

  const getScoreLabel = (score, scoreType) => {
    if (scoreType === 'fsqs') {
      if (score <= 50) return { label: 'Low Quality', color: 'red' }
      if (score <= 70) return { label: 'Fair', color: 'yellow' }
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
        <ErrorState onRetry={() => window.location.reload()} />
      </div>
    )
  }

  const avgFsqs = calculateAverage(fsqsHistory)
  const improvement = calculateImprovement(fsqsHistory)
  const fsqsLabel = fsqsLatest ? getScoreLabel(fsqsLatest.score, 'fsqs') : null

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto animate-fade-in">
      <header className="mb-6 md:mb-8">
        <h1 className="text-2xl md:text-3xl font-bold text-gray-900">Tutor Dashboard</h1>
        <p className="text-gray-600 mt-1">Track your session quality and student engagement</p>
      </header>

      {/* Active Alert Card - Hidden for now */}
      {/* {activeAlerts && activeAlerts.length > 0 && (
        <section className="mb-6 md:mb-8">
          <div className="bg-red-50 border-l-4 border-red-500 rounded-lg p-4 md:p-6">
            <h2 className="text-lg font-semibold text-red-900 mb-2">Active Alerts</h2>
            ...
          </div>
        </section>
      )} */}

      {/* FSQS Feedback Section */}
      {fsqsLatest ? (
        <section className="mb-6 md:mb-8 animate-slide-in-up">
          <h2 className="text-xl md:text-2xl font-semibold mb-4">First Session Quality Feedback</h2>
          
          <div className="bg-white rounded-lg shadow-md p-4 md:p-6 mb-4 hover-lift">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6 mb-6">
              {/* FSQS Indicator */}
              <div className="md:border-r md:pr-4">
                <div className="text-sm text-gray-600 mb-1">
                  FSQS Score
                  <Tooltip text="First Session Quality Score measures the quality of your initial sessions with new students. A higher score (70-100) indicates strong rapport-building, clear goal-setting, and encouraging communication. Scores below 50 suggest areas to improve such as reducing confusion, using positive language, or providing better session structure." />
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-3xl md:text-4xl font-bold">{fsqsLatest.score}</span>
                  <span className={`px-3 py-1 rounded-full text-sm font-medium transition-colors ${
                    fsqsLabel?.color === 'red' ? 'bg-red-100 text-red-800' :
                    fsqsLabel?.color === 'yellow' ? 'bg-yellow-100 text-yellow-800' :
                    'bg-green-100 text-green-800'
                  }`}>
                    {fsqsLabel?.label}
                  </span>
                </div>
              </div>

              {/* FSQS Trend Summary */}
              <div>
                <div className="text-sm text-gray-600 mb-1">
                  Average FSQS (Last 5)
                  <Tooltip text="This shows your average First Session Quality Score across your last 5 first sessions with new students. The trend indicator (↑ or ↓) compares your recent performance to earlier sessions." />
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-3xl md:text-4xl font-bold">{avgFsqs}</span>
                  
                  {/* Sparkline */}
                  {fsqsHistory.length > 0 && (
                    <svg width="80" height="30" className="flex-shrink-0" aria-label="FSQS trend">
                      <polyline
                        fill="none"
                        stroke={improvement > 0 ? '#10B981' : '#DC2626'}
                        strokeWidth="2"
                        points={fsqsHistory.slice(0, 5).reverse().map((item, index) => {
                          const x = (index / 4) * 80
                          const maxScore = Math.max(...fsqsHistory.slice(0, 5).map(h => h.score || 0), 100)
                          const y = 30 - ((item.score || 0) / maxScore) * 25
                          return `${x},${y}`
                        }).join(' ')}
                      />
                      {fsqsHistory.slice(0, 5).reverse().map((item, index) => {
                        const x = (index / 4) * 80
                        const maxScore = Math.max(...fsqsHistory.slice(0, 5).map(h => h.score || 0), 100)
                        const y = 30 - ((item.score || 0) / maxScore) * 25
                        return (
                          <circle
                            key={index}
                            cx={x}
                            cy={y}
                            r="2"
                            fill={improvement > 0 ? '#10B981' : '#DC2626'}
                          />
                        )
                      })}
                    </svg>
                  )}
                  
                  {improvement && (
                    <span className={`text-sm font-medium transition-colors ${
                      improvement > 0 ? 'text-green-600' : 'text-red-600'
                    }`} aria-label={`${improvement > 0 ? 'Improving' : 'Declining'} by ${Math.abs(improvement)} percent`}>
                      {improvement > 0 ? '↑' : '↓'} {Math.abs(improvement)}%
                    </span>
                  )}
                </div>
              </div>
            </div>

          </div>

          {/* FSQS Trend Visualization */}
          {fsqsHistory.length > 0 && (
            <div className="bg-white rounded-lg shadow-md p-4 md:p-6 mb-4 hover-lift">
              <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-4 gap-2">
                <h3 className="text-lg font-semibold">FSQS Trend</h3>
                <AccessibleButton
                  onClick={() => setShowPastSessions(!showPastSessions)}
                  variant="link"
                  size="sm"
                  ariaLabel="View past first sessions"
                >
                  View Past First Sessions →
                </AccessibleButton>
              </div>
              
              {/* Desktop: Side-by-side layout (Chart left, Feedback/Info right) */}
              <div className="md:grid md:grid-cols-2 md:gap-6">
                {/* Left: Bar Chart - Last 5 First Sessions */}
                <div className="mb-4 md:mb-0">
                  <BarChart
                    data={fsqsHistory.slice(0, 5).map((item, index) => ({
                      value: item.score || 0,
                      label: item.student_name || `Session ${index + 1}`,
                      date: item.date ? formatDate(item.date) : null
                    }))}
                    height={isDesktop ? 471 : 280}
                    showGrid={true}
                    showThresholds={true}
                    thresholds={[
                      { value: 50, color: 'red' },
                      { value: 70, color: 'yellow' }
                    ]}
                    showTooltip={true}
                    formatValue={(v) => Math.round(v)}
                    maxValue={100}
                    minValue={0}
                  />
                  
                  <div className="text-sm text-gray-600 mt-2">
                    Average: <span className="font-semibold">{avgFsqs}</span> {improvement && (
                      <span className={improvement > 0 ? 'text-green-600 font-medium' : 'text-red-600 font-medium'}>
                        • {improvement > 0 ? 'Improving' : 'Declining'} by {Math.abs(improvement)}% vs previous period
                      </span>
                    )}
                  </div>
                </div>

                {/* Right: Educational Content (Desktop only) */}
                <div className="hidden md:block">
                  <div className="flex flex-col space-y-4" style={{ paddingTop: isDesktop ? '30px' : '0' }}>
                    {/* Why FSQS Matters */}
                    <div className="bg-blue-50 rounded-lg p-4 border-l-4 border-blue-500">
                      <h4 className="text-lg font-semibold text-blue-900 mb-2 flex items-center gap-2">
                        <span>📊</span> Why This Score Matters
                      </h4>
                      <p className="text-gray-700 text-sm leading-relaxed">
                        Your First Session Quality Score (FSQS) measures how well you're setting up new students for success. 
                        A strong first session builds trust, sets clear expectations, and creates a positive learning foundation. 
                        Students with great first sessions are more likely to continue and engage actively.
                      </p>
                    </div>

                    {/* How to Improve */}
                    <div className="bg-green-50 rounded-lg p-4 border-l-4 border-green-500">
                      <h4 className="text-lg font-semibold text-green-900 mb-2 flex items-center gap-2">
                        <span>🚀</span> How to Improve Your Score
                      </h4>
                      <ul className="text-gray-700 text-sm space-y-2 leading-relaxed">
                        <li className="flex items-start gap-2">
                          <span className="text-green-600 font-bold mt-0.5">•</span>
                          <span><strong>Set clear goals:</strong> Discuss what the student wants to achieve in the first 5 minutes.</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-green-600 font-bold mt-0.5">•</span>
                          <span><strong>Encourage actively:</strong> Use positive phrases like "Great question!" and "You're doing well!"</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-green-600 font-bold mt-0.5">•</span>
                          <span><strong>Balance the conversation:</strong> Aim for 40-60% student speaking time.</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-green-600 font-bold mt-0.5">•</span>
                          <span><strong>Summarize at the end:</strong> Recap what was covered and what's next.</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-green-600 font-bold mt-0.5">•</span>
                          <span><strong>Avoid confusion:</strong> Watch for student confusion phrases and clarify immediately.</span>
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}


          {/* Past First Sessions Side Panel */}
          {showPastSessions && (
            <>
              {/* Overlay */}
              <div 
                className="fixed inset-0 bg-black bg-opacity-50 z-40 animate-fade-in"
                onClick={() => setShowPastSessions(false)}
                aria-hidden="true"
              />
              
              {/* Side Panel */}
              <aside 
                className="fixed inset-y-0 right-0 w-full sm:w-96 bg-white shadow-2xl z-50 overflow-y-auto animate-slide-in-right"
                role="dialog"
                aria-label="Past first sessions"
              >
                <div className="p-6">
                  <div className="flex justify-between items-center mb-4">
                    <h3 className="text-xl font-semibold">Past First Sessions</h3>
                    <AccessibleButton
                      onClick={() => setShowPastSessions(false)}
                      variant="ghost"
                      size="sm"
                      ariaLabel="Close panel"
                      className="text-gray-500 hover:text-gray-700"
                    >
                      ✕
                    </AccessibleButton>
                  </div>
                  <div className="space-y-4">
                    {fsqsHistory.map((item, index) => (
                      <div key={index} className="border rounded-lg p-4 hover-lift transition-all">
                        <div className="flex justify-between items-center mb-2">
                          <span className="font-medium">{item.student_name || 'Unknown Student'}</span>
                          <span className={`px-2 py-1 rounded text-sm font-medium ${
                            item.score <= 50 ? 'bg-red-100 text-red-800' :
                            item.score <= 70 ? 'bg-yellow-100 text-yellow-800' :
                            'bg-green-100 text-green-800'
                          }`}>
                            {item.score}
                          </span>
                        </div>
                        <div className="text-sm text-gray-600 mb-2">
                          {formatDate(item.date)}
                        </div>
                        {item.feedback && (
                          <div className="text-sm space-y-1">
                            <div className="text-green-700">
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
              </aside>
            </>
          )}
        </section>
      ) : (
        <div className="mb-6 md:mb-8">
          <EmptyFSQSState />
        </div>
      )}

      {/* Performance Summary Section */}
      {performanceSummary && (
        <section className="mb-6 md:mb-8 animate-slide-in-up" style={{ animationDelay: '0.1s' }}>
          <h2 className="text-xl md:text-2xl font-semibold mb-4">Performance Summary</h2>
          <div className="bg-white rounded-lg shadow-md p-4 md:p-6 hover-lift">
            {/* Performance Summary Banner */}
            <div className="bg-gradient-to-r from-blue-50 to-indigo-50 border-l-4 border-blue-500 rounded-lg p-4 md:p-5 mb-4">
              <div className="flex items-start gap-3">
                <div className="flex-shrink-0 mt-0.5">
                  <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div className="flex-1">
                  <h3 className="text-base md:text-lg font-semibold text-blue-900 mb-1">Performance Update</h3>
                  <p className="text-sm md:text-base text-gray-700 leading-relaxed">{performanceSummary.summary}</p>
                </div>
              </div>
            </div>
            
            {/* SQS Trend Visualization */}
            {sessionList.length > 0 && (() => {
              const sessionsWithSqs = sessionList.filter(s => s.sqs !== null && s.sqs !== undefined)
              const totalAvg = sessionsWithSqs.length > 0 
                ? (sessionsWithSqs.reduce((sum, s) => sum + (s.sqs || 0), 0) / sessionsWithSqs.length).toFixed(1)
                : '0.0'
              const last5Sessions = sessionsWithSqs.slice(0, 5)
              const last5Avg = last5Sessions.length > 0
                ? (last5Sessions.reduce((sum, s) => sum + (s.sqs || 0), 0) / last5Sessions.length).toFixed(1)
                : '0.0'
              
              return (
                <div className="mt-4">
                  <h3 className="text-lg font-semibold mb-4">
                    SQS Trend
                    <Tooltip text="Session Quality Score (SQS) tracks the operational quality of your sessions, focusing on punctuality, session duration, and technical reliability. Green bars (75+) indicate smooth sessions, yellow (60-75) shows minor issues, and red (<60) suggests significant problems." />
                  </h3>
                  
                  {/* Metrics on top, Chart full width below */}
                  <div className="space-y-4">
                    {/* Metrics Row */}
                    <div className="flex flex-col md:flex-row gap-4">
                      {/* Total Average */}
                      {(() => {
                        const totalAvgNum = parseFloat(totalAvg)
                        const totalLabel = getScoreLabel(totalAvgNum, 'sqs')
                        const isRed = totalLabel.color === 'red'
                        const isYellow = totalLabel.color === 'yellow'
                        const isGreen = totalLabel.color === 'green'
                        
                        return (
                          <div className={`flex-1 rounded-lg p-4 border-l-4 ${
                            isRed ? 'bg-red-50 border-red-500' :
                            isYellow ? 'bg-yellow-50 border-yellow-500' :
                            'bg-green-50 border-green-500'
                          }`}>
                            <div className={`text-sm font-medium mb-1 ${
                              isRed ? 'text-red-700' :
                              isYellow ? 'text-yellow-700' :
                              'text-green-700'
                            }`}>Total Average</div>
                            <div className={`text-3xl font-bold ${
                              isRed ? 'text-red-900' :
                              isYellow ? 'text-yellow-900' :
                              'text-green-900'
                            }`}>{totalAvg}</div>
                            <div className={`text-xs mt-1 ${
                              isRed ? 'text-red-600' :
                              isYellow ? 'text-yellow-600' :
                              'text-green-600'
                            }`}>{sessionsWithSqs.length} sessions</div>
                          </div>
                        )
                      })()}
                      
                      {/* Last 5 Average */}
                      {(() => {
                        const last5AvgNum = parseFloat(last5Avg)
                        const last5Label = getScoreLabel(last5AvgNum, 'sqs')
                        const isRed = last5Label.color === 'red'
                        const isYellow = last5Label.color === 'yellow'
                        const isGreen = last5Label.color === 'green'
                        
                        return (
                          <div className={`flex-1 rounded-lg p-4 border-l-4 ${
                            isRed ? 'bg-red-50 border-red-500' :
                            isYellow ? 'bg-yellow-50 border-yellow-500' :
                            'bg-green-50 border-green-500'
                          }`}>
                            <div className={`text-sm font-medium mb-1 ${
                              isRed ? 'text-red-700' :
                              isYellow ? 'text-yellow-700' :
                              'text-green-700'
                            }`}>Last 5 Average</div>
                            <div className={`text-3xl font-bold ${
                              isRed ? 'text-red-900' :
                              isYellow ? 'text-yellow-900' :
                              'text-green-900'
                            }`}>{last5Avg}</div>
                            <div className={`text-xs mt-1 ${
                              isRed ? 'text-red-600' :
                              isYellow ? 'text-yellow-600' :
                              'text-green-600'
                            }`}>Last {last5Sessions.length} sessions</div>
                          </div>
                        )
                      })()}
                    </div>
                  </div>
                </div>
              )
            })()}

            {/* Actionable Items Section */}
            {sqsActionableFeedback && (
              <div className="mt-4">
                <h3 className="text-lg font-semibold mb-4">Actionable Items</h3>
                {sqsActionableFeedback.perfect ? (
                  <div className="bg-gradient-to-r from-green-50 to-emerald-50 rounded-lg p-6 md:p-8 border-l-4 border-green-500">
                    <div className="flex flex-col md:flex-row items-center md:items-start gap-4">
                      <div className="text-6xl md:text-8xl">🎉</div>
                      <div className="flex-1">
                        <h4 className="text-xl md:text-2xl font-bold text-green-900 mb-2">
                          Fantastic Job!
                        </h4>
                        <p className="text-base md:text-lg text-gray-700 leading-relaxed">
                          {sqsActionableFeedback.message}
                        </p>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {sqsActionableFeedback.items.map((item, index) => (
                      <div
                        key={index}
                        className={`rounded-lg p-4 md:p-5 border-l-4 ${
                          item.priority === 'high'
                            ? 'bg-red-50 border-red-500'
                            : 'bg-yellow-50 border-yellow-500'
                        } animate-slide-in-up`}
                        style={{ animationDelay: `${index * 0.1}s` }}
                      >
                        <div className="flex items-start gap-3">
                          <div className="text-3xl flex-shrink-0">{item.icon}</div>
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-2">
                              <h4 className="text-lg font-semibold text-gray-900">
                                {item.title}
                              </h4>
                              {item.priority === 'high' && (
                                <span className="px-2 py-1 bg-red-100 text-red-800 rounded text-xs font-medium">
                                  High Priority
                                </span>
                              )}
                            </div>
                            <p className="text-sm md:text-base text-gray-700 mb-3 leading-relaxed">
                              {item.description}
                            </p>
                            <div className="bg-white rounded-lg p-3 border border-gray-200">
                              <p className="text-sm font-medium text-gray-900 mb-1">💡 Action:</p>
                              <p className="text-sm text-gray-700 leading-relaxed">{item.action}</p>
                            </div>
                            
                            {/* Get AI Feedback Button */}
                            <div className="mt-4">
                              <button
                                onClick={() => handleGetAIFeedback(item.type)}
                                disabled={aiFeedback[item.type]?.loading}
                                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors text-sm font-medium flex items-center gap-2"
                              >
                                {aiFeedback[item.type]?.loading ? (
                                  <>
                                    <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                    </svg>
                                    Generating...
                                  </>
                                ) : (
                                  <>
                                    <span>✨</span>
                                    Get AI Feedback
                                  </>
                                )}
                              </button>
                            </div>

                            {/* AI Feedback Display */}
                            {aiFeedback[item.type]?.data && (
                              <div className="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
                                <h5 className="font-semibold text-blue-900 mb-3 flex items-center gap-2">
                                  <span>🤖</span>
                                  AI-Powered Feedback
                                </h5>
                                {aiFeedback[item.type].data.fallback && (
                                  <div className="mb-3 text-xs text-blue-700 bg-blue-100 px-2 py-1 rounded">
                                    Note: Using fallback feedback (AI service unavailable)
                                  </div>
                                )}
                                <div className="space-y-4">
                                  {aiFeedback[item.type].data.moments?.map((moment, idx) => (
                                    <div key={idx} className="bg-white rounded p-3 border border-blue-100">
                                      <div className="flex items-start gap-2 mb-2">
                                        <span className="font-semibold text-blue-900">{moment.student_name}</span>
                                        {moment.session_date && (
                                          <span className="text-xs text-gray-500">
                                            {moment.session_date} {moment.session_time || ''}
                                          </span>
                                        )}
                                      </div>
                                      <p className="text-sm text-gray-700 mb-2">
                                        <span className="font-medium">Context:</span> {moment.context}
                                      </p>
                                      <p className="text-sm text-blue-800 mb-2">
                                        <span className="font-medium">💡 Suggestion:</span> "{moment.suggestion}"
                                      </p>
                                      <p className="text-xs text-gray-600 italic">
                                        <span className="font-medium">Why:</span> {moment.reason}
                                      </p>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            )}

                            {/* AI Feedback Error */}
                            {aiFeedback[item.type]?.error && (
                              <div className="mt-4 bg-red-50 border border-red-200 rounded-lg p-3">
                                <p className="text-sm text-red-700">
                                  {aiFeedback[item.type].error === 'rate_limit_exceeded'
                                    ? 'You have reached the daily limit of 5 AI feedback requests. Please try again tomorrow.'
                                    : aiFeedback[item.type].error === 'insufficient_sessions'
                                    ? 'We need at least 5 completed sessions with transcripts to generate AI feedback.'
                                    : 'Unable to generate AI feedback. Please try again later.'}
                                </p>
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </section>
      )}

      {/* Recent Sessions Table */}
      <section className="mb-6 md:mb-8 animate-slide-in-up" style={{ animationDelay: '0.2s' }}>
        <h2 className="text-xl md:text-2xl font-semibold mb-4">Recent Sessions</h2>
        <div className="bg-white md:rounded-lg md:shadow-md overflow-hidden">
          <MobileTable
            data={sessionList}
            keyExtractor={(session) => session.id}
            emptyState={<EmptySessionState />}
            defaultSort={{ column: 'date', direction: 'desc' }}
            columns={[
              {
                key: 'date',
                label: 'Date',
                sortable: true,
                render: (session) => (
                  <span className="whitespace-nowrap">{formatDate(session.date)}</span>
                )
              },
              {
                key: 'student_name',
                label: 'Student',
                sortable: true,
                render: (session) => session.student_name
              },
              {
                key: 'sqs',
                label: 'SQS',
                sortable: true,
                render: (session) => {
                  if (!session.sqs) return <span className="text-gray-400">N/A</span>
                  const sqsLabel = getScoreLabel(session.sqs, 'sqs')
                  return (
                    <span className={`inline-flex px-2 py-1 rounded text-xs sm:text-sm font-medium transition-colors ${
                      sqsLabel?.color === 'red' ? 'bg-red-100 text-red-800' :
                      sqsLabel?.color === 'yellow' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-green-100 text-green-800'
                    }`}>
                      {session.sqs} ({sqsLabel?.label})
                    </span>
                  )
                }
              },
              {
                key: 'fsqs',
                label: 'FSQS Tag',
                sortable: true,
                render: (session) => {
                  if (session.first_session && session.fsqs) {
                    return (
                      <span className={`inline-flex px-2 py-1 rounded text-xs sm:text-sm font-medium transition-colors ${
                        session.fsqs <= 50 ? 'bg-red-100 text-red-800' :
                        session.fsqs <= 70 ? 'bg-yellow-100 text-yellow-800' :
                        'bg-green-100 text-green-800'
                      }`}>
                        FSQS: {session.fsqs}
                      </span>
                    )
                  }
                  return <span className="text-gray-400">—</span>
                }
              },
              {
                key: 'first_session',
                label: 'Notes',
                sortable: true,
                render: (session) => {
                  if (session.first_session) {
                    return (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                        First Session
                      </span>
                    )
                  }
                  return '—'
                }
              }
            ]}
          />
        </div>
      </section>
    </div>
  )
}

export default TutorDashboard
