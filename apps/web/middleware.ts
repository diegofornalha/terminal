import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  // Handle WebSocket upgrade requests
  if (request.nextUrl.pathname.startsWith('/ws/')) {
    const apiUrl = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000';
    const wsUrl = apiUrl.replace('http', 'ws');
    
    // Rewrite to the API WebSocket endpoint
    const url = request.nextUrl.clone();
    url.href = `${wsUrl}${request.nextUrl.pathname}`;
    
    return NextResponse.rewrite(url);
  }
  
  return NextResponse.next();
}

export const config = {
  matcher: '/ws/:path*',
};