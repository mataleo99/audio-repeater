import AVFoundation
import Accelerate

struct SilenceRegion {
    let start: TimeInterval
    let end: TimeInterval
}

struct SilenceDetector {
    let silenceThresholdDB: Float
    let minSilenceDuration: TimeInterval
    let minSegmentDuration: TimeInterval

    init(
        silenceThresholdDB: Float = AppConstants.defaultSilenceThresholdDB,
        minSilenceDuration: TimeInterval = AppConstants.defaultMinSilenceDuration,
        minSegmentDuration: TimeInterval = AppConstants.defaultMinSegmentDuration
    ) {
        self.silenceThresholdDB = silenceThresholdDB
        self.minSilenceDuration = minSilenceDuration
        self.minSegmentDuration = minSegmentDuration
    }

    func detectSilence(in url: URL) throws -> [SilenceRegion] {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw SilenceDetectorError.noAudioTrack
        }

        let reader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        let sampleRate = track.naturalTimeScale > 0 ? Double(track.naturalTimeScale) : 44100.0
        let windowSize = AppConstants.rmsWindowSize
        var allSamples: [Float] = []

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }

            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

            guard let data = dataPointer else { continue }

            let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer)
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc!)!.pointee
            let channelCount = Int(asbd.mChannelsPerFrame)
            let floatCount = length / MemoryLayout<Float>.size

            let floatPointer = data.withMemoryRebound(to: Float.self, capacity: floatCount) { ptr in
                Array(UnsafeBufferPointer(start: ptr, count: floatCount))
            }

            if channelCount > 1 {
                let monoCount = floatCount / channelCount
                var mono = [Float](repeating: 0, count: monoCount)
                for i in 0..<monoCount {
                    var sum: Float = 0
                    for ch in 0..<channelCount {
                        sum += floatPointer[i * channelCount + ch]
                    }
                    mono[i] = sum / Float(channelCount)
                }
                allSamples.append(contentsOf: mono)
            } else {
                allSamples.append(contentsOf: floatPointer)
            }
        }

        guard reader.status == .completed else {
            throw SilenceDetectorError.readingFailed
        }

        return findSilenceRegions(samples: allSamples, sampleRate: sampleRate, windowSize: windowSize)
    }

    private func findSilenceRegions(samples: [Float], sampleRate: Double, windowSize: Int) -> [SilenceRegion] {
        guard samples.count > windowSize else { return [] }

        var silenceRegions: [SilenceRegion] = []
        var silenceStart: Int?
        let hopSize = windowSize / 2

        var windowIndex = 0
        while windowIndex + windowSize <= samples.count {
            let window = Array(samples[windowIndex..<(windowIndex + windowSize)])
            var rms: Float = 0
            vDSP_rmsqv(window, 1, &rms, vDSP_Length(windowSize))

            let db: Float = rms > 0 ? 20.0 * log10(rms) : -160.0

            if db < silenceThresholdDB {
                if silenceStart == nil {
                    silenceStart = windowIndex
                }
            } else {
                if let start = silenceStart {
                    let startTime = Double(start) / sampleRate
                    let endTime = Double(windowIndex) / sampleRate
                    let duration = endTime - startTime
                    if duration >= minSilenceDuration {
                        silenceRegions.append(SilenceRegion(start: startTime, end: endTime))
                    }
                    silenceStart = nil
                }
            }

            windowIndex += hopSize
        }

        if let start = silenceStart {
            let startTime = Double(start) / sampleRate
            let endTime = Double(samples.count) / sampleRate
            let duration = endTime - startTime
            if duration >= minSilenceDuration {
                silenceRegions.append(SilenceRegion(start: startTime, end: endTime))
            }
        }

        return silenceRegions
    }

    enum SilenceDetectorError: Error {
        case noAudioTrack
        case readingFailed
    }
}
