'use client';

import { useState } from 'react';
import DocumentList from '@/components/DocumentList';
import UploadForm from '@/components/UploadForm';

export default function Home() {
  // Al cambiar este número, DocumentList vuelve a pedir la lista
  const [refreshKey, setRefreshKey] = useState(0);

  return (
    <main className="mx-auto max-w-3xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Cloud Document Manager</h1>
        <p className="text-sm opacity-70">
          Sube y abre documentos directamente en S3 mediante URLs firmadas.
        </p>
      </header>

      <UploadForm onUploaded={() => setRefreshKey((k) => k + 1)} />
      <DocumentList refreshKey={refreshKey} />
    </main>
  );
}