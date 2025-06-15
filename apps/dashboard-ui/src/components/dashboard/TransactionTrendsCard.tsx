'use client'

import React from 'react'

const TransactionTrendsCard: React.FC = () => {
  const trendData = [
    { period: "Last 7 days", transactions: 5950, change: "+12.5%" },
    { period: "Last 30 days", transactions: 24800, change: "+8.2%" },
    { period: "This quarter", transactions: 68400, change: "+15.7%" }
  ]

  const topCategories = [
    { category: "Dairy Products", percentage: 34, trend: "up" },
    { category: "Snacks & Confections", percentage: 28, trend: "up" },
    { category: "Beverages", percentage: 22, trend: "stable" },
    { category: "Household Items", percentage: 16, trend: "down" }
  ]

  const getTrendIcon = (trend: string) => {
    switch (trend) {
      case 'up': return '📈'
      case 'down': return '📉'
      case 'stable': return '➡️'
      default: return '➡️'
    }
  }

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-lg font-semibold mb-4">Transaction Trends</h2>
      
      {/* Time-based trends */}
      <div className="mb-6">
        <h3 className="text-md font-medium mb-3">Volume Trends</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {trendData.map((item, index) => (
            <div key={index} className="bg-gray-50 p-3 rounded">
              <div className="text-sm text-gray-600">{item.period}</div>
              <div className="text-lg font-semibold">{item.transactions.toLocaleString()}</div>
              <div className="text-sm text-green-600">{item.change}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Category breakdown */}
      <div>
        <h3 className="text-md font-medium mb-3">Top Categories</h3>
        <div className="space-y-2">
          {topCategories.map((cat, index) => (
            <div key={index} className="flex justify-between items-center">
              <span className="text-sm">{cat.category}</span>
              <div className="flex items-center space-x-2">
                <span className="text-sm font-medium">{cat.percentage}%</span>
                <span className="text-xs">{getTrendIcon(cat.trend)}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-4 text-xs text-gray-500">
        Real-time data • Updated every 15 minutes
      </div>
    </div>
  )
}

export default TransactionTrendsCard