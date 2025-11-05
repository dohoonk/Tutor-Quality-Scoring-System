import React from 'react'

/**
 * MobileTable - Responsive table that shows as cards on mobile
 * 
 * Props:
 * - data: Array of objects to display
 * - columns: Array of column definitions { key, label, render? }
 * - keyExtractor: Function to extract unique key from each row
 * - emptyState: Component to show when data is empty
 */
const MobileTable = ({ 
  data = [], 
  columns = [], 
  keyExtractor = (item, index) => index,
  emptyState = null,
  mobileBreakpoint = 'md' // sm, md, lg
}) => {
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
        {data.map((item, index) => (
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
                  className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >
                  {column.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {data.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-6 py-8">
                  {emptyState}
                </td>
              </tr>
            ) : (
              data.map((item, rowIndex) => (
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

