// Pull the audio track out of a downloaded video, on the device, with ffmpeg.wasm.
// The ~30 MB ffmpeg core is only fetched the first time someone picks "Audio"
// for a video file.

import { FFmpeg } from '@ffmpeg/ffmpeg';
import { toBlobURL } from '@ffmpeg/util';

// Single-threaded core: GitHub Pages can't send the COOP/COEP headers the
// multi-threaded build needs.
const CORE = 'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/esm';

let loading: Promise<FFmpeg> | null = null;

function load(): Promise<FFmpeg> {
  loading ??= (async () => {
    const ffmpeg = new FFmpeg();
    await ffmpeg.load({
      coreURL: await toBlobURL(`${CORE}/ffmpeg-core.js`, 'text/javascript'),
      wasmURL: await toBlobURL(`${CORE}/ffmpeg-core.wasm`, 'application/wasm'),
    });
    return ffmpeg;
  })().catch((e) => {
    loading = null;
    throw e;
  });
  return loading;
}

/** Returns the video's audio as an .m4a (AAC) file. */
export async function extractAudio(video: Blob, onProgress: (ratio: number) => void): Promise<Blob> {
  const ffmpeg = await load();
  const report = ({ progress }: { progress: number }) => onProgress(Math.min(Math.max(progress, 0), 1));
  ffmpeg.on('progress', report);
  try {
    await ffmpeg.writeFile('input', new Uint8Array(await video.arrayBuffer()));
    // Copying the existing audio track is near-instant; re-encode only if the
    // source codec can't go in an .m4a (e.g. Opus in a WebM).
    let code = await ffmpeg.exec(['-y', '-i', 'input', '-vn', '-c:a', 'copy', 'output.m4a']);
    if (code !== 0) code = await ffmpeg.exec(['-y', '-i', 'input', '-vn', '-c:a', 'aac', '-b:a', '192k', 'output.m4a']);
    if (code !== 0) throw new Error('Could not extract audio from this file.');
    const data = (await ffmpeg.readFile('output.m4a')) as Uint8Array<ArrayBuffer>;
    return new Blob([data], { type: 'audio/mp4' });
  } finally {
    ffmpeg.off('progress', report);
    await ffmpeg.deleteFile('input').catch(() => {});
    await ffmpeg.deleteFile('output.m4a').catch(() => {});
  }
}
