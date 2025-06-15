'use client'

import React from 'react'

const ConsumerProfilingCard: React.FC = () => {
  const demographics = [
    { segment: "Young Professionals", percentage: 32, age: "25-35", income: "₱30-60k" },
    { segment: "Family Households", percentage: 28, age: "30-45", income: "₱40-80k" },
    { segment: "Urban Millennials", percentage: 24, age: "20-30", income: "₱25-45k" },
    { segment: "Senior Citizens", percentage: 16, age: "55+", income: "₱20-40k" }
  ]

  const customerTypes = [
    { type: "Loyal Customers", count: 1240, value: "₱180k", frequency: "Weekly" },
    { type: "Occasional Buyers", count: 2180, value: "₱95k", frequency: "Monthly" },
    { type: "Price Hunters", count: 980, value: "₱45k", frequency: "Promotions" },
    { type: "New Customers", count: 560, value: "₱28k", frequency: "First Visit" }
  ]

  const regionalProfiles = [
    { region: "Metro Manila", profile: "High income, brand conscious", tbwa_affinity: 85 },
    { region: "Cebu City", profile: "Value-oriented, family-focused", tbwa_affinity: 72 },
    { region: "Davao", profile: "Quality seekers, price sensitive", tbwa_affinity: 68 }
  ]

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-lg font-semibold mb-4">Consumer Profiling</h2>
      
      {/* Demographics Breakdown */}
      <div className="mb-6">
        <h3 className="text-md font-medium mb-3">Demographics Breakdown</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {demographics.map((demo, index) => (
            <div key={index} className="bg-gray-50 p-3 rounded">
              <div className="font-medium text-sm">{demo.segment}</div>
              <div className="text-xs text-gray-600 mt-1">
                Age: {demo.age} • Income: {demo.income}
              </div>
              <div className="text-lg font-semibold text-blue-600 mt-1">
                {demo.percentage}%
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Customer Types */}
      <div className="mb-6">
        <h3 className="text-md font-medium mb-3">Customer Types</h3>
        <div className="space-y-2">
          {customerTypes.map((customer, index) => (
            <div key={index} className="flex justify-between items-center p-2 border rounded">
              <div>
                <div className="font-medium text-sm">{customer.type}</div>
                <div className="text-xs text-gray-600">{customer.frequency} shoppers</div>
              </div>
              <div className="text-right">
                <div className="text-sm font-semibold">{customer.value}</div>
                <div className="text-xs text-gray-600">{customer.count} customers</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Regional Profiles */}
      <div>
        <h3 className="text-md font-medium mb-3">Regional Profiles</h3>
        <div className="space-y-3">
          {regionalProfiles.map((region, index) => (
            <div key={index} className="space-y-2">
              <div className="flex justify-between items-center">
                <span className="font-medium text-sm">{region.region}</span>
                <span className="text-sm text-blue-600">{region.tbwa_affinity}% TBWA affinity</span>
              </div>
              <p className="text-xs text-gray-600">{region.profile}</p>
              <div className="w-full bg-gray-200 rounded-full h-1">
                <div 
                  className="h-1 rounded-full bg-blue-500"
                  style={{ width: `${region.tbwa_affinity}%` }}
                ></div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-4 text-xs text-gray-500">
        Segmentation based on purchase history • 4,960 active profiles
      </div>
    </div>
  )
}

export default ConsumerProfilingCard