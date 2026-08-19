import SwiftUI

/// A YouTube playlist page: header plus its video rows.
struct YouTubePlaylistDetailView: View {
    @State private var viewModel: YouTubePlaylistViewModel
    @State private var isScrolledPastHeader = false

    private static let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 320), spacing: 16),
    ]

    init(playlistId: String, client: any YouTubeClientProtocol) {
        self._viewModel = State(
            initialValue: YouTubePlaylistViewModel(playlistId: playlistId, client: client)
        )
    }

    var body: some View {
        Group {
            switch self.viewModel.loadingState {
            case .idle, .loading:
                LoadingView()
            case let .error(error):
                ErrorView(
                    title: error.title,
                    message: error.message,
                    isRetryable: error.isRetryable
                ) {
                    Task {
                        await self.viewModel.load()
                    }
                }
            case .loaded, .loadingMore:
                if let detail = self.viewModel.detail {
                    self.content(for: detail)
                }
            }
        }
        .detailNavigationItem(
            title: String(localized: "Playlist"),
            icon: "play.rectangle.on.rectangle.fill",
            scrolledTitle: self.viewModel.detail?.playlist.title,
            thumbnailURL: self.viewModel.detail?.playlist.thumbnailURL,
            isScrolledPastHeader: self.isScrolledPastHeader
        )
        .toolbarBackgroundVisibility(.hidden, for: .automatic)
        .liquidGlassFade(edge: .top, height: 64)
        .task {
            await self.viewModel.load()
        }
    }

    private func content(for detail: YouTubePlaylistDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.playlist.title)
                        .font(.title.bold())
                        .lineLimit(2)

                    let meta = [detail.playlist.channelName, detail.playlist.videoCountText]
                        .compactMap(\.self)
                    if !meta.isEmpty {
                        Text(meta.joined(separator: " · "))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if detail.videos.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "No videos"), systemImage: "list.and.film")
                    }
                } else {
                    LazyVGrid(columns: Self.columns, spacing: 20) {
                        ForEach(detail.videos) { video in
                            NavigationLink(value: YouTubeRoute.watch(video)) {
                                VideoCard(video: video)
                            }
                            .buttonStyle(.interactiveCard)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 50
        } action: { _, isScrolled in
            if self.isScrolledPastHeader != isScrolled {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.isScrolledPastHeader = isScrolled
                }
            }
        }
        // Edge-to-edge with a resting inset so content extends under the
        // floating glass sidebar.
        .contentMargins(.horizontal, DetailContentLayout.horizontalInset, for: .scrollContent)
    }
}
