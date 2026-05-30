# AudioRepeater

A native iOS audio player for language learners — a WorkAudioBook-style "listen, repeat, advance" workflow built in SwiftUI.

Import an audio file (podcast, audiobook, language lesson), auto-detect phrase boundaries from silence, and loop individual phrases until you can repeat them back. Optional subtitles (SRT/VTT or auto-generated from speech).

## Requirements

- iOS 18.0+
- Xcode 26.0+
- Swift 6.0

## Build & Run

Open `AudioRepeater.xcodeproj` in Xcode and hit ⌘R.

From the command line:

```bash
# Simulator
xcodebuild -project AudioRepeater.xcodeproj -scheme AudioRepeater \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Device (no code signing)
xcodebuild -project AudioRepeater.xcodeproj -target AudioRepeater \
  -sdk iphoneos -arch arm64 \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

Auto-Generate Subtitles requires a physical device — `SFSpeechRecognizer` does not work in the simulator.

## Architecture

MVVM + service layer, `@Observable` (not `ObservableObject`), `@MainActor` throughout.

```
SwiftUI Views → @Observable ViewModels → Services → SwiftData Models
```

### Audio engine

`AudioPlayerService` uses `AVAudioEngine` (not `AVAudioPlayer`) for buffer access, sample-accurate seeking, and pitch-preserving speed changes.

```
AVAudioPlayerNode → AVAudioUnitTimePitch → mainMixerNode → outputNode
```

### Data model

`Project` is the aggregate root. Audio files live in `Documents/Audio/` on disk; SwiftData stores only metadata.

```
Project ──┬── [Segment]       (cascade)
          ├── [Bookmark]      (cascade)
          ├── [SubtitleTrack] (cascade) ── [SubtitleCue] (cascade)
          ├── Folder?         (nullify)
          └── Note?           (cascade)
```

### Segmentation

Silence detection runs on a background `@ModelActor`. PCM samples are read via `AVAssetReader`, processed with `vDSP.rootMeanSquare()` in 10ms windows, and silence regions below -35dB lasting ≥100ms become phrase boundaries. Tuned for spoken-word content.

## Features

- Import MP3 / M4A / WAV / AAC / AIFF / CAF audio
- Auto-segmentation into phrases via silence detection
- Waveform with zoom, tap-to-seek, segment overlays
- Loop a single phrase indefinitely; advance to next phrase on command
- Variable playback speed (0.5x–2.0x) without pitch distortion
- Heart / star marks on segments
- Edit segment boundaries (split, merge, delete, drag)
- Per-project bookmarks (tagged) and notes
- Resume playback position
- Import SRT / VTT subtitles
- Auto-generate subtitles from speech (device only)

## Dependencies

- [DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage) — waveform rendering (SPM)

## License

Personal project.
