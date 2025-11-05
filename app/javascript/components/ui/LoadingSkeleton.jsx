import React from 'react'

// Base skeleton component with shimmer animation
const SkeletonBase = ({ className = '', width, height }) => (
  <div
    className={`animate-pulse bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 bg-[length:200%_100%] rounded ${className}`}
    style={{
      width: width || '100%',
      height: height || 'auto',
      animation: 'shimmer 1.5s infinite'
    }}
  />
)

// Card skeleton for metric cards
export const SkeletonCard = () => (
  <div className="bg-white rounded-lg shadow-md p-6 space-y-3">
    <SkeletonBase height="24px" width="60%" />
    <SkeletonBase height="40px" width="40%" />
    <SkeletonBase height="16px" width="80%" />
  </div>
)

// Table row skeleton
export const SkeletonTableRow = ({ columns = 5 }) => (
  <tr className="border-b border-gray-200">
    {Array.from({ length: columns }).map((_, i) => (
      <td key={i} className="px-4 py-3">
        <SkeletonBase height="20px" />
      </td>
    ))}
  </tr>
)

// Dashboard skeleton for full page loading
export const SkeletonDashboard = () => (
  <div className="space-y-6 animate-fade-in">
    {/* Header */}
    <div className="space-y-2">
      <SkeletonBase height="32px" width="300px" />
      <SkeletonBase height="20px" width="200px" />
    </div>

    {/* Metric cards */}
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <SkeletonCard />
      <SkeletonCard />
      <SkeletonCard />
    </div>

    {/* Table */}
    <div className="bg-white rounded-lg shadow-md p-6">
      <SkeletonBase height="24px" width="200px" className="mb-4" />
      <div className="space-y-3">
        <SkeletonBase height="40px" />
        <SkeletonBase height="40px" />
        <SkeletonBase height="40px" />
        <SkeletonBase height="40px" />
      </div>
    </div>
  </div>
)

// Inline skeleton for small elements
export const SkeletonInline = ({ width = '100px' }) => (
  <SkeletonBase height="20px" width={width} className="inline-block" />
)

export default SkeletonBase

