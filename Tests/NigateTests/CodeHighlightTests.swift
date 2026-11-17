import XCTest
@testable import Nigate

final class CodeHighlightTests: XCTestCase {
    func testJoinsBackToOriginalSource() {
        let samples = [
            "xcode-select --install",
            #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#,
            "if brew list --cask macfuse >/dev/null 2>&1; then brew reinstall --cask macfuse; else brew install --cask macfuse; fi",
            "xattr -cr /Applications/nigate.app",
            #"open "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.fskit.fsmodule""#,
            "PATH=/opt/homebrew/bin:$PATH brew install fswatch",
            "# comment only\ntrue && echo done\n",
            ""
        ]
        for source in samples {
            XCTAssertEqual(
                CodeHighlight.spans(in: source).map(\.text).joined(),
                source,
                source
            )
        }
    }

    func testHighlightsInstallCommandNameAndFlags() {
        XCTAssertEqual(
            CodeHighlight.spans(in: "xcode-select --install"),
            [
                CodeSpan(kind: .title, text: "xcode-select"),
                CodeSpan(kind: .plain, text: " "),
                CodeSpan(kind: .attr, text: "--install")
            ]
        )
    }

    func testQuotedScriptStaysOneString() {
        let source = #"/bin/bash -c "$(curl -fsSL https://example.com/install.sh)""#
        let spans = CodeHighlight.spans(in: source)
        XCTAssertEqual(spans.map(\.text).joined(), source)
        XCTAssertEqual(spans.first?.kind, .title)
        XCTAssertEqual(spans.first?.text, "/bin/bash")
        XCTAssertTrue(spans.contains { $0.kind == .attr && $0.text == "-c" })
        XCTAssertTrue(spans.contains { $0.kind == .string && $0.text.hasPrefix("\"$(") && $0.text.hasSuffix("\"") })
    }

    func testResetsCommandPositionAfterPipeAndKeyword() {
        let spans = CodeHighlight.spans(
            in: "if true; then echo ok; else false; fi"
        )
        XCTAssertEqual(kind(of: "if", in: spans), .keyword)
        XCTAssertEqual(kind(of: "then", in: spans), .keyword)
        XCTAssertEqual(kind(of: "else", in: spans), .keyword)
        XCTAssertEqual(kind(of: "fi", in: spans), .keyword)
        XCTAssertEqual(kind(of: "true", in: spans), .builtin)
        XCTAssertEqual(kind(of: "echo", in: spans), .builtin)
        XCTAssertEqual(kind(of: "false", in: spans), .builtin)
    }

    func testVariablesFlagsNumbersAndComments() {
        let spans = CodeHighlight.spans(in: "FOO=$HOME 2 # wait")
        XCTAssertEqual(kind(of: "FOO", in: spans), .variable)
        XCTAssertEqual(kind(of: "$HOME", in: spans), .variable)
        XCTAssertEqual(kind(of: "2", in: spans), .number)
        XCTAssertEqual(kind(of: "# wait", in: spans), .comment)
    }

    func testEmptyLanguageUsesShellUnknownStaysPlain() {
        XCTAssertEqual(
            CodeHighlight.spans(in: "xattr -cr /Applications/nigate.app", language: ""),
            CodeHighlight.spans(in: "xattr -cr /Applications/nigate.app", language: "bash")
        )
        XCTAssertEqual(
            CodeHighlight.spans(in: "xattr -cr /Applications/nigate.app", language: "swift"),
            [CodeSpan(kind: .plain, text: "xattr -cr /Applications/nigate.app")]
        )
    }

    func testTreeLanguageSplitsPathAndComment() {
        XCTAssertEqual(
            CodeHighlight.spans(in: "src/app  leftover notes", language: "text"),
            [
                CodeSpan(kind: .attr, text: "src/app"),
                CodeSpan(kind: .plain, text: "  "),
                CodeSpan(kind: .comment, text: "leftover notes")
            ]
        )
    }

    private func kind(of text: String, in spans: [CodeSpan]) -> CodeSpanKind? {
        spans.first { $0.text == text }?.kind
    }
}
