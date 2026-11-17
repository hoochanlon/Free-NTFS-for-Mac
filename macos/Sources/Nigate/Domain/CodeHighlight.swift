import Foundation

enum CodeSpanKind: Equatable, Sendable {
    case plain
    case comment
    case string
    case variable
    case number
    case keyword
    case builtin
    case title
    case attr
}

struct CodeSpan: Equatable, Sendable {
    let kind: CodeSpanKind
    let text: String
}

/// 源码 → 连续着色片段。拼回去必须等于原文。
enum CodeHighlight {
    private static let shellLanguages: Set<String> = ["", "sh", "bash", "shell", "zsh", "console", "fish"]
    private static let textLanguages: Set<String> = ["text", "plaintext", "txt"]
    private static let keywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "while", "until",
        "do", "done", "case", "esac", "in", "function", "select"
    ]
    /// 这些词后面跟的是命令，不是普通参数。
    private static let commandHeads: Set<String> = [
        "if", "then", "else", "elif", "do", "while", "until"
    ]
    private static let builtins: Set<String> = [
        "cd", "echo", "export", "test", "exec", "eval", "set", "unset",
        "source", "exit", "pwd", "printf", "read", "trap", "wait", "alias",
        "true", "false", "shift", "continue", "break", "return", "local",
        "declare", "let", "command", "type", "hash", "jobs", "fg", "bg",
        "kill", "time", "umask"
    ]

    static func spans(in source: String, language: String = "") -> [CodeSpan] {
        let lang = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if shellLanguages.contains(lang) { return merge(highlightShell(source)) }
        if textLanguages.contains(lang) { return merge(highlightTree(source)) }
        return source.isEmpty ? [] : [CodeSpan(kind: .plain, text: source)]
    }

    private static func highlightShell(_ source: String) -> [CodeSpan] {
        mapLines(source, highlightShellLine)
    }

    private static func highlightTree(_ source: String) -> [CodeSpan] {
        mapLines(source, highlightTreeLine)
    }

    private static func mapLines(_ source: String, _ highlight: (String) -> [CodeSpan]) -> [CodeSpan] {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.enumerated().flatMap { offset, line in
            let spans = highlight(String(line))
            return offset + 1 < lines.count ? spans + [CodeSpan(kind: .plain, text: "\n")] : spans
        }
    }

    private static func highlightShellLine(_ line: String) -> [CodeSpan] {
        var spans: [CodeSpan] = []
        var index = line.startIndex
        var firstWord = true

        while index < line.endIndex {
            let rest = String(line[index...])
            let character = rest[rest.startIndex]

            if character == " " || character == "\t", let match = prefix(#"^[ \t]+"#, in: rest) {
                append(&spans, .plain, match)
                line.formIndex(&index, offsetBy: match.count)
                continue
            }
            if character == "#" {
                append(&spans, .comment, rest)
                break
            }
            if character == "'" || character == "\"" {
                let pattern = character == "'" ? #"^'[^']*'"# : #"^"(?:\\.|[^"\\])*""#
                if let match = prefix(pattern, in: rest) {
                    append(&spans, .string, match)
                    line.formIndex(&index, offsetBy: match.count)
                    firstWord = false
                    continue
                }
            }
            if character == "\\" {
                let taken = rest.count > 1 ? String(rest.prefix(2)) : rest
                append(&spans, .plain, taken)
                line.formIndex(&index, offsetBy: taken.count)
                continue
            }
            if let match = prefix(#"^[A-Za-z_][A-Za-z0-9_]*="#, in: rest) {
                append(&spans, .variable, String(match.dropLast()))
                append(&spans, .plain, "=")
                line.formIndex(&index, offsetBy: match.count)
                firstWord = false
                continue
            }
            if let match = prefix(#"^\$\{[^}]*\}|^\$[A-Za-z_][A-Za-z0-9_]*"#, in: rest) {
                append(&spans, .variable, match)
                line.formIndex(&index, offsetBy: match.count)
                firstWord = false
                continue
            }
            if let match = prefix(#"^https?://[^\s"'\\]+"#, in: rest) {
                append(&spans, .string, match)
                line.formIndex(&index, offsetBy: match.count)
                firstWord = false
                continue
            }
            if let match = prefix(#"^--?[A-Za-z][A-Za-z0-9_-]*"#, in: rest) {
                append(&spans, .attr, match)
                line.formIndex(&index, offsetBy: match.count)
                firstWord = false
                continue
            }
            if let match = prefix(#"^\d+\b"#, in: rest) {
                append(&spans, .number, match)
                line.formIndex(&index, offsetBy: match.count)
                firstWord = false
                continue
            }
            if let word = prefix(#"^[A-Za-z_./~][A-Za-z0-9_./+-]*"#, in: rest) {
                let kind: CodeSpanKind
                if keywords.contains(word) {
                    kind = .keyword
                } else if firstWord, builtins.contains(word) {
                    kind = .builtin
                } else if firstWord {
                    kind = .title
                } else {
                    kind = .plain
                }
                append(&spans, kind, word)
                line.formIndex(&index, offsetBy: word.count)
                firstWord = commandHeads.contains(word)
                continue
            }

            append(&spans, .plain, String(character))
            line.formIndex(&index, offsetBy: 1)
            if character == ";" || character == "&" || character == "|" {
                firstWord = true
            }
        }

        return spans
    }

    private static func highlightTreeLine(_ line: String) -> [CodeSpan] {
        if let groups = capture(#"^([ \t]*)(\S.*?)( {2,})(\S.*)$"#, in: line), groups.count == 4 {
            return [
                CodeSpan(kind: .plain, text: groups[0]),
                CodeSpan(kind: .attr, text: groups[1]),
                CodeSpan(kind: .plain, text: groups[2]),
                CodeSpan(kind: .comment, text: groups[3])
            ].filter { !$0.text.isEmpty }
        }
        if let groups = capture(#"^([ \t]*)(\S.*)$"#, in: line), groups.count == 2 {
            return [
                CodeSpan(kind: .plain, text: groups[0]),
                CodeSpan(kind: .attr, text: groups[1])
            ].filter { !$0.text.isEmpty }
        }
        return line.isEmpty ? [] : [CodeSpan(kind: .plain, text: line)]
    }

    private static func prefix(_ pattern: String, in text: String) -> String? {
        guard let range = text.range(of: pattern, options: .regularExpression),
              range.lowerBound == text.startIndex else { return nil }
        return String(text[range])
    }

    private static func capture(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let full = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: full) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let slice = Range(range, in: text) else { return nil }
            return String(text[slice])
        }
    }

    private static func append(_ spans: inout [CodeSpan], _ kind: CodeSpanKind, _ text: String) {
        guard !text.isEmpty else { return }
        if let last = spans.last, last.kind == kind {
            spans[spans.count - 1] = CodeSpan(kind: kind, text: last.text + text)
        } else {
            spans.append(CodeSpan(kind: kind, text: text))
        }
    }

    private static func merge(_ spans: [CodeSpan]) -> [CodeSpan] {
        spans.reduce(into: []) { result, span in
            append(&result, span.kind, span.text)
        }
    }
}
