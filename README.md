# Hushtune

An iOS app that browses and searches YouTube (via the official YouTube Data API v3)
and plays videos using YouTube's official embeddable IFrame Player, wrapped in a
custom SwiftUI "Hushtune" interface.

## What this is — and isn't

This app uses only YouTube's **official, public APIs**:

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

- **Home** tab shows currently trending videos.
- **Search** tab searches YouTube by keyword.
- Tapping a video opens the player screen with a custom scrubber, play/pause
  button, and title/channel info drawn in SwiftUI, wrapping YouTube's actual
  video player underneath.

## Project layout

```
Sources/
  HushtuneApp.swift              entry point
  Config.swift                   API key
  Models/YouTubeModels.swift      Codable models for the YouTube Data API
  Networking/YouTubeAPIService.swift  search / trending / details calls
  Utilities/Formatters.swift      ISO-8601 duration + view count formatting
  Views/
    RootTabView.swift             tab bar / API-key-missing state
    HomeView.swift                trending list
    SearchView.swift              search bar + results
    VideoRowView.swift            thumbnail/title/channel row
    PlayerView.swift               custom player chrome (scrubber, play/pause)
    YouTubePlayerWebView.swift     WKWebView <-> YouTube IFrame API bridge
  Resources/youtube_player.html   local page hosting the YouTube IFrame player
```

## Distribution note

This project is not set up for App Store distribution and isn't intended to be
a YouTube Premium replacement — background/ad-free playback specifically isn't
something this (or any) app built on the public embed can provide. If you want
uninterrupted background YouTube playback, that's what YouTube Premium is for.
