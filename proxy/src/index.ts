// Hushtune media proxy.
//
// The web app can't read files from other sites directly (CORS), so it asks
// this Worker instead. Two endpoints:
//
//   GET /probe?url=…   Describe a direct media file, or — for an HTML page —
//                      find the direct media files it references
//                      (og:video/og:audio, <video>/<audio>/<source> src,
//                      links to media files) and describe those.
//   GET /fetch?url=…   Stream a direct media file back with CORS headers.
//
// Only real, fetchable audio/video files are served. Streaming playlists
// (HLS/DASH), blob:/data: URLs and anything that isn't audio/video are refused.

interface Env {
  /** Comma-separated origins allowed to call the proxy, or "*". */
  ALLOWED_ORIGINS: string;
  /** Largest file /fetch will serve, in bytes. */
  MAX_BYTES: string;
}

type Kind = 'audio' | 'video';

interface MediaInfo {
  url: string;
  type: string;
  size: number | null;
  name: string;
  kind: Kind;
}

const MEDIA_EXT: Record<string, Kind> = {
  mp4: 'video', m4v: 'video', mov: 'video', webm: 'video', mkv: 'video', '3gp': 'video',
  mp3: 'audio', m4a: 'audio', aac: 'audio', wav: 'audio', flac: 'audio',
  ogg: 'audio', oga: 'audio', opus: 'audio',
};

const GENERIC_TYPES = new Set(['', 'application/octet-stream', 'binary/octet-stream', 'application/x-download']);
// Used only if the caller sends no User-Agent. Some hosts reject unfamiliar
// agents, so the user's own browser agent is forwarded when present.
const FALLBACK_UA = 'Mozilla/5.0 (compatible; Hushtune/1.0; +https://github.com/sajjadshahpoor/Hushtune)';
const MAX_HTML_BYTES = 5 * 1024 * 1024;
const MAX_CANDIDATES = 10;

class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const origin = req.headers.get('Origin') ?? '';
    const allowed = env.ALLOWED_ORIGINS.split(',').map((s) => s.trim());
    if (!allowed.includes('*') && !allowed.includes(origin)) {
      return new Response('Origin not allowed', { status: 403 });
    }
    const cors = {
      'Access-Control-Allow-Origin': origin || '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Type, X-Filename',
      Vary: 'Origin',
    };
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (req.method !== 'GET') return new Response('Method not allowed', { status: 405, headers: cors });

    const { pathname, searchParams } = new URL(req.url);
    const ua = req.headers.get('User-Agent') || FALLBACK_UA;
    try {
      const target = checkTarget(searchParams.get('url'));
      if (pathname === '/probe') return json(await probe(target, ua), cors);
      if (pathname === '/fetch') return await proxyFile(target, ua, Number(env.MAX_BYTES), cors);
      throw new HttpError(404, 'Not found');
    } catch (e) {
      const status = e instanceof HttpError ? e.status : 502;
      const message = e instanceof Error ? e.message : String(e);
      return json({ error: message }, cors, status);
    }
  },
} satisfies ExportedHandler<Env>;

function checkTarget(raw: string | null): URL {
  if (!raw) throw new HttpError(400, 'Missing url parameter');
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    throw new HttpError(400, 'That is not a valid URL');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new HttpError(400, 'Only http and https URLs are supported');
  }
  const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, '');
  const privateHost =
    host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.local') || host.endsWith('.internal') ||
    /^(0|10|127)\./.test(host) || /^169\.254\./.test(host) || /^192\.168\./.test(host) ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(host) || host === '::1' || /^f[cd][0-9a-f]{2}:/.test(host) || /^fe80:/.test(host);
  if (privateHost) throw new HttpError(400, 'Private network addresses are not allowed');
  return url;
}

async function probe(target: URL, ua: string): Promise<{ title: string; files: MediaInfo[] }> {
  const res = await upstream(target, ua);
  const type = mimeOf(res);

  const direct = describe(res, type);
  if (direct) {
    await res.body?.cancel();
    return { title: direct.name, files: [direct] };
  }

  if (type === 'text/html' || type === 'application/xhtml+xml') {
    const length = Number(res.headers.get('content-length'));
    if (length > MAX_HTML_BYTES) {
      await res.body?.cancel();
      throw new HttpError(413, 'That page is too large to scan');
    }
    const { title, urls } = await scanPage(res);
    const files = (await Promise.all(urls.map((u) => probeFile(u, ua).catch(() => null)))).filter(
      (f): f is MediaInfo => f !== null,
    );
    if (files.length === 0) throw new HttpError(404, 'No downloadable audio or video files found on that page');
    return { title, files };
  }

  await res.body?.cancel();
  if (type.includes('mpegurl') || type.includes('dash+xml')) {
    throw new HttpError(415, 'That is a streaming playlist, not a downloadable file');
  }
  throw new HttpError(415, `Not an audio or video file (${type || 'unknown type'})`);
}

/** Describe a candidate URL found on a page, without downloading it. */
async function probeFile(url: string, ua: string): Promise<MediaInfo | null> {
  const target = checkTarget(url);
  let res = await upstream(target, ua, 'HEAD');
  if (!res.ok || !res.headers.get('content-type')) {
    // Some servers reject HEAD; ask for the first byte instead.
    res = await upstream(target, ua, 'GET', { Range: 'bytes=0-0' });
    await res.body?.cancel();
  }
  return describe(res, mimeOf(res));
}

async function proxyFile(target: URL, ua: string, maxBytes: number, cors: Record<string, string>): Promise<Response> {
  const res = await upstream(target, ua);
  const info = describe(res, mimeOf(res));
  if (!info) {
    await res.body?.cancel();
    throw new HttpError(415, 'Not a downloadable audio or video file');
  }
  if (info.size !== null && info.size > maxBytes) {
    await res.body?.cancel();
    throw new HttpError(413, `File is larger than the ${Math.round(maxBytes / 1e6)} MB limit`);
  }

  // A known size is passed through as Content-Length (so the app can show a
  // progress bar); otherwise count bytes and stop at the limit.
  let seen = 0;
  const stream =
    info.size !== null
      ? new FixedLengthStream(info.size)
      : new TransformStream<Uint8Array, Uint8Array>({
          transform(chunk, ctrl) {
            seen += chunk.byteLength;
            if (seen > maxBytes) ctrl.error(new Error('File exceeded the size limit'));
            else ctrl.enqueue(chunk);
          },
        });

  return new Response(res.body!.pipeThrough(stream), {
    headers: {
      ...cors,
      'Content-Type': info.type,
      'X-Filename': encodeURIComponent(info.name),
      'Cache-Control': 'no-store',
    },
  });
}

async function upstream(target: URL, ua: string, method = 'GET', extra: Record<string, string> = {}): Promise<Response> {
  const res = await fetch(target.href, { method, redirect: 'follow', headers: { 'User-Agent': ua, ...extra } });
  if (!res.ok && res.status !== 206) {
    await res.body?.cancel();
    throw new HttpError(502, `The site responded with HTTP ${res.status}`);
  }
  return res;
}

function mimeOf(res: Response): string {
  return (res.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase();
}

function extOf(pathname: string): string {
  const m = /\.([a-z0-9]{2,4})$/i.exec(pathname);
  return m ? m[1].toLowerCase() : '';
}

/** Returns file details if the response is a direct audio/video file, else null. */
function describe(res: Response, type: string): MediaInfo | null {
  const finalUrl = new URL(res.url);
  const name = fileName(res, finalUrl);
  const ext = extOf(name) || extOf(finalUrl.pathname);

  let kind: Kind | undefined;
  if (type.startsWith('audio/') && !type.includes('mpegurl')) kind = 'audio';
  else if (type.startsWith('video/') && !type.includes('mpegurl') && type !== 'video/mp2t') kind = 'video';
  else if (GENERIC_TYPES.has(type)) kind = MEDIA_EXT[ext];
  if (!kind) return null;

  return {
    url: finalUrl.href,
    type: GENERIC_TYPES.has(type) ? `${kind}/${ext === 'mov' ? 'quicktime' : ext === 'm4a' ? 'mp4' : ext}` : type,
    size: sizeOf(res),
    name,
    kind,
  };
}

function sizeOf(res: Response): number | null {
  const range = /\/(\d+)$/.exec(res.headers.get('content-range') ?? '');
  if (range) return Number(range[1]);
  const length = res.headers.get('content-length');
  return length && res.status === 200 ? Number(length) : null;
}

function fileName(res: Response, url: URL): string {
  const cd = res.headers.get('content-disposition') ?? '';
  const star = /filename\*\s*=\s*(?:UTF-8|utf-8)''([^;]+)/.exec(cd);
  const plain = /filename\s*=\s*"?([^";]+)"?/.exec(cd);
  let name = '';
  try {
    name = star ? decodeURIComponent(star[1]) : plain ? plain[1] : decodeURIComponent(url.pathname.split('/').pop() ?? '');
  } catch {
    name = url.pathname.split('/').pop() ?? '';
  }
  name = name.replace(/[\\/:*?"<>|\x00-\x1f]+/g, '_').trim();
  return name || 'download';
}

async function scanPage(res: Response): Promise<{ title: string; urls: string[] }> {
  const base = res.url;
  const urls: string[] = [];
  let ogTitle = '';
  let docTitle = '';

  const add = (value: string | null, mustLookLikeMedia = false) => {
    if (!value) return;
    try {
      const u = new URL(value.trim(), base);
      if (u.protocol !== 'http:' && u.protocol !== 'https:') return; // skips blob:, data:, javascript:
      if (mustLookLikeMedia && !MEDIA_EXT[extOf(u.pathname)]) return;
      if (!urls.includes(u.href)) urls.push(u.href);
    } catch {
      /* ignore unparsable URLs */
    }
  };

  await new HTMLRewriter()
    .on('meta', {
      element(el) {
        const prop = (el.getAttribute('property') ?? el.getAttribute('name') ?? '').toLowerCase();
        const content = el.getAttribute('content');
        if (/^og:(video|audio)(:url|:secure_url)?$/.test(prop) || prop === 'twitter:player:stream') add(content);
        else if (prop === 'og:title' && !ogTitle) ogTitle = content ?? '';
      },
    })
    .on('video[src], audio[src], video source[src], audio source[src]', {
      element(el) {
        add(el.getAttribute('src'));
      },
    })
    .on('a[href]', {
      element(el) {
        add(el.getAttribute('href'), true);
      },
    })
    .on('title', {
      text(t) {
        docTitle += t.text;
      },
    })
    .transform(res)
    .arrayBuffer();

  return { title: (ogTitle || docTitle).trim(), urls: urls.slice(0, MAX_CANDIDATES) };
}

function json(body: unknown, cors: Record<string, string>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}
