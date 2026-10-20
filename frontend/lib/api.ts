// NEXT_PUBLIC_* se inyecta en tiempo de BUILD: queda incrustado en el JS del navegador.
// Por defecto es una ruta RELATIVA (/api): en AWS el ALB la envía al backend, y en local
// next.config.ts la redirige al puerto 4000. Así la imagen no depende de ninguna URL fija.
export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? '/api';

export interface DocumentItem {
  key: string;
  name: string;
  size: number;
  lastModified: string | null;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    ...init,
    // Content-Type solo cuando hay body: evita un preflight innecesario en los GET
    headers: init?.body ? { 'Content-Type': 'application/json' } : undefined,
    cache: 'no-store',
  });

  if (!res.ok) {
    const body = await res.json().catch(() => null);
    const message = Array.isArray(body?.message)
      ? body.message.join(', ')
      : (body?.message ?? res.statusText);
    throw new Error(message);
  }

  return res.json() as Promise<T>;
}

export const listDocuments = () => request<DocumentItem[]>('/documents');

export const getUploadUrl = (filename: string, fileType: string) =>
  request<{ url: string; key: string; expiresIn: number }>(
    '/documents/upload-url',
    { method: 'POST', body: JSON.stringify({ filename, fileType }) },
  );

// Avisa al backend que el PUT a S3 terminó, para que registre los metadatos del documento
export const confirmUpload = (key: string) =>
  request<{ stored: boolean }>('/documents/confirm', {
    method: 'POST',
    body: JSON.stringify({ key }),
  });

export const getViewUrl = (key: string) =>
  request<{ url: string; expiresIn: number }>('/documents/view-url', {
    method: 'POST',
    body: JSON.stringify({ key }),
  });

// 1) pide la URL firmada al backend  2) sube el archivo DIRECTO a S3  3) confirma al backend
export async function uploadFile(file: File) {
  // Debe ser el MISMO Content-Type en ambos pasos: la URL firmada lo incluye en la firma
  const contentType = file.type || 'application/octet-stream';

  const { url, key } = await getUploadUrl(file.name, contentType);

  const res = await fetch(url, {
    method: 'PUT',
    body: file,
    headers: { 'Content-Type': contentType },
  });

  if (!res.ok) {
    throw new Error(`S3 rechazó la subida (HTTP ${res.status})`);
  }

  try {
    await confirmUpload(key);
  } catch (err) {
    const detail = err instanceof Error ? err.message : 'error desconocido';
    throw new Error(`El archivo se subió, pero no se pudo registrar: ${detail}`);
  }
}