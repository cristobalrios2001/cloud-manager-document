'use client';

import { useRef, useState, type FormEvent } from 'react';
import { uploadFile } from '@/lib/api';

const MAX_SIZE_MB = 10; // protege el Free Tier de S3

type Status =
  | { kind: 'idle' }
  | { kind: 'uploading' }
  | { kind: 'success'; name: string }
  | { kind: 'error'; message: string };

export default function UploadForm({ onUploaded }: { onUploaded: () => void }) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [status, setStatus] = useState<Status>({ kind: 'idle' });

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!file) return;

    if (file.size > MAX_SIZE_MB * 1024 * 1024) {
      setStatus({
        kind: 'error',
        message: `El archivo supera ${MAX_SIZE_MB} MB`,
      });
      return;
    }

    setStatus({ kind: 'uploading' });
    try {
      await uploadFile(file);
      setStatus({ kind: 'success', name: file.name });
      setFile(null);
      if (inputRef.current) inputRef.current.value = '';
      onUploaded();
    } catch (err) {
      setStatus({
        kind: 'error',
        message: err instanceof Error ? err.message : 'Error desconocido',
      });
    }
  }

  const uploading = status.kind === 'uploading';

  return (
    <form
      onSubmit={handleSubmit}
      className="space-y-3 rounded-lg border border-black/15 p-4 dark:border-white/20"
    >
      <h2 className="text-lg font-medium">Subir documento</h2>

      <input
        ref={inputRef}
        type="file"
        disabled={uploading}
        onChange={(e) => {
          setFile(e.target.files?.[0] ?? null);
          setStatus({ kind: 'idle' });
        }}
        className="block w-full text-sm"
      />

      <button
        type="submit"
        disabled={!file || uploading}
        className="rounded-md bg-black px-4 py-2 text-sm font-medium text-white disabled:opacity-40 dark:bg-white dark:text-black"
      >
        {uploading ? 'Subiendo…' : 'Subir'}
      </button>

      {status.kind === 'success' && (
        <p className="text-sm text-green-600">
          «{status.name}» se subió correctamente.
        </p>
      )}
      {status.kind === 'error' && (
        <p className="text-sm text-red-600">{status.message}</p>
      )}
    </form>
  );
}