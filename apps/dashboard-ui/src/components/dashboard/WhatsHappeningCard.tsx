'use client'

import React from 'react'

interface WhatsHappeningCardProps {
  metrics: {
    revenue_today: number
    total_transactions_today: number
    tbwa_market_share_percent: number
    revenue_growth_dod_percent: number
  }
}

const WhatsHappeningCard: React.FC<WhatsHappeningCardProps> = ({ metrics }) => {
  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-lg font-semibold mb-4">What's Happening</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="text-center">
          <div className="text-2xl font-bold text-green-600">
            ₱{metrics.revenue_today.toLocaleString()}
          </div>
          <div className="text-sm text-gray-600">Today's Revenue</div>
          <div className="text-xs text-green-500">
            +{metrics.revenue_growth_dod_percent}% vs yesterday
          </div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-blue-600">
            {metrics.total_transactions_today.toLocaleString()}
          </div>
          <div className="text-sm text-gray-600">Transactions</div>
          <div className="text-xs text-gray-500">Customer interactions</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-purple-600">
            {metrics.tbwa_market_share_percent.toFixed(1)}%
          </div>
          <div className="text-sm text-gray-600">TBWA Market Share</div>
          <div className="text-xs text-gray-500">Across PH regions</div>
        </div>
      </div>
    </div>
  )
}

export default WhatsHappeningCard