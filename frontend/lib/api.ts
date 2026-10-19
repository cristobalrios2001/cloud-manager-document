// NEXT_PUBLIC_* se inyecta en tiempo de BUILD: queda incrustado en el JS del navegador.
export const API_URL =
  process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000';

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

export const getViewUrl = (key: string) =>
  request<{ url: string; expiresIn: number }>('/documents/view-url', {
    method: 'POST',
    body: JSON.stringify({ key }),
  });

// 1) pide la URL firmada al backend  2) sube el archivo DIRECTO a S3
export async function uploadFile(file: File) {
  // Debe ser el MISMO Content-Type en ambos pasos: la URL firmada lo incluye en la firma
  const contentType = file.type || 'application/octet-stream';

  const { url } = await getUploadUrl(file.name, contentType);

  const res = await fetch(url, {
    method: 'PUT',
    body: file,
    headers: { 'Content-Type': contentType },
  });

  if (!res.ok) {
    throw new Error(`S3 rechazó la subida (HTTP ${res.status})`);
  }
}