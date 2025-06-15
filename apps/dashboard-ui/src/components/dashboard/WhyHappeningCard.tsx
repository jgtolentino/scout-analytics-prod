'use client'

import React from 'react'

const WhyHappeningCard: React.FC = () => {
  const insights = [
    {
      title: "Strong Alaska Milk Performance",
      description: "Alaska brand showing 15% growth driven by increased distribution in Luzon region",
      confidence: 92,
      impact: "high"
    },
    {
      title: "Seasonal Snack Demand",
      description: "Oishi products experiencing summer demand surge, particularly in urban centers",
      confidence: 87,
      impact: "medium"
    },
    {
      title: "Regional Expansion Success",
      description: "New store openings in Visayas contributing to overall transaction growth",
      confidence: 84,
      impact: "medium"
    }
  ]

  const getImpactColor = (impact: string) => {
    switch (impact) {
      case 'high': return 'text-red-600 bg-red-50'
      case 'medium': return 'text-yellow-600 bg-yellow-50'
      case 'low': return 'text-green-600 bg-green-50'
      default: return 'text-gray-600 bg-gray-50'
    }
  }

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-lg font-semibold mb-4">Why Is This Happening?</h2>
      <div className="space-y-4">
        {insights.map((insight, index) => (
          <div key={index} className="border-l-4 border-blue-500 pl-4">
            <div className="flex justify-between items-start mb-2">
              <h3 className="font-medium text-gray-900">{insight.title}</h3>
              <div className="flex items-center space-x-2">
                <span className={`px-2 py-1 text-xs rounded ${getImpactColor(insight.impact)}`}>
                  {insight.impact}
                </span>
                <span className="text-xs text-gray-500">{insight.confidence}%</span>
              </div>
            </div>
            <p className="text-sm text-gray-600">{insight.description}</p>
          </div>
        ))}
      </div>
      <div className="mt-4 text-xs text-gray-500">
        AI Confidence: 87% • Based on 5,000+ transaction analysis
      </div>
    </div>
  )
}

export default WhyHappeningCard