'use client'

import React from 'react'

const ProductMixCard: React.FC = () => {
  const tbwaBrands = [
    { name: "Alaska Milk", sku_count: 24, revenue_share: 36, growth: "+15%" },
    { name: "Oishi Snacks", sku_count: 18, revenue_share: 26, growth: "+8%" },
    { name: "Del Monte", sku_count: 16, revenue_share: 22, growth: "+12%" },
    { name: "Peerless", sku_count: 12, revenue_share: 12, growth: "+5%" },
    { name: "JTI Products", sku_count: 8, revenue_share: 4, growth: "+2%" }
  ]

  const topSKUs = [
    { sku: "ALK-001", name: "Alaska Fresh Milk 1L", units: 1240, revenue: "₱62,000" },
    { sku: "OSH-015", name: "Oishi Prawn Crackers", units: 980, revenue: "₱49,000" },
    { sku: "DM-008", name: "Del Monte Corned Beef", units: 720, revenue: "₱43,200" },
    { sku: "PER-003", name: "Peerless Detergent", units: 560, revenue: "₱28,000" }
  ]

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-lg font-semibold mb-4">Product Mix & SKU Info</h2>
      
      {/* TBWA Brand Performance */}
      <div className="mb-6">
        <h3 className="text-md font-medium mb-3">TBWA Brand Performance</h3>
        <div className="space-y-3">
          {tbwaBrands.map((brand, index) => (
            <div key={index} className="flex justify-between items-center p-2 bg-gray-50 rounded">
              <div>
                <div className="font-medium text-sm">{brand.name}</div>
                <div className="text-xs text-gray-600">{brand.sku_count} SKUs active</div>
              </div>
              <div className="text-right">
                <div className="text-sm font-semibold">{brand.revenue_share}%</div>
                <div className="text-xs text-green-600">{brand.growth}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Top Performing SKUs */}
      <div>
        <h3 className="text-md font-medium mb-3">Top Performing SKUs</h3>
        <div className="space-y-2">
          {topSKUs.map((sku, index) => (
            <div key={index} className="flex justify-between items-center text-sm">
              <div>
                <div className="font-medium">{sku.name}</div>
                <div className="text-xs text-gray-500">{sku.sku}</div>
              </div>
              <div className="text-right">
                <div className="font-medium">{sku.revenue}</div>
                <div className="text-xs text-gray-600">{sku.units} units</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-4 text-xs text-gray-500">
        98 total SKUs tracked • 5 TBWA brands
      </div>
    </div>
  )
}

export default ProductMixCard