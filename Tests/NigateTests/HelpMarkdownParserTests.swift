import XCTest
@testable import Nigate

final class HelpMarkdownParserTests: XCTestCase {
    func testPreservesHeadingParagraphAndListStructure() {
        let markdown = """
        # Getting started

        Use **bold text** when it matters
        and wrap lines naturally.

        1. First step
        3. Third step
          - Nested step
        """

        let blocks = HelpMarkdownParser.parse(markdown)

        XCTAssertEqual(blocks.count, 3)
        guard case let .heading(level, title) = blocks[0].content else {
            return XCTFail("Expected a heading block")
        }
        XCTAssertEqual(level, 1)
        XCTAssertEqual(title, "Getting started")

        guard case let .paragraph(paragraph) = blocks[1].content else {
            return XCTFail("Expected a paragraph block")
        }
        XCTAssertEqual(paragraph, "Use **bold text** when it matters and wrap lines naturally.")

        guard case let .list(items) = blocks[2].content else {
            return XCTFail("Expected a list block")
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].text, "First step")
        XCTAssertEqual(items[1].text, "Third step")
        XCTAssertEqual(items[2].text, "Nested step")
        XCTAssertEqual(items[2].depth, 1)
        guard case let .numbered(number) = items[1].marker else {
            return XCTFail("Expected a numbered list marker")
        }
        XCTAssertEqual(number, 3)
    }

    func testParsesCalloutAndTableBlocks() {
        let markdown = """
        > [!WARNING]
        > Keep data backed up.

        | Name | Value |
        | --- | --- |
        | `disk4` | **external** |
        """

        let blocks = HelpMarkdownParser.parse(markdown)

        XCTAssertEqual(blocks.count, 2)
        guard case let .callout(kind, text) = blocks[0].content else {
            return XCTFail("Expected a callout block")
        }
        XCTAssertEqual(kind, .warning)
        XCTAssertEqual(text, "Keep data backed up.")

        guard case let .table(rows) = blocks[1].content else {
            return XCTFail("Expected a table block")
        }
        XCTAssertEqual(rows, [["Name", "Value"], ["`disk4`", "**external**"]])
    }

    func testBuildsContentsFromSectionHeadingsUsingBlockIDs() {
        let markdown = """
        # Guide title
        ## Setup
        ### Details
        ## Details
        # Another title
        #### Advanced
        """

        let headings = HelpMarkdownIndex.headings(in: HelpMarkdownParser.parse(markdown))

        XCTAssertEqual(headings.map(\.title), ["Setup", "Details", "Details", "Advanced"])
        XCTAssertEqual(headings.map(\.blockID), [1, 2, 3, 5])
    }

    func testSearchesAcrossParagraphsListsCalloutsTablesAndCode() {
        let markdown = """
        # Guide

        This paragraph spans
        multiple lines with Needle inside.

        - List needle

        > [!NOTE]
        > Needle in a callout

        | Label | Value |
        | --- | --- |
        | Needle | Found |

        ```text
        Needle in code
        ```
        """

        let blocks = HelpMarkdownParser.parse(markdown)

        XCTAssertEqual(
            HelpMarkdownIndex.matchingBlockIDs(query: "needle", in: blocks),
            [1, 2, 3, 4, 5]
        )
        XCTAssertEqual(
            HelpMarkdownIndex.matchingBlockIDs(query: "multiple lines with needle", in: blocks),
            [1]
        )
    }

    func testLocalizedGuidesExposeSearchableContentsHeadings() {
        let previousLanguage = L10n.language
        defer { L10n.apply(previousLanguage) }

        for language in [AppLanguage.zhCN, .zhTW, .en, .ja, .de] {
            L10n.apply(language)
            let blocks = HelpMarkdownParser.parse(L10n.helpMarkdown())
            let headings = HelpMarkdownIndex.headings(in: blocks)

            XCTAssertFalse(headings.isEmpty, language.rawValue)
            guard let firstHeading = headings.first else { continue }
            XCTAssertTrue(
                HelpMarkdownIndex.matchingBlockIDs(query: firstHeading.title, in: blocks)
                    .contains(firstHeading.blockID),
                language.rawValue
            )
        }
    }

    func testSearchReturnsNoResultsForEmptyOrUnmatchedQueries() {
        let blocks = HelpMarkdownParser.parse("## Setup\n\nPrepare the device.")

        XCTAssertTrue(HelpMarkdownIndex.matchingBlockIDs(query: "   ", in: blocks).isEmpty)
        XCTAssertTrue(HelpMarkdownIndex.matchingBlockIDs(query: "missing", in: blocks).isEmpty)
    }
}
