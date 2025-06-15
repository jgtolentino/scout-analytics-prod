'use client'

import React, { useState } from 'react'
import { Button } from '../ui/button'
import LearnBotModal from './LearnBotModal'

const InteractiveTutorialCard: React.FC = () => {
  const [open, setOpen] = useState(false)
  
  return (
    <div className="bg-white rounded-lg shadow p-4">
      <h2 className="text-lg font-semibold mb-2">Interactive Tutorial</h2>
      <p className="text-sm text-gray-600 mb-4">
        Launch a guided walkthrough of the dashboard features.
      </p>
      <Button onClick={() => setOpen(true)}>Launch Tutorial</Button>
      {open && (
        <LearnBotModal
          context="dashboard_overview_tutorial"
          onClose={() => setOpen(false)}
        />
      )}
    </div>
  )
}

export default InteractiveTutorialCard