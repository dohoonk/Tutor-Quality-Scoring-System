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
        <div className="absolute z-50 w-72 p-3 bg-gray-900 text-white text-sm rounded-lg shadow-lg -top-2 left-6 transform -translate-y-full animate-fade-in">
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
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [showPastSessions, setShowPastSessions] = useState(false)

  useEffect(() => {
    if (!tutorId) return

    const fetchData = async () => {
      setLoading(true)
      setError(null)
      
      try {
        // Fetch all data in parallel
        const [fsqsLatestRes, fsqsHistoryRes, performanceSummaryRes, sessionListRes] = await Promise.all([
          fetch(`/api/tutor/${tutorId}/fsqs_latest`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/fsqs_history`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/performance_summary`).catch(() => null),
          fetch(`/api/tutor/${tutorId}/session_list`).catch(() => null)
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
      } catch (err) {
        console.error('Error fetching data:', err)
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [tutorId])

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

                {/* Right: Feedback & Educational Content (Desktop only) */}
                <div className="hidden md:block">
                  <div className="flex flex-col space-y-4" style={{ paddingTop: isDesktop ? '30px' : '0' }}>
                    {/* What Went Well - Feedback */}
                    {fsqsLatest.feedback?.what_went_well && (
                      <div className="bg-green-50 rounded-lg p-4 border-l-4 border-green-500">
                        <h4 className="text-lg font-semibold text-green-700 mb-2 flex items-center gap-2">
                          <span>✓</span> What Went Well
                        </h4>
                        <p className="text-gray-700 text-sm leading-relaxed">{fsqsLatest.feedback.what_went_well}</p>
                      </div>
                    )}

                    {/* One Improvement Idea - Feedback */}
                    {fsqsLatest.feedback?.improvement_idea && (
                      <div className="bg-blue-50 rounded-lg p-4 border-l-4 border-blue-500">
                        <h4 className="text-lg font-semibold text-blue-700 mb-2 flex items-center gap-2">
                          <span>💡</span> One Improvement Idea
                        </h4>
                        <p className="text-gray-700 text-sm leading-relaxed">{fsqsLatest.feedback.improvement_idea}</p>
                      </div>
                    )}

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

          {/* Mobile: Feedback sections (shown below chart on mobile) */}
          <div className="md:hidden space-y-4 mb-4">
            {/* What Went Well */}
            {fsqsLatest.feedback?.what_went_well && (
              <div className="p-4 bg-green-50 rounded-lg border-l-4 border-green-500">
                <h3 className="text-lg font-semibold text-green-700 mb-2 flex items-center gap-2">
                  <span>✓</span> What Went Well
                </h3>
                <p className="text-gray-700">{fsqsLatest.feedback.what_went_well}</p>
              </div>
            )}

            {/* One Improvement Idea */}
            {fsqsLatest.feedback?.improvement_idea && (
              <div className="p-4 bg-blue-50 rounded-lg border-l-4 border-blue-500">
                <h3 className="text-lg font-semibold text-blue-700 mb-2 flex items-center gap-2">
                  <span>💡</span> One Improvement Idea
                </h3>
                <p className="text-gray-700">{fsqsLatest.feedback.improvement_idea}</p>
              </div>
            )}
          </div>

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
              const last10Sessions = sessionsWithSqs.slice(0, 10)
              const last10Avg = last10Sessions.length > 0
                ? (last10Sessions.reduce((sum, s) => sum + (s.sqs || 0), 0) / last10Sessions.length).toFixed(1)
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
                      
                      {/* Last 10 Average */}
                      {(() => {
                        const last10AvgNum = parseFloat(last10Avg)
                        const last10Label = getScoreLabel(last10AvgNum, 'sqs')
                        const isRed = last10Label.color === 'red'
                        const isYellow = last10Label.color === 'yellow'
                        const isGreen = last10Label.color === 'green'
                        
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
                            }`}>Last 10 Average</div>
                            <div className={`text-3xl font-bold ${
                              isRed ? 'text-red-900' :
                              isYellow ? 'text-yellow-900' :
                              'text-green-900'
                            }`}>{last10Avg}</div>
                            <div className={`text-xs mt-1 ${
                              isRed ? 'text-red-600' :
                              isYellow ? 'text-yellow-600' :
                              'text-green-600'
                            }`}>Last {last10Sessions.length} sessions</div>
                          </div>
                        )
                      })()}
                    </div>
                    
                    {/* Chart - Full Width */}
                    <div className="flex items-end gap-1 md:gap-2 h-32 w-full">
                      {sessionList.slice(0, 10).map((session, index) => {
                        if (!session.sqs) return null
                        const maxSqs = Math.max(...sessionList.map(s => s.sqs || 0), 100)
                        const height = (session.sqs / maxSqs) * 100
                        const sqsLabel = getScoreLabel(session.sqs, 'sqs')
                        const color = sqsLabel.color === 'red' ? 'bg-red-500' : 
                                     sqsLabel.color === 'yellow' ? 'bg-yellow-500' : 'bg-green-500'
                        return (
                          <div key={index} className="flex-1 flex flex-col items-center group">
                            <div
                              className={`w-full ${color} rounded-t transition-all hover:opacity-80`}
                              style={{ height: `${height}%` }}
                              title={`SQS: ${session.sqs}`}
                              aria-label={`Session ${index + 1}: SQS ${session.sqs}`}
                            />
                          </div>
                        )
                      })}
                    </div>
                  </div>
                </div>
              )
            })()}
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
            columns={[
              {
                key: 'date',
                label: 'Date',
                render: (session) => (
                  <span className="whitespace-nowrap">{formatDate(session.date)}</span>
                )
              },
              {
                key: 'student_name',
                label: 'Student',
                render: (session) => session.student_name
              },
              {
                key: 'sqs',
                label: 'SQS',
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
                key: 'notes',
                label: 'Notes',
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
