import Foundation

struct VTTParser {
    struct Cue {
        let index: Int
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String
    }

    static func parse(from url: URL) throws -> [Cue] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parse(content: content)
    }

    static func parse(content: String) -> [Cue] {
        var cues: [Cue] = []
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")

        // Split into blocks separated by blank lines
        let blocks = normalized.components(separatedBy: "\n\n")

        var cueIndex = 1
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")

            // Skip the WEBVTT header and NOTE blocks
            if lines.first?.hasPrefix("WEBVTT") == true { continue }
            if lines.first?.hasPrefix("NOTE") == true { continue }
            if lines.first?.hasPrefix("STYLE") == true { continue }

            // Find the timing line (contains "-->")
            guard let timingLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }

            guard let (start, end) = parseTimeLine(lines[timingLineIndex]) else { continue }

            let textLines = lines[(timingLineIndex + 1)...]
            let text = textLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                // Strip VTT formatting tags like <b>, <i>, <c.classname>
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

            guard !text.isEmpty else { continue }

            cues.append(Cue(index: cueIndex, startTime: start, endTime: end, text: text))
            cueIndex += 1
        }

        return cues.sorted { $0.startTime < $1.startTime }
    }

    private static func parseTimeLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: " --> ")
        guard parts.count == 2 else { return nil }

        // VTT can have positioning after the end timestamp, separated by space
        let endPart = parts[1].components(separatedBy: " ").first ?? parts[1]

        guard let start = parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces)),
              let end = parseTimestamp(endPart.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        return (start, end)
    }

    // Parses "HH:MM:SS.mmm" or "MM:SS.mmm"
    static func parseTimestamp(_ str: String) -> TimeInterval? {
        let components = str.components(separatedBy: ":")

        switch components.count {
        case 3:
            guard let hours = Double(components[0]),
                  let minutes = Double(components[1]),
                  let seconds = Double(components[2]) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        case 2:
            guard let minutes = Double(components[0]),
                  let seconds = Double(components[1]) else { return nil }
            return minutes * 60 + seconds
        default:
            return nil
        }
    }
}
