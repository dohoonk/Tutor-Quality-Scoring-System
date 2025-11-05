import React, { useState, useMemo } from 'react'
import { AccessibleButton } from './index'

/**
 * MobileSearchableTable - Mobile-optimized table with search and filtering
 * Shows search bar and filters on mobile, table on desktop
 */
const MobileSearchableTable = ({
  data = [],
  columns = [],
  keyExtractor = (item, index) => index,
  emptyState = null,
  searchableFields = [], // Array of field names to search in
  filters = [], // Array of filter configs { key, label, options: [{value, label}], getValue?: (item) => value }
  defaultSort = { column: null, direction: 'asc' },
  onRowClick = null,
  mobileBreakpoint = 'md'
}) => {
  const [searchQuery, setSearchQuery] = useState('')
  const [activeFilters, setActiveFilters] = useState({})
  const [sortColumn, setSortColumn] = useState(defaultSort.column)
  const [sortDirection, setSortDirection] = useState(defaultSort.direction)
  const [showFilters, setShowFilters] = useState(false)

  // Filter and search data
  const filteredData = useMemo(() => {
    let result = [...data]

    // Apply search
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase()
      result = result.filter(item => {
        return searchableFields.some(field => {
          const value = item[field]
          return value && value.toString().toLowerCase().includes(query)
        })
      })
    }

    // Apply filters
    Object.entries(activeFilters).forEach(([key, value]) => {
      if (value && value !== 'all') {
        const filterConfig = filters.find(f => f.key === key)
        result = result.filter(item => {
          // Use custom getValue function if provided, otherwise use item[key]
          const itemValue = filterConfig?.getValue ? filterConfig.getValue(item) : item[key]
          
          // Handle special filter values
          if (key === 'has_alerts' && value === 'yes') {
            return item.alert_count > 0
          }
          if (key === 'has_alerts' && value === 'no') {
            return item.alert_count === 0 || !item.alert_count
          }
          
          return itemValue === value || (Array.isArray(itemValue) && itemValue.includes(value))
        })
      }
    })

    return result
  }, [data, searchQuery, activeFilters, searchableFields, filters])

  // Sort data
  const sortedData = useMemo(() => {
    if (!sortColumn) return filteredData

    return [...filteredData].sort((a, b) => {
      let aVal = a[sortColumn]
      let bVal = b[sortColumn]

      // Handle null values
      if (aVal === null || aVal === undefined) return 1
      if (bVal === null || bVal === undefined) return -1

      // String comparison
      if (typeof aVal === 'string') {
        aVal = aVal.toLowerCase()
        bVal = bVal.toLowerCase()
        return sortDirection === 'asc' 
          ? aVal.localeCompare(bVal)
          : bVal.localeCompare(aVal)
      }

      // Numeric comparison
      return sortDirection === 'asc' ? aVal - bVal : bVal - aVal
    })
  }, [filteredData, sortColumn, sortDirection])

  const handleSort = (column) => {
    if (sortColumn === column) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      setSortColumn(column)
      setSortDirection('asc')
    }
  }

  const handleFilterChange = (filterKey, value) => {
    setActiveFilters(prev => ({
      ...prev,
      [filterKey]: value
    }))
  }

  const clearFilters = () => {
    setSearchQuery('')
    setActiveFilters({})
  }

  const activeFilterCount = Object.values(activeFilters).filter(v => v && v !== 'all').length + (searchQuery ? 1 : 0)

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
    <div className="space-y-4">
      {/* Mobile Search & Filter Bar */}
      <div className={`${breakpointClass} space-y-3`}>
        {/* Search Bar */}
        <div className="relative">
          <input
            type="text"
            placeholder="Search tutors..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-10 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-base"
            aria-label="Search tutors"
          />
          <svg
            className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
              aria-label="Clear search"
            >
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </button>
          )}
        </div>

        {/* Filter Toggle */}
        {filters.length > 0 && (
          <div className="flex items-center gap-2">
            <AccessibleButton
              onClick={() => setShowFilters(!showFilters)}
              variant={activeFilterCount > 0 ? 'primary' : 'secondary'}
              size="md"
              className="flex-1"
              ariaLabel="Toggle filters"
            >
              <span className="flex items-center gap-2">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
                </svg>
                Filters
                {activeFilterCount > 0 && (
                  <span className="bg-white text-blue-600 rounded-full px-2 py-0.5 text-xs font-bold">
                    {activeFilterCount}
                  </span>
                )}
              </span>
            </AccessibleButton>
            {activeFilterCount > 0 && (
              <AccessibleButton
                onClick={clearFilters}
                variant="ghost"
                size="md"
                ariaLabel="Clear all filters"
              >
                Clear
              </AccessibleButton>
            )}
          </div>
        )}

        {/* Filter Dropdown */}
        {showFilters && filters.length > 0 && (
          <div className="bg-white border border-gray-200 rounded-lg p-4 space-y-4 animate-slide-in-down">
            {filters.map(filter => (
              <div key={filter.key}>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  {filter.label}
                </label>
                <select
                  value={activeFilters[filter.key] || 'all'}
                  onChange={(e) => handleFilterChange(filter.key, e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-base"
                >
                  <option value="all">All</option>
                  {filter.options.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>
            ))}
          </div>
        )}

        {/* Results Count */}
        <div className="text-sm text-gray-600">
          Showing {sortedData.length} of {data.length} tutors
          {(searchQuery || activeFilterCount > 0) && (
            <button
              onClick={clearFilters}
              className="ml-2 text-blue-600 hover:text-blue-800 underline"
            >
              Clear all
            </button>
          )}
        </div>
      </div>

      {/* Mobile List View */}
      <div className={`${breakpointClass} space-y-3`}>
        {sortedData.length === 0 ? (
          <div className="py-12">
            {emptyState || (
              <div className="text-center text-gray-500">
                <p className="text-lg font-medium mb-2">No tutors found</p>
                <p className="text-sm">
                  {searchQuery || activeFilterCount > 0
                    ? 'Try adjusting your search or filters'
                    : 'No tutors available'}
                </p>
                {(searchQuery || activeFilterCount > 0) && (
                  <button
                    onClick={clearFilters}
                    className="mt-4 text-blue-600 hover:text-blue-800 underline"
                  >
                    Clear filters
                  </button>
                )}
              </div>
            )}
          </div>
        ) : (
          sortedData.map((item, index) => (
            <div
              key={keyExtractor(item, index)}
              onClick={() => onRowClick && onRowClick(item)}
              className={`bg-white border rounded-lg p-4 hover:shadow-md transition-shadow ${
                onRowClick ? 'cursor-pointer' : ''
              }`}
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
          ))
        )}
      </div>

      {/* Desktop Table View */}
      <div className={`${breakpointTableClass} bg-white rounded-lg shadow-md overflow-hidden`}>
        {/* Desktop Search & Filters */}
        <div className="p-4 border-b border-gray-200 bg-gray-50">
          <div className="flex flex-col lg:flex-row gap-4">
            {/* Search */}
            <div className="flex-1 relative">
              <input
                type="text"
                placeholder="Search tutors..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                aria-label="Search tutors"
              />
              <svg
                className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery('')}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  ✕
                </button>
              )}
            </div>

            {/* Filters */}
            {filters.map(filter => (
              <select
                key={filter.key}
                value={activeFilters[filter.key] || 'all'}
                onChange={(e) => handleFilterChange(filter.key, e.target.value)}
                className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="all">{filter.label}: All</option>
                {filter.options.map(option => (
                  <option key={option.value} value={option.value}>
                    {filter.label}: {option.label}
                  </option>
                ))}
              </select>
            ))}
          </div>

          {/* Results Count */}
          <div className="mt-2 text-sm text-gray-600">
            Showing {sortedData.length} of {data.length} tutors
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
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
                    {emptyState || (
                      <div className="text-center text-gray-500">
                        <p>No tutors found</p>
                        {(searchQuery || activeFilterCount > 0) && (
                          <button
                            onClick={clearFilters}
                            className="mt-2 text-blue-600 hover:text-blue-800 underline"
                          >
                            Clear filters
                          </button>
                        )}
                      </div>
                    )}
                  </td>
                </tr>
              ) : (
                sortedData.map((item, rowIndex) => (
                  <tr
                    key={keyExtractor(item, rowIndex)}
                    onClick={() => onRowClick && onRowClick(item)}
                    className={`hover:bg-gray-50 transition-colors ${
                      onRowClick ? 'cursor-pointer' : ''
                    }`}
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
      </div>
    </div>
  )
}

export default MobileSearchableTable

