// Client for the proxy Worker in ../proxy.

export type Kind = 'audio' | 'video';

export interface MediaInfo {
  url: string;
  type: string;
  size: number | null;
  name: string;
  kind: Kind;
}

const STORAGE_KEY = 'hushtune.proxyUrl';

export function getProxyUrl(): string {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) return saved;
  } catch {
    /* storage unavailable */
  }
  return import.meta.env.VITE_PROXY_URL ?? '';
}

export function setProxyUrl(url: string): void {
  try {
    if (url) localStorage.setItem(STORAGE_KEY, url);
    else localStorage.removeItem(STORAGE_KEY);
  } catch {
    /* storage unavailable */
  }
}

function endpoint(path: string, target: string): string {
  const base = getProxyUrl().replace(/\/+$/, '');
  if (!base) throw new Error('Set the proxy URL in Settings first.');
  return `${base}${path}?url=${encodeURIComponent(target)}`;
}

async function failure(res: Response): Promise<Error> {
  try {
    const body = await res.json();
    if (body?.error) return new Error(body.error);
  } catch {
    /* not JSON */
  }
  return new Error(`Proxy error (HTTP ${res.status})`);
}

export async function probe(url: string): Promise<{ title: string; files: MediaInfo[] }> {
  const res = await fetch(endpoint('/probe', url));
  if (!res.ok) throw await failure(res);
  return res.json();
}

/** Download a file through the proxy, reporting bytes received as they arrive. */
export async function download(
  file: MediaInfo,
  onProgress: (received: number, total: number | null) => void,
  signal: AbortSignal,
): Promise<Blob> {
  const res = await fetch(endpoint('/fetch', file.url), { signal });
  if (!res.ok) throw await failure(res);

  const total = Number(res.headers.get('content-length')) || file.size;
  const reader = res.body!.getReader();
  const chunks: Uint8Array<ArrayBuffer>[] = [];
  let received = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    received += value.byteLength;
    onProgress(received, total);
  }
  return new Blob(chunks, { type: res.headers.get('content-type') ?? file.type });
}
