import SwiftUI

// MARK: - DetailNavigationPayload

/// Encapsulates the descriptive metadata and dynamic scroll state for an active detail surface.
@MainActor
struct DetailNavigationPayload: Equatable {
    var title: String
    var icon: String
    var scrolledTitle: String?
    var thumbnailURL: URL?
    var isScrolledPastHeader: Bool

    init(
        title: String,
        icon: String,
        scrolledTitle: String? = nil,
        thumbnailURL: URL? = nil,
        isScrolledPastHeader: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self.scrolledTitle = scrolledTitle
        self.thumbnailURL = thumbnailURL
        self.isScrolledPastHeader = isScrolledPastHeader
    }
}

// MARK: - DetailNavigationEntry

/// An entry in the detail navigation stack describing the active detail surface.
@MainActor
struct DetailNavigationEntry: Identifiable {
    let id: UUID
    var payload: DetailNavigationPayload
    let dismiss: @MainActor @Sendable () -> Void

    var title: String {
        get { self.payload.title }
        set { self.payload.title = newValue }
    }

    var icon: String {
        get { self.payload.icon }
        set { self.payload.icon = newValue }
    }

    var scrolledTitle: String? {
        get { self.payload.scrolledTitle }
        set { self.payload.scrolledTitle = newValue }
    }

    var thumbnailURL: URL? {
        get { self.payload.thumbnailURL }
        set { self.payload.thumbnailURL = newValue }
    }

    var isScrolledPastHeader: Bool {
        get { self.payload.isScrolledPastHeader }
        set { self.payload.isScrolledPastHeader = newValue }
    }
}

// MARK: - DetailNavigationManager

/// Observable manager tracking pushed detail views to coordinate back navigation and contextual topbar title pills.
@Observable
@MainActor
final class DetailNavigationManager {
    /// Stack of currently active detail entries.
    private(set) var stack: [DetailNavigationEntry] = []

    /// The topmost detail entry, if any.
    var current: DetailNavigationEntry? {
        self.stack.last
    }

    /// Whether there is an active detail view that can be dismissed.
    var canGoBack: Bool {
        !self.stack.isEmpty
    }

    /// Registers a new detail view entry when it appears.
    /// - Parameters:
    ///   - title: The localized title of the detail view (e.g. "Playlist", "Album", "Artist").
    ///   - icon: The SF Symbol name for the detail view.
    ///   - scrolledTitle: The specific item title to show when scrolled past the header (e.g., playlist name).
    ///   - thumbnailURL: The cover art or avatar URL to show when scrolled past the header.
    ///   - isScrolledPastHeader: Whether the view's hero header is currently scrolled out of view.
    ///   - dismiss: The action to dismiss/pop the detail view.
    /// - Returns: A unique identifier for unregistering when the view disappears.
    func push(
        title: String,
        icon: String,
        scrolledTitle: String? = nil,
        thumbnailURL: URL? = nil,
        isScrolledPastHeader: Bool = false,
        dismiss: @escaping @MainActor @Sendable () -> Void
    ) -> UUID {
        let payload = DetailNavigationPayload(
            title: title,
            icon: icon,
            scrolledTitle: scrolledTitle,
            thumbnailURL: thumbnailURL,
            isScrolledPastHeader: isScrolledPastHeader
        )
        let entry = DetailNavigationEntry(
            id: UUID(),
            payload: payload,
            dismiss: dismiss
        )
        self.stack.append(entry)
        return entry.id
    }

    /// Updates dynamic metadata and scroll state for an active detail entry.
    func update(id: UUID, payload: DetailNavigationPayload) {
        guard let index = self.stack.firstIndex(where: { $0.id == id }) else { return }
        self.stack[index].payload = payload
    }

    /// Unregisters a detail view entry when it disappears.
    /// - Parameter id: The identifier returned by `push`.
    func pop(id: UUID) {
        self.stack.removeAll(where: { $0.id == id })
    }

    /// Invokes the dismiss action of the topmost detail entry to pop back.
    func goBack() {
        if let last = self.stack.last {
            last.dismiss()
        }
    }

    /// Resets the navigation stack.
    func clear() {
        self.stack.removeAll()
    }
}

// MARK: - DetailNavigationItemModifier

/// View modifier that registers a view as an active detail item with the `DetailNavigationManager`.
private struct DetailNavigationItemModifier: ViewModifier {
    let payload: DetailNavigationPayload

    @Environment(DetailNavigationManager.self) private var navigationManager: DetailNavigationManager?
    @Environment(\.dismiss) private var dismiss
    @State private var entryId: UUID?

    init(
        title: String,
        icon: String,
        scrolledTitle: String?,
        thumbnailURL: URL?,
        isScrolledPastHeader: Bool
    ) {
        self.payload = DetailNavigationPayload(
            title: title,
            icon: icon,
            scrolledTitle: scrolledTitle,
            thumbnailURL: thumbnailURL,
            isScrolledPastHeader: isScrolledPastHeader
        )
    }

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
            .onAppear {
                if let navigationManager {
                    self.entryId = navigationManager.push(
                        title: self.payload.title,
                        icon: self.payload.icon,
                        scrolledTitle: self.payload.scrolledTitle,
                        thumbnailURL: self.payload.thumbnailURL,
                        isScrolledPastHeader: self.payload.isScrolledPastHeader,
                        dismiss: {
                            self.dismiss()
                        }
                    )
                }
            }
            .onChange(of: self.payload) { _, newPayload in
                guard let entryId, let navigationManager else { return }
                navigationManager.update(id: entryId, payload: newPayload)
            }
            .onDisappear {
                if let entryId, let navigationManager {
                    navigationManager.pop(id: entryId)
                    self.entryId = nil
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Registers this view as a detail navigation item for the topbar back button and contextual pill.
    /// - Parameters:
    ///   - title: The category/type title (e.g., "Playlist", "Album", "Artist").
    ///   - icon: The SF Symbol name representing the item.
    ///   - scrolledTitle: The specific title to display when scrolled past the header (e.g., playlist name).
    ///   - thumbnailURL: The cover art or avatar URL to display when scrolled past the header.
    ///   - isScrolledPastHeader: Whether the hero header is scrolled out of view.
    func detailNavigationItem(
        title: String,
        icon: String,
        scrolledTitle: String? = nil,
        thumbnailURL: URL? = nil,
        isScrolledPastHeader: Bool = false
    ) -> some View {
        modifier(
            DetailNavigationItemModifier(
                title: title,
                icon: icon,
                scrolledTitle: scrolledTitle,
                thumbnailURL: thumbnailURL,
                isScrolledPastHeader: isScrolledPastHeader
            )
        )
    }
}
