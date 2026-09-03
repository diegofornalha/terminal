'use client';

import { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';

// Importa o terminal de forma dinâmica para evitar SSR
const TerminalInteractive = dynamic(
  () => import('../../components/TerminalInteractive'),
  { 
    ssr: false,
    loading: () => (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="w-8 h-8 border-2 border-green-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-green-400">Carregando terminal interativo...</p>
        </div>
      </div>
    )
  }
);

export default function TerminalInteractivePage() {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="w-8 h-8 border-2 border-green-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-green-400">Iniciando...</p>
        </div>
      </div>
    );
  }

  return (
    <TerminalInteractive projectId="interactive-test" />
  );
}