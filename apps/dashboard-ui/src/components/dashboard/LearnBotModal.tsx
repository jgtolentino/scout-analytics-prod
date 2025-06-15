'use client'

import React, { useEffect } from 'react'

interface LearnBotModalProps {
  context: string
  onClose: () => void
}

const LearnBotModal: React.FC<LearnBotModalProps> = ({ context, onClose }) => {
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
      }
    }
    
    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  }, [onClose])

  const getTutorialContent = (context: string) => {
    switch (context) {
      case 'dashboard_overview_tutorial':
        return {
          title: 'Dashboard Overview Tutorial',
          steps: [
            {
              title: 'Welcome to Scout Analytics',
              content: 'This dashboard provides real-time insights into Philippine market performance for TBWA brands.'
            },
            {
              title: 'Key Performance Indicators',
              content: 'The "What\'s Happening" section shows daily revenue, transactions, and market share metrics.'
            },
            {
              title: 'AI Insights',
              content: 'The "Why Is This Happening?" section provides AI-powered analysis of performance drivers.'
            },
            {
              title: 'Regional Performance',
              content: 'View geographic performance across 17 Philippine regions with detailed breakdowns.'
            },
            {
              title: 'Navigation',
              content: 'Use the sidebar to explore Transaction Trends, Product Mix, and Consumer Insights.'
            }
          ]
        }
      default:
        return {
          title: 'Tutorial',
          steps: [
            {
              title: 'Getting Started',
              content: 'Welcome to the Scout Analytics tutorial system.'
            }
          ]
        }
    }
  }

  const tutorial = getTutorialContent(context)
  const [currentStep, setCurrentStep] = React.useState(0)

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 p-6">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-semibold">{tutorial.title}</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-xl"
            aria-label="Close tutorial"
          >
            ×
          </button>
        </div>
        
        <div className="mb-6">
          <div className="mb-2">
            <span className="text-sm text-gray-500">
              Step {currentStep + 1} of {tutorial.steps.length}
            </span>
          </div>
          <h3 className="text-lg font-medium mb-2">
            {tutorial.steps[currentStep].title}
          </h3>
          <p className="text-gray-700">
            {tutorial.steps[currentStep].content}
          </p>
        </div>

        <div className="flex justify-between">
          <button
            onClick={() => setCurrentStep(Math.max(0, currentStep - 1))}
            disabled={currentStep === 0}
            className="px-4 py-2 text-gray-600 disabled:text-gray-400 disabled:cursor-not-allowed"
          >
            Previous
          </button>
          
          {currentStep < tutorial.steps.length - 1 ? (
            <button
              onClick={() => setCurrentStep(currentStep + 1)}
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
            >
              Next
            </button>
          ) : (
            <button
              onClick={onClose}
              className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
            >
              Complete
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

export default LearnBotModal