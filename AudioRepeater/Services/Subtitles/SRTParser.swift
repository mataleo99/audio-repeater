import Foundation

struct SRTParser {
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
        let blocks = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")

            guard lines.count >= 3,
                  let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else {
                continue
            }

            let timeLine = lines[1]
            guard let (start, end) = parseTimeLine(timeLine) else { continue }

            let text = lines[2...].joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            cues.append(Cue(index: index, startTime: start, endTime: end, text: text))
        }

        return cues.sorted { $0.startTime < $1.startTime }
    }

    private static func parseTimeLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: " --> ")
        guard parts.count == 2 else { return nil }

        guard let start = parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces)),
              let end = parseTimestamp(parts[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        return (start, end)
    }

    // Parses "HH:MM:SS,mmm" or "HH:MM:SS.mmm"
    static func parseTimestamp(_ str: String) -> TimeInterval? {
        let cleaned = str.replacingOccurrences(of: ",", with: ".")
        let components = cleaned.components(separatedBy: ":")
        guard components.count == 3 else { return nil }

        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }

        return hours * 3600 + minutes * 60 + seconds
    }
}
