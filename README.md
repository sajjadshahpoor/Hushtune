# Hushtune

An iOS app with two parts:

1. A YouTube browsing/player tab built on YouTube's official Data API v3 and
   IFrame Player API (see the notes below — unchanged from before).
2. A **general-purpose mobile web browser** tab with ad blocking, a video
   download manager, and background audio, built entirely on standard, public
   iOS frameworks (`WKWebView`, `WKContentRuleList`, `AVAudioSession`,
   `URLSession`) — the same APIs Safari, Firefox, and Brave use for the same
   features.

There's also a **web app** (`web/` + `proxy/`) that runs on iPhone from the
Home Screen, with no Mac or Xcode needed — see below.

## Web app (iPhone, no Mac needed)

A Progressive Web App that saves audio and video files to the phone. Paste a
link to a media file — or to a page that has one — choose **Download video**
or **Download audio**, then tap **Save to Files / Open in…** to send it to the
Files app or straight into a player such as VLC.

Same rule as the browser tab: only **direct media files** are supported (a
real `.mp4`/`.m4a`/`.mp3`/… URL, or one referenced by a page's
`og:video`/`og:audio`, `<video>`/`<audio>`/`<source>` tags or links).
Streaming playlists, `blob:`/`data:` URLs and protected players are refused.

- **`web/`** — the app (Vite + TypeScript + `vite-plugin-pwa`). Builds into
  `docs/app/`, served at `https://sajjadshahpoor.github.io/Hushtune/app/`.
  "Download audio" on a video extracts the audio track on the device with
  ffmpeg.wasm (loaded on first use, ~30 MB).
- **`proxy/`** — a Cloudflare Worker the app downloads through, since
  browsers can't read files from other sites directly (CORS). It only serves
  audio/video, only to the origins in `ALLOWED_ORIGINS`, refuses private
  network addresses, and caps file size (`MAX_BYTES`).

### Setup

1. **Deploy the proxy** (free Cloudflare account):
   ```sh
   cd proxy
   npm install
   npx wrangler login
   npm run deploy        # prints https://hushtune-proxy.<you>.workers.dev
   ```
2. **Build the app** (optionally bake in the proxy URL):
   ```sh
   cd web
   npm install
   echo VITE_PROXY_URL=https://hushtune-proxy.<you>.workers.dev > .env.local
   npm run build         # writes docs/app/
   ```
   Commit and push `docs/app/`; GitHub Pages publishes it (see the Pages
   setup below).
3. **On the iPhone**, open `https://sajjadshahpoor.github.io/Hushtune/app/`
   in Safari → Share → **Add to Home Screen**. If you skipped
   `VITE_PROXY_URL`, paste the proxy URL under **Settings** in the app.

### Local development

```sh
cd proxy && npm run dev   # proxy on http://127.0.0.1:8787, any origin allowed
cd web && npm run dev     # app on http://localhost:5173 and your LAN address
```

### iPhone limitations

- **Keep the app open while downloading.** iOS suspends web apps in the
  background, and Safari has no background-download API.
- Downloads are held in memory until saved, so very large files (well over
  1 GB) can fail on older iPhones. Audio extraction needs roughly 2–3× the
  video's size in memory.

## What this is — and isn't

### YouTube tab

This uses only YouTube's **official, public APIs**:

- **YouTube Data API v3** for search and trending video metadata.
- **YouTube IFrame Player API**, the same embeddable player YouTube provides for
  any website/app, loaded here in a `WKWebView`.

Because of that, a few things are true by design and are not bugs to "fix":

- **Ads still play.** YouTube serves and controls ads inside its own player.
  There is no supported way to remove them, and this project does not attempt to.
- **Playback pauses when the app is backgrounded/minimized**, the same way a
  YouTube tab in Safari behaves. This is enforced by the embedded player itself.
  Uninterrupted background/PiP playback is YouTube Premium's feature and isn't
  available through the public embed — this app doesn't try to circumvent that.
- Use of the YouTube API is subject to the [YouTube API Services Terms of Service](https://developers.google.com/youtube/terms/api-services-terms-of-service)
  and [YouTube Terms of Service](https://www.youtube.com/t/terms). Don't modify
  this project to strip ads, hide required attribution, or otherwise work around
  those terms.

### Browser tab

- **Ad/tracker blocking** uses Apple's `WKContentRuleList` API (the same
  mechanism behind Safari content blockers) against a curated list of common
  ad/tracker domains in `Sources/Resources/adblock_rules.json`, plus a
  popup blocker that redirects `window.open()`/`target="_blank"` navigations
  into the current tab instead of spawning a new window.
- **Video download** (auto-detected and manual-URL) only works on **direct
  media file URLs** — a page's `<video src="...">`, `<source>`, or
  `og:video` tag pointing at a real `.mp4`/`.mov`/etc. file. It deliberately
  ignores `blob:` and `data:` URLs, which is what most custom in-page video
  players (YouTube included) use — those aren't real, fetchable network
  resources, so there's nothing for a download manager to legitimately pull.
  This isn't a missing feature to add later; it's the actual distinction
  between "a link to a video file" and "a proprietary streaming player."
- **Background audio** configures a real `AVAudioSession` in `.playback`
  category with the `audio` background mode declared in `Info.plist`, which
  is what keeps ordinary web media playing when you lock the screen or
  switch apps. Pages that deliberately pause themselves via JavaScript on
  `visibilitychange`/`blur` (YouTube does this) will still pause — this app
  does not inject scripts to spoof page-visibility state to defeat that.

## Requirements

- A Mac with **Xcode 15+** installed (iOS apps can only be built with Xcode).
- [Homebrew](https://brew.sh)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — generates the `.xcodeproj`
  from `project.yml` (more reliable than hand-editing Xcode project files).

## 1. Get a YouTube Data API v3 key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project (or pick an existing one) from the project dropdown at the top.
3. In the left menu go to **APIs & Services -> Library**.
4. Search for **YouTube Data API v3** and click **Enable**.
5. Go to **APIs & Services -> Credentials**.
6. Click **Create Credentials -> API key**. Copy the key that's generated.
7. (Recommended) Click **Edit API key** and under **API restrictions** choose
   **Restrict key -> YouTube Data API v3**, so the key can't be used for other
   Google APIs if it ever leaks.
8. This API has a free daily quota (10,000 units/day by default), which is
   plenty for personal use — a search costs 100 units, a details lookup ~1-5.

## 2. Generate the Xcode project

```bash
brew install xcodegen
cd path/to/Hushtune
xcodegen generate
open Hushtune.xcodeproj
```

## 3. Add your API key

Open `Sources/Config.swift` and replace the placeholder:

```swift
static let youTubeAPIKey = "YOUR_YOUTUBE_API_KEY_HERE"
```

with the key you created above.

## 4. Run it

In Xcode, pick an iPhone simulator (or your device) and hit **Run** (Cmd+R).

- **Home** tab shows currently trending YouTube videos.
- **Search** tab searches YouTube by keyword.
- Tapping a video opens the player screen with a custom scrubber, play/pause
  button, and title/channel info drawn in SwiftUI, wrapping YouTube's actual
  video player underneath.
- **Browser** tab is a general web browser: URL/search bar, back/forward/reload,
  an ad-block toggle, and a banner that appears when a downloadable video is
  detected on the current page.
- **Downloads** tab lists in-progress and completed downloads (from the
  browser's auto-detect banner or a manually pasted URL) and plays finished
  videos in a full-screen player.

## Project layout

```
Sources/
  HushtuneApp.swift               entry point (also activates the audio session)
  Config.swift                    YouTube API key
  Models/YouTubeModels.swift       Codable models for the YouTube Data API
  Networking/YouTubeAPIService.swift  search / trending / details calls
  Utilities/Formatters.swift       ISO-8601 duration + view count formatting
  Audio/AudioSessionManager.swift  AVAudioSession config for background playback
  AdBlock/AdBlockManager.swift     compiles/caches the WKContentRuleList
  Downloads/
    DownloadItem.swift             download model
    DownloadManager.swift          URLSession-based download queue
  Views/
    RootTabView.swift              tab bar (Home / Search / Browser / Downloads)
    HomeView.swift                 trending list
    SearchView.swift               search bar + results
    VideoRowView.swift             thumbnail/title/channel row
    PlayerView.swift                custom YouTube player chrome
    YouTubePlayerWebView.swift      WKWebView <-> YouTube IFrame API bridge
    BrowserView.swift               URL bar, toolbar, detected-video banner
    BrowserWebView.swift            general WKWebView: ad block, popup block,
                                     video detection script bridge
    ManualDownloadSheet.swift       paste-a-URL download sheet
    DownloadsView.swift             download list + full-screen player
  Resources/
    youtube_player.html            local page hosting the YouTube IFrame player
    adblock_rules.json             WKContentRuleList ad/tracker block list
```

## Distribution note

This project is not set up for App Store distribution and isn't intended to be
a YouTube Premium replacement — background/ad-free playback specifically isn't
something this (or any) app built on the public embed can provide. If you want
uninterrupted background YouTube playback, that's what YouTube Premium is for.

## Landing page (GitHub Pages)

`docs/` contains a static landing page — hero, feature list, install steps,
and a releases section that fetches live from the GitHub Releases API (so it
updates on its own when a new release is published, no HTML edits needed).

**One-time setup** (from the repo's GitHub page):

1. Go to **Settings -> Pages**.
2. Under **Build and deployment -> Source**, choose **Deploy from a branch**.
3. Branch: **main**, folder: **/docs**. Save.
4. The site publishes at `https://sajjadshahpoor.github.io/Hushtune/` within a
   few minutes.

**Publishing a release** so the "Download" button and Releases list have
something to point at: build and sign an `.ipa` in Xcode (Product -> Archive,
then export for ad-hoc/development distribution), then on GitHub go to
**Releases -> Draft a new release**, tag it (e.g. `v1.0.0`), and attach the
`.ipa` file as a release asset. The landing page picks it up automatically.
