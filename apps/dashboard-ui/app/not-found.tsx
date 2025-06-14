export default function NotFound() {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">404</h1>
        <p className="text-gray-600 mb-8">Page not found</p>
        <a href="/" className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
          Return Home
        </a>
      </div>
    </div>
  )
}