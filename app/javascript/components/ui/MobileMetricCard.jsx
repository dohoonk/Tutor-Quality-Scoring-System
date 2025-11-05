import React from 'react'

/**
 * MobileMetricCard - Responsive metric display optimized for mobile
 * Stacks vertically on small screens, horizontal on larger screens
 */
const MobileMetricCard = ({ 
  title, 
  value, 
  subtitle, 
  icon, 
  color = 'blue',
  trend = null, // { value: number, isPositive: boolean, label: string }
  className = ''
}) => {
  const colorStyles = {
    blue: 'bg-blue-50 border-blue-200 text-blue-800',
    green: 'bg-green-50 border-green-200 text-green-800',
    red: 'bg-red-50 border-red-200 text-red-800',
    yellow: 'bg-yellow-50 border-yellow-200 text-yellow-800',
    gray: 'bg-gray-50 border-gray-200 text-gray-800',
  }

  return (
    <div className={`bg-white rounded-lg shadow-md p-4 hover-lift border-l-4 ${colorStyles[color]} ${className}`}>
      <div className="flex flex-col space-y-2">
        {/* Title with icon */}
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-medium text-gray-600 truncate flex-1">
            {title}
          </h3>
          {icon && <span className="text-2xl ml-2 flex-shrink-0">{icon}</span>}
        </div>

        {/* Value */}
        <div className="flex items-baseline justify-between">
          <span className="text-3xl sm:text-4xl font-bold text-gray-900">
            {value}
          </span>
          
          {/* Trend indicator */}
          {trend && (
            <div className={`flex items-center text-sm font-medium ${
              trend.isPositive ? 'text-green-600' : 'text-red-600'
            }`}>
              <span className="text-lg mr-1">
                {trend.isPositive ? '↑' : '↓'}
              </span>
              <span>{Math.abs(trend.value)}%</span>
            </div>
          )}
        </div>

        {/* Subtitle */}
        {subtitle && (
          <p className="text-xs sm:text-sm text-gray-500">
            {subtitle}
          </p>
        )}

        {/* Trend label */}
        {trend && trend.label && (
          <p className="text-xs text-gray-500">
            {trend.label}
          </p>
        )}
      </div>
    </div>
  )
}

/**
 * MobileMetricGrid - Grid container for metric cards
 * Responsive: 1 column on mobile, 2 on tablet, 3 on desktop
 */
export const MobileMetricGrid = ({ children, columns = 3 }) => {
  const gridCols = {
    2: 'sm:grid-cols-2',
    3: 'sm:grid-cols-2 lg:grid-cols-3',
    4: 'sm:grid-cols-2 lg:grid-cols-4'
  }

  return (
    <div className={`grid grid-cols-1 ${gridCols[columns]} gap-4`}>
      {children}
    </div>
  )
}

export default MobileMetricCard

