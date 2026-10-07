import './style.css';
import { download, getProxyUrl, probe, setProxyUrl, type Kind, type MediaInfo } from './api';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;

const form = $<HTMLFormElement>('probe-form');
const urlInput = $<HTMLInputElement>('url');
const findBtn = $<HTMLButtonElement>('find');
const errorEl = $('error');
const results = $('results');
const filesList = $<HTMLUListElement>('files');
const progress = $('progress');
const progressLabel = $('progress-label');
const progressBar = $<HTMLProgressElement>('progress-bar');
const progressDetail = $('progress-detail');
const cancelBtn = $<HTMLButtonElement>('cancel');
const done = $('done');
const saveBtn = $<HTMLButtonElement>('save');
const settings = $<HTMLDetailsElement>('settings');
const proxyInput = $<HTMLInputElement>('proxy');

let ready: File | null = null;
let abort: AbortController | null = null;

proxyInput.value = getProxyUrl();
if (!proxyInput.value) settings.open = true;
proxyInput.addEventListener('change', () => setProxyUrl(proxyInput.value.trim()));

$('paste').addEventListener('click', async () => {
  try {
    urlInput.value = (await navigator.clipboard.readText()).trim();
  } catch {
    urlInput.focus();
  }
});

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  showError(null);
  results.hidden = true;
  findBtn.disabled = true;
  findBtn.textContent = 'Looking…';
  try {
    const { title, files } = await probe(urlInput.value.trim());
    renderResults(title, files);
  } catch (err) {
    showError(err);
  } finally {
    findBtn.disabled = false;
    findBtn.textContent = 'Find media';
  }
});

cancelBtn.addEventListener('click', () => abort?.abort());

saveBtn.addEventListener('click', async () => {
  if (!ready) return;
  try {
    await saveFile(ready);
  } catch (err) {
    showError(err);
  }
});

function renderResults(title: string, files: MediaInfo[]) {
  $('results-title').textContent = title || 'Found';
  filesList.replaceChildren(
    ...files.map((file) => {
      const li = document.createElement('li');
      li.className = 'card file';

      const name = document.createElement('p');
      name.className = 'file-name';
      name.textContent = file.name;

      const meta = document.createElement('p');
      meta.className = 'muted small';
      meta.textContent = [file.kind === 'video' ? 'Video' : 'Audio', formatBytes(file.size), file.type].filter(Boolean).join(' · ');

      const actions = document.createElement('div');
      actions.className = 'row';
      const modes: Kind[] = file.kind === 'video' ? ['video', 'audio'] : ['audio'];
      for (const mode of modes) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = mode === modes[0] ? 'primary' : 'ghost';
        btn.textContent = mode === 'video' ? 'Download video' : 'Download audio';
        btn.addEventListener('click', () => start(file, mode));
        actions.append(btn);
      }

      li.append(name, meta, actions);
      return li;
    }),
  );
  results.hidden = false;
}

async function start(file: MediaInfo, mode: Kind) {
  showError(null);
  ready = null;
  done.hidden = true;
  setBusy(true);
  abort = new AbortController();
  const wakeLock = await navigator.wakeLock?.request('screen').catch(() => null);

  try {
    progressLabel.textContent = `Downloading ${file.name}`;
    cancelBtn.hidden = false;
    const blob = await download(
      file,
      (received, total) => {
        progressBar.value = total ? received / total : NaN;
        progressDetail.textContent = total ? `${formatBytes(received)} of ${formatBytes(total)}` : formatBytes(received);
      },
      abort.signal,
    );

    let output = blob;
    let name = withExtension(file.name, blob.type);
    if (mode === 'audio' && file.kind === 'video') {
      cancelBtn.hidden = true;
      progressLabel.textContent = 'Extracting audio…';
      progressBar.removeAttribute('value');
      progressDetail.textContent = 'The first time, this also downloads the converter (~30 MB).';
      const { extractAudio } = await import('./extract');
      output = await extractAudio(blob, (ratio) => {
        progressBar.value = ratio;
        progressDetail.textContent = `${Math.round(ratio * 100)}%`;
      });
      name = name.replace(/\.[a-z0-9]{2,4}$/i, '') + '.m4a';
    }

    ready = new File([output], name, { type: output.type });
    $('done-name').textContent = ready.name;
    $('done-size').textContent = formatBytes(ready.size);
    done.hidden = false;
    done.scrollIntoView({ behavior: 'smooth', block: 'center' });
  } catch (err) {
    if (!(err instanceof DOMException && err.name === 'AbortError')) showError(err);
  } finally {
    abort = null;
    setBusy(false);
    await wakeLock?.release().catch(() => {});
  }
}

/**
 * iOS: open the share sheet ("Save to Files", VLC, …). Sharing needs a fresh
 * tap, which is why this runs from the Save button rather than automatically
 * when the download finishes. Elsewhere: a normal browser download.
 */
async function saveFile(file: File) {
  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file] });
    } catch (err) {
      if (!(err instanceof DOMException && err.name === 'AbortError')) throw err;
    }
    return;
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(file);
  a.download = file.name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 60_000);
}

function setBusy(busy: boolean) {
  progress.hidden = !busy;
  if (busy) {
    progressBar.value = 0;
    progressDetail.textContent = '';
  }
  for (const btn of document.querySelectorAll<HTMLButtonElement>('#files button, #find')) btn.disabled = busy;
}

function showError(err: unknown) {
  errorEl.hidden = err == null;
  errorEl.textContent = err instanceof Error ? err.message : err == null ? '' : String(err);
}

function withExtension(name: string, type: string): string {
  if (/\.[a-z0-9]{2,4}$/i.test(name)) return name;
  const ext: Record<string, string> = {
    'video/mp4': 'mp4', 'video/quicktime': 'mov', 'video/webm': 'webm',
    'audio/mpeg': 'mp3', 'audio/mp4': 'm4a', 'audio/aac': 'aac', 'audio/wav': 'wav', 'audio/ogg': 'ogg', 'audio/flac': 'flac',
  };
  return ext[type] ? `${name}.${ext[type]}` : name;
}

function formatBytes(n: number | null): string {
  if (n == null) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  while (n >= 1000 && i < units.length - 1) {
    n /= 1000;
    i++;
  }
  return `${n.toFixed(i === 0 || n >= 100 ? 0 : 1)} ${units[i]}`;
}

// Allow opening the app as …/app/?url=<link>, e.g. from an iOS Shortcut.
const initial = new URLSearchParams(location.search).get('url');
if (initial) {
  urlInput.value = initial;
  if (getProxyUrl()) form.requestSubmit();
}
