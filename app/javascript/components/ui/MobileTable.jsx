import React, { useState, useMemo } from 'react'

/**
 * MobileTable - Responsive table that shows as cards on mobile
 * 
 * Props:
 * - data: Array of objects to display
 * - columns: Array of column definitions { key, label, render?, sortable? }
 * - keyExtractor: Function to extract unique key from each row
 * - emptyState: Component to show when data is empty
 * - defaultSort: { column: string, direction: 'asc' | 'desc' }
 */
const MobileTable = ({ 
  data = [], 
  columns = [], 
  keyExtractor = (item, index) => index,
  emptyState = null,
  mobileBreakpoint = 'md', // sm, md, lg
  defaultSort = { column: null, direction: 'asc' }
}) => {
  const [sortColumn, setSortColumn] = useState(defaultSort.column)
  const [sortDirection, setSortDirection] = useState(defaultSort.direction)

  // Sort data
  const sortedData = useMemo(() => {
    if (!sortColumn) return data

    return [...data].sort((a, b) => {
      let aVal = a[sortColumn]
      let bVal = b[sortColumn]

      // Handle null values
      if (aVal === null || aVal === undefined) return 1
      if (bVal === null || bVal === undefined) return -1

      // Handle date strings
      if (typeof aVal === 'string' && typeof bVal === 'string') {
        const aDate = new Date(aVal)
        const bDate = new Date(bVal)
        if (!isNaN(aDate.getTime()) && !isNaN(bDate.getTime())) {
          return sortDirection === 'asc' 
            ? aDate - bDate
            : bDate - aDate
        }
      }

      // String comparison
      if (typeof aVal === 'string' && typeof bVal === 'string') {
        aVal = aVal.toLowerCase()
        bVal = bVal.toLowerCase()
        return sortDirection === 'asc' 
          ? aVal.localeCompare(bVal)
          : bVal.localeCompare(aVal)
      }

      // Numeric comparison
      return sortDirection === 'asc' ? aVal - bVal : bVal - aVal
    })
  }, [data, sortColumn, sortDirection])

  const handleSort = (column) => {
    if (sortColumn === column) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      setSortColumn(column)
      setSortDirection('asc')
    }
  }
  if (data.length === 0 && emptyState) {
    return emptyState
  }

  const breakpointClass = {
    sm: 'sm:hidden',
    md: 'md:hidden',
    lg: 'lg:hidden'
  }[mobileBreakpoint]

  const breakpointTableClass = {
    sm: 'hidden sm:block',
    md: 'hidden md:block',
    lg: 'hidden lg:block'
  }[mobileBreakpoint]

  return (
    <>
      {/* Mobile Card View */}
      <div className={`${breakpointClass} space-y-3`}>
        {sortedData.map((item, index) => (
          <div 
            key={keyExtractor(item, index)}
            className="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow"
          >
            {columns.map((column, colIndex) => {
              const value = column.render 
                ? column.render(item, index) 
                : item[column.key]
              
              return (
                <div 
                  key={colIndex} 
                  className={`flex justify-between items-start py-2 ${
                    colIndex !== columns.length - 1 ? 'border-b border-gray-100' : ''
                  }`}
                >
                  <span className="text-sm font-medium text-gray-600 flex-shrink-0 w-1/3">
                    {column.label}
                  </span>
                  <span className="text-sm text-gray-900 flex-1 text-right">
                    {value}
                  </span>
                </div>
              )
            })}
          </div>
        ))}
      </div>

      {/* Desktop Table View */}
      <div className={`${breakpointTableClass} overflow-x-auto`}>
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              {columns.map((column, index) => (
                <th
                  key={index}
                  scope="col"
                  className={`px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider ${
                    column.sortable !== false ? 'cursor-pointer hover:bg-gray-100 transition-colors focus-ring' : ''
                  }`}
                  onClick={() => column.sortable !== false && handleSort(column.key)}
                  tabIndex={column.sortable !== false ? 0 : -1}
                  onKeyDown={(e) => column.sortable !== false && e.key === 'Enter' && handleSort(column.key)}
                >
                  <div className="flex items-center">
                    {column.label}
                    {column.sortable !== false && sortColumn === column.key && (
                      <span className="ml-1 text-gray-700">
                        {sortDirection === 'asc' ? '↑' : '↓'}
                      </span>
                    )}
                  </div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {sortedData.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-6 py-8">
                  {emptyState}
                </td>
              </tr>
            ) : (
              sortedData.map((item, rowIndex) => (
                <tr 
                  key={keyExtractor(item, rowIndex)}
                  className="hover:bg-gray-50 transition-colors"
                >
                  {columns.map((column, colIndex) => (
                    <td 
                      key={colIndex}
                      className="px-4 py-4 text-sm text-gray-900"
                    >
                      {column.render 
                        ? column.render(item, rowIndex) 
                        : item[column.key]
                      }
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </>
  )
}

export default MobileTable

