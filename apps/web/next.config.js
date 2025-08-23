/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  productionBrowserSourceMaps: false,
  // Disable critters optimizeCss to avoid missing module during build
  experimental: {
    optimizeCss: false,
    scrollRestoration: true,
  },
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: process.env.NEXT_PUBLIC_API_BASE ? 
          `${process.env.NEXT_PUBLIC_API_BASE}/api/:path*` :
          'http://localhost:8000/api/:path*',
      },
    ];
  },
};

module.exports = nextConfig;