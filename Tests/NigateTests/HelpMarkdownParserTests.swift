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

    func testNestsOutlineFromHeadingLevels() {
        let markdown = """
        # Guide
        ## Parent
        ### Child A
        #### Grandchild
        ### Child B
        ## Sibling
        """

        let outline = HelpMarkdownIndex.outline(in: HelpMarkdownParser.parse(markdown))

        XCTAssertEqual(outline.map(\.heading.title), ["Parent", "Sibling"])
        XCTAssertEqual(outline[0].children.map(\.heading.title), ["Child A", "Child B"])
        XCTAssertEqual(outline[0].children[0].children.map(\.heading.title), ["Grandchild"])
        XCTAssertTrue(outline[1].children.isEmpty)
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

            let outline = HelpMarkdownIndex.outline(in: blocks)
            XCTAssertFalse(outline.isEmpty, language.rawValue)
            XCTAssertNotNil(
                outline.first { node in
                    node.children.count >= 3 && node.children.contains { !$0.children.isEmpty }
                },
                language.rawValue
            )
        }
    }

    func testSearchReturnsNoResultsForEmptyOrUnmatchedQueries() {
        let blocks = HelpMarkdownParser.parse("## Setup\n\nPrepare the device.")

        XCTAssertTrue(HelpMarkdownIndex.matchingBlockIDs(query: "   ", in: blocks).isEmpty)
        XCTAssertTrue(HelpMarkdownIndex.matchingBlockIDs(query: "missing", in: blocks).isEmpty)
    }

    func testParsesStandaloneMarkdownImagesAndIndexesAltText() {
        let markdown = """
        # Guide

        ![Damaged app](images/1.png)

        Continue with text.
        """

        let blocks = HelpMarkdownParser.parse(markdown)

        XCTAssertEqual(blocks.count, 3)
        guard case let .image(name, alt) = blocks[1].content else {
            return XCTFail("Expected an image block")
        }
        XCTAssertEqual(name, "images/1.png")
        XCTAssertEqual(alt, "Damaged app")
        XCTAssertEqual(HelpMarkdownIndex.matchingBlockIDs(query: "damaged", in: blocks), [1])
    }

    func testParsesHTMLImagesAndLowercaseCallouts() {
        let markdown = """
        # Guide

        <img width="auto" height="350" alt="Image" src="./7.gif" />

        > [!important]
        > Source notes
        """

        let blocks = HelpMarkdownParser.parse(markdown)

        XCTAssertEqual(blocks.count, 3)
        guard case let .image(name, alt) = blocks[1].content else {
            return XCTFail("Expected an HTML image block")
        }
        XCTAssertEqual(name, "7.gif")
        XCTAssertEqual(alt, "Image")

        guard case let .callout(kind, text) = blocks[2].content else {
            return XCTFail("Expected a lowercase important callout")
        }
        XCTAssertEqual(kind, .important)
        XCTAssertEqual(text, "Source notes")
    }

    func testLocalizedGuidesShareTheSameHelpImages() {
        let previousLanguage = L10n.language
        defer { L10n.apply(previousLanguage) }

        let expected = Set([
            "1.png", "2.png", "3.png", "4.png", "5.png",
            "6.png", "7.gif", "8.png", "9.png", "10.png",
            "11.png", "12.png", "13.png", "14.png", "15.png",
            "bc-1.png", "bc-2.png", "bc-3.png"
        ])

        for language in [AppLanguage.zhCN, .zhTW, .en, .ja, .de] {
            L10n.apply(language)
            let names = Set(HelpMarkdownParser.parse(L10n.helpMarkdown()).compactMap { block -> String? in
                if case let .image(name, _) = block.content {
                    return URL(fileURLWithPath: name).lastPathComponent
                }
                return nil
            })
            XCTAssertEqual(names, expected, language.rawValue)
        }

        for name in expected {
            let file = URL(fileURLWithPath: name).lastPathComponent
            XCTAssertNotNil(L10n.resource("Help/images/\(file)"), file)
        }
    }
}
