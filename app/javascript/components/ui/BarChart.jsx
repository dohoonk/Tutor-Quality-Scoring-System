import React, { useState } from 'react'

/**
 * BarChart - Responsive bar chart for discrete data points
 * 
 * Props:
 * - data: Array of { value, label?, date? } objects
 * - height: Chart height in pixels (default: 200)
 * - showGrid: Show grid lines (default: true)
 * - showThresholds: Show color-coded threshold zones (default: true)
 * - thresholds: Array of { value, color } for zones (default: [{50, 'red'}, {70, 'yellow'}])
 * - getBarColor: Function to get bar color based on value (default: color by thresholds)
 * - showTooltip: Show tooltip on hover (default: true)
 * - formatValue: Function to format values (default: (v) => v)
 * - maxValue: Maximum value for scaling (default: null = auto)
 * - minValue: Minimum value for scaling (default: 0)
 */
const BarChart = ({
  data = [],
  height = 200,
  showGrid = true,
  showThresholds = true,
  thresholds = [
    { value: 50, color: 'red' },
    { value: 70, color: 'yellow' }
  ],
  getBarColor = null, // Custom function or null for default
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
  const padding = { top: 20, right: 20, bottom: 50, left: 40 }
  const chartWidth = 800 // Fixed width for viewBox, scales responsively
  const chartHeight = height
  const innerWidth = chartWidth - padding.left - padding.right
  const innerHeight = chartHeight - padding.top - padding.bottom

  // Get value range
  const values = data.map(d => d.value || 0)
  const max = maxValue !== null ? maxValue : Math.max(...values, 100)
  const min = minValue

  // Calculate bar dimensions
  const barCount = data.length
  // Use a more reasonable bar width: smaller percentage for fewer bars, cap at max width
  const maxBarWidth = 80 // Maximum bar width for desktop
  const minBarWidth = 20 // Minimum bar width for mobile
  const calculatedWidth = (innerWidth / barCount) * 0.4 // 40% of available space per bar
  const barWidth = Math.max(minBarWidth, Math.min(maxBarWidth, calculatedWidth))
  const barSpacing = (innerWidth - (barWidth * barCount)) / (barCount + 1)

  // Default color function
  const defaultGetBarColor = (value) => {
    if (value <= thresholds[0]?.value) return '#EF4444' // red-500
    if (value <= thresholds[1]?.value) return '#EAB308' // yellow-500
    return '#10B981' // green-500
  }

  const getColor = getBarColor || defaultGetBarColor

  // Calculate bar positions
  const bars = data.map((item, index) => {
    const normalizedValue = ((item.value || 0) - min) / (max - min || 1)
    const barHeight = normalizedValue * innerHeight
    const x = padding.left + barSpacing + (index * (barWidth + barSpacing))
    const y = padding.top + innerHeight - barHeight

    return {
      x,
      y,
      width: barWidth,
      height: barHeight,
      value: item.value || 0,
      label: item.label,
      date: item.date,
      index,
      color: getColor(item.value || 0)
    }
  })

  // Grid lines
  const gridLines = showGrid ? [0, 25, 50, 75, 100].filter(v => v >= min && v <= max).map(value => {
    const normalizedValue = (value - min) / (max - min || 1)
    const y = padding.top + innerHeight - (normalizedValue * innerHeight)
    return { value, y }
  }) : []

  // Threshold zones (if enabled)
  const thresholdZones = showThresholds ? thresholds.map((threshold, idx) => {
    const prevThreshold = idx > 0 ? thresholds[idx - 1].value : min
    const thresholdY = padding.top + innerHeight - (((threshold.value - min) / (max - min || 1)) * innerHeight)
    const prevY = padding.top + innerHeight - (((prevThreshold - min) / (max - min || 1)) * innerHeight)
    
    return {
      value: threshold.value,
      color: threshold.color === 'red' ? 'rgba(239, 68, 68, 0.1)' :
             threshold.color === 'yellow' ? 'rgba(234, 179, 8, 0.1)' :
             'rgba(34, 197, 94, 0.1)',
      y: thresholdY,
      prevY: prevY
    }
  }).reverse() : []

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
          <rect
            key={idx}
            x={padding.left}
            y={zone.y}
            width={innerWidth}
            height={zone.prevY - zone.y}
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

        {/* Bars */}
        {bars.map((bar, idx) => {
          const isHovered = hoveredIndex === idx
          return (
            <g key={idx}>
              {/* Hover area (larger for easier interaction) */}
              <rect
                x={bar.x - 5}
                y={padding.top}
                width={bar.width + 10}
                height={innerHeight}
                fill="transparent"
                onMouseEnter={() => setHoveredIndex(idx)}
                className="cursor-pointer"
              />
              
              {/* Bar */}
              <rect
                x={bar.x}
                y={bar.y}
                width={bar.width}
                height={bar.height}
                fill={bar.color}
                rx="4"
                className="transition-all"
                style={{
                  opacity: isHovered ? 0.9 : 1,
                  transform: isHovered ? 'scale(1.05)' : 'scale(1)',
                  transformOrigin: `${bar.x + bar.width / 2} ${bar.y + bar.height}`
                }}
              />
              
              {/* Value label on bar (if space permits) */}
              {bar.height > 20 && (
                <text
                  x={bar.x + bar.width / 2}
                  y={bar.y - 5}
                  textAnchor="middle"
                  fontSize="11"
                  fill={bar.color}
                  fontWeight="600"
                >
                  {formatValue(bar.value)}
                </text>
              )}

              {/* Hover tooltip */}
              {showTooltip && isHovered && (
                <g>
                  {/* Tooltip background */}
                  <rect
                    x={bar.x + bar.width / 2 - 40}
                    y={bar.y - 35}
                    width="80"
                    height="25"
                    rx="4"
                    fill="rgba(0, 0, 0, 0.8)"
                  />
                  {/* Tooltip text */}
                  <text
                    x={bar.x + bar.width / 2}
                    y={bar.y - 18}
                    textAnchor="middle"
                    fontSize="11"
                    fill="white"
                    fontWeight="bold"
                  >
                    {formatValue(bar.value)}
                  </text>
                  {/* Tooltip label */}
                  {bar.label && (
                    <text
                      x={bar.x + bar.width / 2}
                      y={bar.y - 8}
                      textAnchor="middle"
                      fontSize="9"
                      fill="#d1d5db"
                    >
                      {bar.label}
                    </text>
                  )}
                  {/* Tooltip arrow */}
                  <polygon
                    points={`${bar.x + bar.width / 2 - 5},${bar.y - 10} ${bar.x + bar.width / 2 + 5},${bar.y - 10} ${bar.x + bar.width / 2},${bar.y - 5}`}
                    fill="rgba(0, 0, 0, 0.8)"
                  />
                </g>
              )}

              {/* X-axis label */}
              <text
                x={bar.x + bar.width / 2}
                y={innerHeight + padding.top + 15}
                textAnchor="middle"
                fontSize="10"
                fill="#6b7280"
                className="truncate"
              >
                {bar.date || bar.label || `#${idx + 1}`}
              </text>
            </g>
          )
        })}
      </svg>

      {/* Legend for thresholds (mobile-friendly) */}
      {showThresholds && (
        <div className="flex flex-wrap gap-3 mt-2 text-xs text-gray-600">
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-red-500"></div>
            <span>Low (≤50)</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-yellow-500"></div>
            <span>Fair (51-70)</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-green-500"></div>
            <span>Good (>70)</span>
          </div>
        </div>
      )}
    </div>
  )
}

export default BarChart

