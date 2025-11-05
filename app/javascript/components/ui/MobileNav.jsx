import React, { useState } from 'react'
import { AccessibleButton } from './index'

/**
 * MobileNav - Mobile-friendly navigation header
 * Features: Hamburger menu, collapsible, touch-friendly
 */
const MobileNav = ({ 
  title = 'Dashboard',
  subtitle = null,
  actions = [],
  menuItems = []
}) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false)

  return (
    <nav className="bg-white border-b border-gray-200 sticky top-0 z-30 shadow-sm">
      <div className="px-4 py-3">
        <div className="flex items-center justify-between">
          {/* Title */}
          <div className="flex-1 min-w-0">
            <h1 className="text-xl sm:text-2xl font-bold text-gray-900 truncate">
              {title}
            </h1>
            {subtitle && (
              <p className="text-sm text-gray-600 truncate mt-0.5">
                {subtitle}
              </p>
            )}
          </div>

          {/* Actions (desktop) */}
          {actions.length > 0 && (
            <div className="hidden sm:flex items-center gap-2 ml-4">
              {actions.map((action, index) => (
                <AccessibleButton
                  key={index}
                  onClick={action.onClick}
                  variant={action.variant || 'primary'}
                  size="sm"
                  ariaLabel={action.ariaLabel}
                >
                  {action.label}
                </AccessibleButton>
              ))}
            </div>
          )}

          {/* Hamburger menu (mobile) */}
          {(menuItems.length > 0 || actions.length > 0) && (
            <button
              onClick={() => setIsMenuOpen(!isMenuOpen)}
              className="sm:hidden ml-4 p-2 rounded-lg hover:bg-gray-100 transition-colors focus-ring"
              aria-label="Toggle menu"
              aria-expanded={isMenuOpen}
            >
              <svg 
                className="w-6 h-6 text-gray-700" 
                fill="none" 
                strokeLinecap="round" 
                strokeLinejoin="round" 
                strokeWidth="2" 
                viewBox="0 0 24 24" 
                stroke="currentColor"
              >
                {isMenuOpen ? (
                  <path d="M6 18L18 6M6 6l12 12" />
                ) : (
                  <path d="M4 6h16M4 12h16M4 18h16" />
                )}
              </svg>
            </button>
          )}
        </div>

        {/* Mobile menu dropdown */}
        {isMenuOpen && (
          <div className="sm:hidden mt-3 pt-3 border-t border-gray-200 space-y-2 animate-slide-in-down">
            {/* Menu items */}
            {menuItems.map((item, index) => (
              <button
                key={index}
                onClick={() => {
                  item.onClick()
                  setIsMenuOpen(false)
                }}
                className="w-full text-left px-3 py-2 rounded-lg hover:bg-gray-100 transition-colors text-gray-700 font-medium"
              >
                {item.label}
              </button>
            ))}

            {/* Actions */}
            {actions.map((action, index) => (
              <AccessibleButton
                key={index}
                onClick={() => {
                  action.onClick()
                  setIsMenuOpen(false)
                }}
                variant={action.variant || 'primary'}
                size="md"
                className="w-full"
                ariaLabel={action.ariaLabel}
              >
                {action.label}
              </AccessibleButton>
            ))}
          </div>
        )}
      </div>
    </nav>
  )
}

export default MobileNav

