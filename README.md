# Hushtune

A web app for iPhone that saves audio and video files to the phone, so you can
play them offline in any player.

Paste a link to a media file — or to a page that has one — choose **Download
video** or **Download audio**, then tap **Save to Files / Open in…** to send it
to the Files app or straight into a player such as VLC.

**Nothing to install.** Open
[sajjadshahpoor.github.io/Hushtune/app](https://sajjadshahpoor.github.io/Hushtune/app/)
in Safari on your iPhone, tap Share → **Add to Home Screen**, and it runs
full-screen like a native app.

## What it supports

Only **direct media files**: a real `.mp4`/`.m4a`/`.mp3`/… URL, or one
referenced by a page's `og:video`/`og:audio` tags, `<video>`/`<audio>`/`<source>`
elements, or plain links. Streaming playlists (HLS/DASH), `blob:`/`data:` URLs
and protected players such as YouTube are refused — those aren't downloadable
files. Only save files you have the right to download.

## How it works

- **`web/`** — the app (Vite + TypeScript + `vite-plugin-pwa`). Builds into
  `docs/app/`, which GitHub Pages serves. "Download audio" on a video extracts
  the audio track on the device with ffmpeg.wasm (loaded on first use, ~30 MB).
- **`proxy/`** — a Cloudflare Worker the app downloads through, since browsers
  can't read files from other sites directly (CORS). It only serves
  audio/video, only to the origins in `ALLOWED_ORIGINS`, refuses private
  network addresses, and caps file size (`MAX_BYTES`).
- **`docs/`** — the landing page, published with GitHub Pages.

## Hosting your own copy

Needs [Node.js](https://nodejs.org) and a free Cloudflare account. Works on
Windows, macOS or Linux.

1. **Deploy the proxy:**
   ```sh
   cd proxy
   npm install
   npx wrangler login
   npm run deploy        # prints https://hushtune-proxy.<you>.workers.dev
   ```
   If your site isn't `https://sajjadshahpoor.github.io`, change
   `ALLOWED_ORIGINS` in `proxy/wrangler.toml` first.
2. **Build the app** (optionally bake in the proxy URL):
   ```sh
   cd web
   npm install
   echo VITE_PROXY_URL=https://hushtune-proxy.<you>.workers.dev > .env.local
   npm run build         # writes docs/app/
   ```
   If you skip `VITE_PROXY_URL`, paste the proxy URL under **Settings** in the
   app instead.
3. **Publish:** commit and push. On GitHub, under **Settings → Pages**, set the
   source to **Deploy from a branch**, branch **main**, folder **/docs**. The
   landing page appears at `https://<user>.github.io/Hushtune/` and the app at
   `…/Hushtune/app/`.

### Local development

```sh
cd proxy && npm run dev   # proxy on http://127.0.0.1:8787, any origin allowed
cd web && npm run dev     # app on http://localhost:5173 and your LAN address
```

## iPhone limitations

- **Keep the app open while downloading.** iOS suspends web apps in the
  background, and Safari has no background-download API.
- Downloads are held in memory until saved, so very large files (well over
  1 GB) can fail on older iPhones. Audio extraction needs roughly 2–3× the
  video's size in memory.
