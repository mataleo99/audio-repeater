import Foundation
import SwiftData
import AVFoundation

struct FileImportService {
    static func importAudioFile(
        from sourceURL: URL,
        modelContext: ModelContext
    ) throws -> Project {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = documentsURL.appendingPathComponent(AppConstants.audioDirectory)

        if !fileManager.fileExists(atPath: audioDir.path) {
            try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = audioDir.appendingPathComponent(fileName)

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let title = sourceURL.deletingPathExtension().lastPathComponent
        let duration = Self.getAudioDuration(url: destinationURL)

        let project = Project(
            title: title,
            audioFileName: fileName,
            audioFormat: fileExtension,
            duration: duration
        )

        modelContext.insert(project)
        try modelContext.save()

        return project
    }

    private static func getAudioDuration(url: URL) -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            return Double(audioFile.length) / audioFile.processingFormat.sampleRate
        } catch {
            print("Failed to get audio duration: \(error)")
            return 0
        }
    }
}
