/** @type {import('next').NextConfig} */
const nextConfig = {
  compress: true,
  poweredByHeader: false,
  swcMinify: true,
  compiler: {
    styledJsx: false,
  },
  experimental: {
    esmExternals: false,
  },
};

module.exports = nextConfig;