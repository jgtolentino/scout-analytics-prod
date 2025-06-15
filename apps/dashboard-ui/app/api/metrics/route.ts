import { NextResponse } from 'next/server'

// Mock metrics for the dashboard API
// In production, this would connect to your actual database
export async function GET() {
  try {
    // This should match the actual data from your database
    // For now, using the same values as the UI components
    const metrics = {
      totalTransactions: 850,
      revenueToday: 125000,
      tbwaMarketShare: 67.5,
      revenueGrowth: 12.3,
      timestamp: new Date().toISOString()
    }

    return NextResponse.json(metrics)
  } catch (error) {
    console.error('Error fetching metrics:', error)
    return NextResponse.json(
      { error: 'Failed to fetch metrics' },
      { status: 500 }
    )
  }
}