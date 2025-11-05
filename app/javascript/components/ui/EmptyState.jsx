import React from 'react'

const EmptyState = ({ 
  icon = '📭',
  title = 'No data found',
  description = 'There is no data to display at this time.',
  action = null,
  className = ''
}) => {
  return (
    <div className={`flex flex-col items-center justify-center py-12 px-4 text-center ${className}`}>
      <div className="text-6xl mb-4">{icon}</div>
      <h3 className="text-xl font-semibold text-gray-900 mb-2">{title}</h3>
      <p className="text-gray-500 mb-6 max-w-md">{description}</p>
      {action && (
        <div className="mt-4">
          {action}
        </div>
      )}
    </div>
  )
}

// Specific empty states for common scenarios
export const EmptySessionState = () => (
  <EmptyState
    icon="📅"
    title="No sessions yet"
    description="You don't have any completed sessions yet. Your session scores will appear here once you complete your first session."
  />
)

export const EmptyFSQSState = () => (
  <EmptyState
    icon="🎯"
    title="No first session data"
    description="You haven't completed any first sessions with new students yet. Your first session quality scores will appear here."
  />
)

export const EmptyAlertState = () => (
  <EmptyState
    icon="✅"
    title="No active alerts"
    description="Great! There are no active alerts at this time. All tutors are performing well."
  />
)

export const ErrorState = ({ onRetry }) => (
  <EmptyState
    icon="⚠️"
    title="Something went wrong"
    description="We couldn't load the data. Please try again."
    action={
      onRetry && (
        <button
          onClick={onRetry}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          Try Again
        </button>
      )
    }
  />
)

export default EmptyState

