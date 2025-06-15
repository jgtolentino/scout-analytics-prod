'use client'

import React from 'react'

const GeospatialMapCard: React.FC = () => {
  const regions = [
    { name: "Luzon", revenue: 85000, tbwaShare: 72, color: "bg-blue-500" },
    { name: "Visayas", revenue: 25000, tbwaShare: 65, color: "bg-green-500" },
    { name: "Mindanao", revenue: 15000, tbwaShare: 58, color: "bg-orange-500" }
  ]

  const maxRevenue = Math.max(...regions.map(r => r.revenue))

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-lg font-semibold mb-4">Regional Performance Map</h2>
      <div className="space-y-4">
        {regions.map((region, index) => {
          const widthPercentage = (region.revenue / maxRevenue) * 100
          return (
            <div key={index} className="space-y-2">
              <div className="flex justify-between items-center">
                <span className="font-medium text-gray-900">{region.name}</span>
                <div className="text-right">
                  <div className="text-sm font-medium">₱{region.revenue.toLocaleString()}</div>
                  <div className="text-xs text-gray-500">{region.tbwaShare}% TBWA</div>
                </div>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div 
                  className={`h-2 rounded-full ${region.color}`}
                  style={{ width: `${widthPercentage}%` }}
                ></div>
              </div>
            </div>
          )
        })}
      </div>
      <div className="mt-4 text-xs text-gray-500">
        17 Philippine regions • Real-time performance tracking
      </div>
    </div>
  )
}

export default GeospatialMapCard