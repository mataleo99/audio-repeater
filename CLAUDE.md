# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a native iOS SwiftUI app (iOS 18.0+, Swift 6.0). SPM dependency: DSWaveformImage (waveform rendering).

```bash
# Build for simulator (requires iOS simulator runtime installed)
xcodebuild -project AudioRepeater.xcodeproj -scheme AudioRepeater -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/audio-repeater-build build

# Build for device SDK without code signing (works without simulator runtime)
xcodebuild -project AudioRepeater.xcodeproj -target AudioRepeater -sdk iphoneos -arch arm64 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build

# Run tests (test targets exist but are currently empty)
xcodebuild -project AudioRepeater.xcodeproj -scheme AudioRepeater -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/audio-repeater-build test
```

Note: Info.plist lives at the project root (not inside `AudioRepeater/`) to avoid conflicts with the file-system-synchronized group auto-including it as a bundle resource.

Open `AudioRepeater.xcodeproj` in Xcode to build/run. The project uses file-system-synchronized groups (Xcode 16+), so new Swift files added to the `AudioRepeater/` directory are automatically discovered.

## Architecture

**MVVM + Service Layer** with `@Observable` (not ObservableObject) and `@MainActor` throughout:

```
SwiftUI Views → @Observable ViewModels → Services → SwiftData Models
```

### Threading model

Both `AudioPlayerService` and `PlayerViewModel` are `@MainActor`. AVAudioEngine manages its own audio render thread internally — our code only calls fast configuration/scheduling APIs on main. Time updates come from a 30 FPS Timer that reads `playerNode.playerTime(forNodeTime:)` and updates `@Observable` state.

### Audio engine

`AudioPlayerService` uses AVAudioEngine (not AVAudioPlayer) because we need:
- Buffer access for future waveform/amplitude features
- Sample-accurate seeking for segment boundaries
- `AVAudioUnitTimePitch` for speed changes without pitch distortion

Node graph: `AVAudioPlayerNode → AVAudioUnitTimePitch → mainMixerNode → outputNode`

Seek tracking uses a `seekFrame` offset combined with `playerNode.playerTime()` — `playerNode.currentTime` alone is unreliable after seeking.

### SwiftData model graph

`Project` is the aggregate root. All child models cascade-delete except `Folder` (nullify). Audio files live in `Documents/Audio/` on disk; SwiftData only stores metadata and the relative filename.

```
Project ──┬── [Segment]       (cascade)
          ├── [Bookmark]      (cascade)
          ├── [SubtitleTrack] (cascade) ── [SubtitleCue] (cascade)
          ├── Folder?         (nullify)
          └── Note?           (cascade)
```

### File import flow

`FileImportService` handles security-scoped URLs from `.fileImporter`: calls `startAccessingSecurityScopedResource()`, copies to `Documents/Audio/{UUID}.{ext}`, creates a `Project` in SwiftData, then stops access. Audio files are never stored inside SwiftData.

## Key Constants

Defined in `AppConstants.swift`:
- Silence detection defaults: -40dB threshold, 300ms min silence, 500ms min segment
- Speed range: 0.5x–2.0x
- Supported formats: mp3, m4a, wav, aac, aiff, caf (audio); srt, vtt (subtitles)

### Audio scheduling and the generation counter

`AudioPlayerService` uses a `scheduleGeneration` counter to prevent stale completion handlers from resetting playback state. Each call to `play()` or `seek()` increments the generation before `playerNode.stop()`. The completion handler captures the generation at schedule time and only runs `handlePlaybackCompletion` if it matches.

### Segment boundary monitoring

`AudioPlayerService.onTimeUpdate` callback fires at 30 FPS. `PlayerViewModel` uses it to detect when playback crosses segment boundaries, triggering auto-pause or repeat cycles based on `RepeatState`.

## Project Status

Phases 1-3 implemented: audio import, playback with speed control, library UI, waveform visualization with zoom, silence-based auto-segmentation, repeat/auto-pause state machine, segment marking (heart/star), segment editing (split/merge/delete with boundary dragging), bookmarks with tags, and per-project notes. Stub directories exist for future phases:
- `Services/Subtitles/` — SRT/VTT parsing, auto-generation
- `Services/Notifications/` — practice reminders
- `Views/Settings/`, `Views/Subtitles/` — UI for those features

Info.plist already declares background audio mode, speech recognition permission, and document type handlers for audio + subtitle files.
