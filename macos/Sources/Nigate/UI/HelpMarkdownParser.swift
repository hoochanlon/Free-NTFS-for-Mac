import Foundation

struct HelpBlock: Identifiable {
    enum Content {
        case heading(level: Int, text: String)
        case paragraph(String)
        case list([HelpListItem])
        case code(language: String, source: String)
        case callout(kind: HelpCalloutKind, text: String)
        case table([[String]])
    }

    let id: Int
    let content: Content
}

struct HelpListItem: Identifiable {
    enum Marker {
        case bullet
        case numbered(Int)
    }

    let id: Int
    let depth: Int
    let marker: Marker
    var text: String
}

enum HelpCalloutKind: String {
    case note = "NOTE"
    case tip = "TIP"
    case important = "IMPORTANT"
    case warning = "WARNING"
    case caution = "CAUTION"

    init(marker: String) {
        let normalized = marker.uppercased()
        self = normalized == "WARN" ? .warning : (Self(rawValue: normalized) ?? .note)
    }
}

enum HelpMarkdownParser {
    private struct ParsedListItem {
        let indentation: Int
        let marker: HelpListItem.Marker
        let text: String
    }

    static func parse(_ markdown: String) -> [HelpBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [HelpBlock] = []
        var index = 0

        func append(_ content: HelpBlock.Content) {
            blocks.append(HelpBlock(id: blocks.count, content: content))
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
            } else if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var code: [String] = []
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                append(.code(language: language, source: code.joined(separator: "\n")))
            } else if let heading = heading(in: trimmed) {
                append(.heading(level: heading.level, text: heading.text))
                index += 1
            } else if isTableHeader(at: index, lines: lines) {
                let rows = parseTable(at: &index, lines: lines)
                append(.table(rows))
            } else if trimmed.hasPrefix(">") {
                let callout = parseCallout(at: &index, lines: lines)
                append(.callout(kind: callout.kind, text: callout.text))
            } else if parseListItem(line) != nil {
                let items = parseList(at: &index, lines: lines)
                append(.list(items))
            } else {
                let paragraph = parseParagraph(at: &index, lines: lines)
                if !paragraph.isEmpty { append(.paragraph(paragraph)) }
            }
        }

        return blocks
    }

    private static func heading(in line: String) -> (level: Int, text: String)? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else { return nil }
        let remainder = line.dropFirst(level)
        guard remainder.first?.isWhitespace == true else { return nil }
        let text = remainder.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private static func parseParagraph(at index: inout Int, lines: [String]) -> String {
        var parts: [String] = []
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !startsBlock(at: index, lines: lines) else { break }
            parts.append(trimmed)
            index += 1
        }
        if parts.isEmpty {
            index += 1
            return ""
        }
        return parts.joined(separator: " ")
    }

    private static func startsBlock(at index: Int, lines: [String]) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("```")
            || heading(in: trimmed) != nil
            || trimmed.hasPrefix(">")
            || parseListItem(lines[index]) != nil
            || isTableHeader(at: index, lines: lines)
    }

    private static func parseListItem(_ line: String) -> ParsedListItem? {
        let indentation = line.prefix(while: { $0 == " " || $0 == "\t" })
            .reduce(into: 0) { count, character in count += character == "\t" ? 2 : 1 }
        let content = line.dropFirst(line.prefix(while: { $0 == " " || $0 == "\t" }).count)
        guard let first = content.first else { return nil }

        if "-*+".contains(first), content.dropFirst().first?.isWhitespace == true {
            let text = content.dropFirst().drop(while: { $0.isWhitespace })
            return ParsedListItem(indentation: indentation, marker: .bullet, text: String(text))
        }

        let digits = content.prefix(while: \.isNumber)
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        let suffix = content.dropFirst(digits.count)
        guard let punctuation = suffix.first, punctuation == "." || punctuation == ")",
              suffix.dropFirst().first?.isWhitespace == true else { return nil }
        let text = suffix.dropFirst().drop(while: { $0.isWhitespace })
        return ParsedListItem(indentation: indentation, marker: .numbered(number), text: String(text))
    }

    private static func parseList(at index: inout Int, lines: [String]) -> [HelpListItem] {
        var items: [HelpListItem] = []
        var lastIndentation = 0

        while index < lines.count {
            let line = lines[index]
            if let parsed = parseListItem(line) {
                let item = HelpListItem(
                    id: items.count,
                    depth: parsed.indentation / 2,
                    marker: parsed.marker,
                    text: parsed.text
                )
                items.append(item)
                lastIndentation = parsed.indentation
                index += 1
            } else {
                let indentation = line.prefix(while: { $0 == " " || $0 == "\t" })
                    .reduce(into: 0) { count, character in count += character == "\t" ? 2 : 1 }
                let continuation = line.trimmingCharacters(in: .whitespaces)
                guard !continuation.isEmpty, indentation > lastIndentation, !items.isEmpty else { break }
                items[items.count - 1].text += " " + continuation
                index += 1
            }
        }

        return items
    }

    private static func parseCallout(at index: inout Int, lines: [String]) -> (kind: HelpCalloutKind, text: String) {
        var quoteLines: [String] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(">") else { break }
            quoteLines.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
            index += 1
        }

        var kind = HelpCalloutKind.note
        if let marker = quoteLines.first,
           marker.range(of: #"^\[!(NOTE|TIP|IMPORTANT|WARNING|WARN|CAUTION)\]$"#, options: .regularExpression) != nil {
            kind = HelpCalloutKind(marker: String(marker.dropFirst(2).dropLast()))
            quoteLines.removeFirst()
        }
        return (kind, quoteLines.joined(separator: "\n"))
    }

    private static func isTableHeader(at index: Int, lines: [String]) -> Bool {
        guard index + 1 < lines.count,
              lines[index].contains("|"),
              lines[index + 1].contains("|") else { return false }
        let separatorCells = tableCells(in: lines[index + 1])
        return !separatorCells.isEmpty && separatorCells.allSatisfy {
            $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil
        }
    }

    private static func parseTable(at index: inout Int, lines: [String]) -> [[String]] {
        var rows = [tableCells(in: lines[index])]
        index += 2
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, line.contains("|") else { break }
            rows.append(tableCells(in: line))
            index += 1
        }
        return rows
    }

    private static func tableCells(in line: String) -> [String] {
        line.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

struct HelpHeading: Identifiable {
    let blockID: Int
    let level: Int
    let title: String

    var id: Int { blockID }
}

enum HelpMarkdownIndex {
    static func headings(in blocks: [HelpBlock]) -> [HelpHeading] {
        blocks.compactMap { block in
            guard case let .heading(level, title) = block.content, level >= 2 else { return nil }
            return HelpHeading(blockID: block.id, level: level, title: title)
        }
    }

    static func matchingBlockIDs(query: String, in blocks: [HelpBlock]) -> [Int] {
        let needle = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return [] }

        return blocks.compactMap { block in
            normalized(searchableText(in: block.content)).contains(needle) ? block.id : nil
        }
    }

    private static func searchableText(in content: HelpBlock.Content) -> String {
        switch content {
        case let .heading(_, text), let .paragraph(text), let .code(_, text), let .callout(_, text):
            text
        case let .list(items):
            items.map(\.text).joined(separator: "\n")
        case let .table(rows):
            rows.flatMap { $0 }.joined(separator: "\n")
        }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale.current)
    }
}
