import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Scout Analytics Dashboard',
  description: 'Real-time Philippine market insights for TBWA brands',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="bg-gray-50 font-sans">
        {children}
      </body>
    </html>
  )
}