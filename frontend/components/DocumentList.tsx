'use client';

import { useEffect, useState } from 'react';
import { getViewUrl, listDocuments, type DocumentItem } from '@/lib/api';

function formatSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function formatDate(iso: string | null) {
  return iso ? new Date(iso).toLocaleString() : '—';
}

export default function DocumentList({ refreshKey }: { refreshKey: number }) {
  const [docs, setDocs] = useState<DocumentItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [openingKey, setOpeningKey] = useState<string | null>(null);

  // Se vuelve a ejecutar cada vez que cambia refreshKey (tras una subida)
  useEffect(() => {
    let cancelled = false;

    listDocuments()
      .then((items) => {
        if (cancelled) return;
        setDocs(items);
        setError(null);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : 'Error desconocido');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [refreshKey]);

  async function handleOpen(key: string) {
    // Abrir la pestaña ANTES del await evita que el navegador bloquee el popup
    const tab = window.open('', '_blank');
    setOpeningKey(key);
    try {
      const { url } = await getViewUrl(key);
      if (tab) {
        tab.opener = null;
        tab.location.href = url;
      } else {
        window.location.assign(url);
      }
    } catch (err) {
      tab?.close();
      setError(err instanceof Error ? err.message : 'Error desconocido');
    } finally {
      setOpeningKey(null);
    }
  }

  return (
    <section className="space-y-3">
      <h2 className="text-lg font-medium">Documentos</h2>

      {loading && <p className="text-sm opacity-70">Cargando…</p>}
      {error && <p className="text-sm text-red-600">{error}</p>}
      {!loading && !error && docs.length === 0 && (
        <p className="text-sm opacity-70">Aún no hay documentos.</p>
      )}

      <ul className="divide-y divide-black/10 rounded-lg border border-black/15 dark:divide-white/15 dark:border-white/20">
        {docs.map((doc) => (
          <li
            key={doc.key}
            className="flex items-center justify-between gap-4 p-3"
          >
            <div className="min-w-0">
              <p className="truncate text-sm font-medium">{doc.name}</p>
              <p className="text-xs opacity-60">
                {formatSize(doc.size)} · {formatDate(doc.lastModified)}
              </p>
            </div>
            <button
              onClick={() => handleOpen(doc.key)}
              disabled={openingKey === doc.key}
              className="shrink-0 rounded-md border border-black/20 px-3 py-1 text-sm disabled:opacity-40 dark:border-white/30"
            >
              {openingKey === doc.key ? 'Abriendo…' : 'Abrir'}
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}