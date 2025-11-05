import React, { useState } from 'react'

/**
 * LineChart - Responsive line chart component for trend visualization
 * 
 * Props:
 * - data: Array of { value, label?, date? } objects
 * - height: Chart height in pixels (default: 200)
 * - showGrid: Show grid lines (default: true)
 * - showThresholds: Show color-coded threshold zones (default: true)
 * - thresholds: Array of { value, color } for zones (default: [{50, 'red'}, {70, 'yellow'}])
 * - color: Line color (default: 'blue')
 * - showPoints: Show data point circles (default: true)
 * - showTooltip: Show tooltip on hover (default: true)
 * - formatValue: Function to format values (default: (v) => v)
 */
const LineChart = ({
  data = [],
  height = 200,
  showGrid = true,
  showThresholds = true,
  thresholds = [
    { value: 50, color: 'red' },
    { value: 70, color: 'yellow' }
  ],
  color = '#3B82F6', // blue-500
  showPoints = true,
  showTooltip = true,
  formatValue = (v) => v,
  maxValue = null,
  minValue = 0
}) => {
  const [hoveredIndex, setHoveredIndex] = useState(null)

  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-48 text-gray-400">
        <p>No data available</p>
      </div>
    )
  }

  // Calculate chart dimensions
  const padding = { top: 20, right: 20, bottom: 30, left: 40 }
  const chartWidth = 100 // Percentage-based for responsiveness
  const chartHeight = height
  const innerWidth = chartWidth - padding.left - padding.right
  const innerHeight = chartHeight - padding.top - padding.bottom

  // Get value range
  const values = data.map(d => d.value || 0)
  const max = maxValue !== null ? maxValue : Math.max(...values, 100)
  const min = minValue

  // Calculate points
  const points = data.map((item, index) => {
    const x = (index / (data.length - 1 || 1)) * innerWidth + padding.left
    const normalizedValue = ((item.value || 0) - min) / (max - min || 1)
    const y = innerHeight - (normalizedValue * innerHeight) + padding.top
    return { x, y, value: item.value, label: item.label, date: item.date, index }
  })

  // Create path for line
  const pathData = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.y}`).join(' ')

  // Threshold zones (if enabled)
  const thresholdZones = showThresholds ? thresholds.map((threshold, idx) => {
    const prevThreshold = idx > 0 ? thresholds[idx - 1].value : min
    const thresholdY = innerHeight - (((threshold.value - min) / (max - min || 1)) * innerHeight) + padding.top
    const prevY = innerHeight - (((prevThreshold - min) / (max - min || 1)) * innerHeight) + padding.top
    
    return {
      value: threshold.value,
      color: threshold.color === 'red' ? 'rgba(239, 68, 68, 0.1)' :
             threshold.color === 'yellow' ? 'rgba(234, 179, 8, 0.1)' :
             'rgba(34, 197, 94, 0.1)',
      path: `M ${padding.left} ${thresholdY} L ${innerWidth + padding.left} ${thresholdY} L ${innerWidth + padding.left} ${prevY} L ${padding.left} ${prevY} Z`
    }
  }).reverse() : []

  // Grid lines
  const gridLines = showGrid ? [0, 25, 50, 75, 100].filter(v => v >= min && v <= max).map(value => {
    const y = innerHeight - (((value - min) / (max - min || 1)) * innerHeight) + padding.top
    return { value, y }
  }) : []

  return (
    <div className="relative w-full">
      <svg
        viewBox={`0 0 ${chartWidth} ${chartHeight}`}
        preserveAspectRatio="none"
        className="w-full h-full"
        style={{ height: `${height}px` }}
        onMouseLeave={() => setHoveredIndex(null)}
      >
        {/* Threshold zones */}
        {thresholdZones.map((zone, idx) => (
          <path
            key={idx}
            d={zone.path}
            fill={zone.color}
            opacity="0.3"
          />
        ))}

        {/* Grid lines */}
        {gridLines.map((line, idx) => (
          <g key={idx}>
            <line
              x1={padding.left}
              y1={line.y}
              x2={innerWidth + padding.left}
              y2={line.y}
              stroke="#e5e7eb"
              strokeWidth="1"
              strokeDasharray="4 4"
            />
            <text
              x={padding.left - 5}
              y={line.y + 4}
              textAnchor="end"
              fontSize="10"
              fill="#6b7280"
            >
              {line.value}
            </text>
          </g>
        ))}

        {/* Line */}
        <path
          d={pathData}
          fill="none"
          stroke={color}
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="transition-all"
        />

        {/* Data points */}
        {showPoints && points.map((point, idx) => {
          const isHovered = hoveredIndex === idx
          return (
            <g key={idx}>
              {/* Hover area (larger for easier interaction) */}
              <circle
                cx={point.x}
                cy={point.y}
                r="8"
                fill="transparent"
                onMouseEnter={() => setHoveredIndex(idx)}
                className="cursor-pointer"
              />
              
              {/* Point circle */}
              <circle
                cx={point.x}
                cy={point.y}
                r={isHovered ? "5" : "4"}
                fill={color}
                stroke="white"
                strokeWidth="2"
                className="transition-all"
              />
              
              {/* Hover tooltip */}
              {showTooltip && isHovered && (
                <g>
                  {/* Tooltip background */}
                  <rect
                    x={point.x - 30}
                    y={point.y - 35}
                    width="60"
                    height="25"
                    rx="4"
                    fill="rgba(0, 0, 0, 0.8)"
                  />
                  {/* Tooltip text */}
                  <text
                    x={point.x}
                    y={point.y - 18}
                    textAnchor="middle"
                    fontSize="11"
                    fill="white"
                    fontWeight="bold"
                  >
                    {formatValue(point.value)}
                  </text>
                  {/* Tooltip label */}
                  {point.label && (
                    <text
                      x={point.x}
                      y={point.y - 8}
                      textAnchor="middle"
                      fontSize="9"
                      fill="#d1d5db"
                    >
                      {point.label}
                    </text>
                  )}
                  {/* Tooltip arrow */}
                  <polygon
                    points={`${point.x - 5},${point.y - 10} ${point.x + 5},${point.y - 10} ${point.x},${point.y - 5}`}
                    fill="rgba(0, 0, 0, 0.8)"
                  />
                </g>
              )}
            </g>
          )
        })}

        {/* X-axis labels */}
        {data.length <= 10 && points.map((point, idx) => {
          if (idx % Math.ceil(data.length / 5) === 0 || idx === data.length - 1) {
            return (
              <text
                key={idx}
                x={point.x}
                y={innerHeight + padding.top + 15}
                textAnchor="middle"
                fontSize="10"
                fill="#6b7280"
              >
                {point.date || `#${idx + 1}`}
              </text>
            )
          }
          return null
        })}
      </svg>

      {/* Legend for thresholds (mobile-friendly) */}
      {showThresholds && (
        <div className="flex flex-wrap gap-3 mt-2 text-xs text-gray-600">
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-red-100"></div>
            <span>Low (≤50)</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-yellow-100"></div>
            <span>Fair (51-70)</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-green-100"></div>
            <span>Good (>70)</span>
          </div>
        </div>
      )}
    </div>
  )
}

export default LineChart

