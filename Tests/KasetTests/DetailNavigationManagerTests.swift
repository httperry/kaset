import Foundation
import Testing
@testable import Kaset

@Suite("DetailNavigationManager Tests")
@MainActor
struct DetailNavigationManagerTests {
    @Test("Pushing and popping entries updates stack and canGoBack")
    func pushAndPop() {
        let manager = DetailNavigationManager()
        #expect(!manager.canGoBack)
        #expect(manager.current == nil)

        var dismissed = false
        let id1 = manager.push(
            title: "Playlist",
            icon: "music.note.list",
            scrolledTitle: "Vibin'",
            thumbnailURL: URL(string: "https://example.com/cover.jpg"),
            isScrolledPastHeader: false
        ) {
            dismissed = true
        }

        #expect(manager.canGoBack)
        #expect(manager.current?.title == "Playlist")
        #expect(manager.current?.icon == "music.note.list")
        #expect(manager.current?.scrolledTitle == "Vibin'")
        #expect(manager.current?.thumbnailURL == URL(string: "https://example.com/cover.jpg"))
        #expect(manager.current?.isScrolledPastHeader == false)

        manager.pop(id: id1)
        #expect(!manager.canGoBack)
        #expect(manager.current == nil)
        #expect(!dismissed)
    }

    @Test("Updating dynamic scroll metadata and state")
    func updateScrollMetadata() {
        let manager = DetailNavigationManager()
        let id1 = manager.push(
            title: "Playlist",
            icon: "music.note.list",
            scrolledTitle: nil,
            thumbnailURL: nil,
            isScrolledPastHeader: false
        ) {}

        #expect(manager.current?.isScrolledPastHeader == false)

        manager.update(
            id: id1,
            payload: DetailNavigationPayload(
                title: "Playlist",
                icon: "music.note.list",
                scrolledTitle: "Chill Beats",
                thumbnailURL: URL(string: "https://example.com/chill.jpg"),
                isScrolledPastHeader: true
            )
        )

        #expect(manager.current?.isScrolledPastHeader == true)
        #expect(manager.current?.scrolledTitle == "Chill Beats")
        #expect(manager.current?.thumbnailURL == URL(string: "https://example.com/chill.jpg"))
    }

    @Test("goBack triggers the dismiss handler of the topmost entry")
    func goBack() {
        let manager = DetailNavigationManager()
        var firstDismissed = false
        var secondDismissed = false

        _ = manager.push(title: "First", icon: "1.circle") {
            firstDismissed = true
        }

        _ = manager.push(title: "Second", icon: "2.circle") {
            secondDismissed = true
        }

        #expect(manager.current?.title == "Second")
        manager.goBack()

        #expect(secondDismissed)
        #expect(!firstDismissed)
    }

    @Test("Clear removes all navigation entries")
    func clear() {
        let manager = DetailNavigationManager()
        _ = manager.push(title: "A", icon: "a.circle") {}
        _ = manager.push(title: "B", icon: "b.circle") {}

        #expect(manager.stack.count == 2)
        #expect(manager.canGoBack)

        manager.clear()
        #expect(manager.stack.isEmpty)
        #expect(!manager.canGoBack)
        #expect(manager.current == nil)
    }
}
