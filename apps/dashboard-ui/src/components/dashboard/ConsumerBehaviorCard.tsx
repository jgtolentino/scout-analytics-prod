'use client'

import React from 'react'

const ConsumerBehaviorCard: React.FC = () => {
  const behaviorSignals = [
    { 
      signal: "Bundle Purchases", 
      frequency: "68%", 
      impact: "High",
      description: "Customers buying 2+ TBWA products together"
    },
    { 
      signal: "Brand Loyalty", 
      frequency: "52%", 
      impact: "High",
      description: "Repeat purchases within 30 days"
    },
    { 
      signal: "Price Sensitivity", 
      frequency: "34%", 
      impact: "Medium",
      description: "Purchases during promotional periods"
    },
    { 
      signal: "Seasonal Patterns", 
      frequency: "78%", 
      impact: "Medium",
      description: "Holiday and weather-driven demand"
    }
  ]

  const preferences = [
    { category: "Premium Quality", percentage: 45, color: "bg-blue-500" },
    { category: "Value for Money", percentage: 38, color: "bg-green-500" },
    { category: "Brand Recognition", percentage: 32, color: "bg-purple-500" },
    { category: "Convenience", percentage: 28, color: "bg-orange-500" }
  ]

  const getImpactColor = (impact: string) => {
    switch (impact) {
      case 'High': return 'text-red-600 bg-red-50'
      case 'Medium': return 'text-yellow-600 bg-yellow-50'
      case 'Low': return 'text-green-600 bg-green-50'
      default: return 'text-gray-600 bg-gray-50'
    }
  }

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-lg font-semibold mb-4">Consumer Behavior & Preference Signals</h2>
      
      {/* Behavior Signals */}
      <div className="mb-6">
        <h3 className="text-md font-medium mb-3">Key Behavior Signals</h3>
        <div className="space-y-3">
          {behaviorSignals.map((signal, index) => (
            <div key={index} className="border-l-4 border-blue-400 pl-3">
              <div className="flex justify-between items-start mb-1">
                <span className="font-medium text-sm">{signal.signal}</span>
                <div className="flex items-center space-x-2">
                  <span className={`px-2 py-1 text-xs rounded ${getImpactColor(signal.impact)}`}>
                    {signal.impact}
                  </span>
                  <span className="text-sm font-semibold">{signal.frequency}</span>
                </div>
              </div>
              <p className="text-xs text-gray-600">{signal.description}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Purchase Preferences */}
      <div>
        <h3 className="text-md font-medium mb-3">Purchase Preferences</h3>
        <div className="space-y-3">
          {preferences.map((pref, index) => {
            const maxPercentage = Math.max(...preferences.map(p => p.percentage))
            const widthPercentage = (pref.percentage / maxPercentage) * 100
            return (
              <div key={index} className="space-y-1">
                <div className="flex justify-between items-center">
                  <span className="text-sm font-medium">{pref.category}</span>
                  <span className="text-sm text-gray-600">{pref.percentage}%</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2">
                  <div 
                    className={`h-2 rounded-full ${pref.color}`}
                    style={{ width: `${widthPercentage}%` }}
                  ></div>
                </div>
              </div>
            )
          })}
        </div>
      </div>

      <div className="mt-4 text-xs text-gray-500">
        Based on 5,000+ customer interactions • Machine learning insights
      </div>
    </div>
  )
}

export default ConsumerBehaviorCard