import SwiftUI

/// Home view displaying personalized content sections.
struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(PlayerService.self) private var playerService
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(SongLikeStatusManager.self) private var likeStatusManager
    @Environment(AuthService.self) private var authService
    @Environment(AccountService.self) private var accountService
    @State private var navigationPath = NavigationPath()
    @State private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        NavigationStack(path: self.$navigationPath) {
            Group {
                if !self.networkMonitor.isConnected {
                    ErrorView(
                        title: String(localized: "No Connection"),
                        message: String(localized: "Please check your internet connection and try again.")
                    ) {
                        Task { await self.viewModel.refresh() }
                    }
                } else {
                    switch self.viewModel.loadingState {
                    case .idle, .loading:
                        HomeLoadingView()
                    case .loaded, .loadingMore:
                        self.contentView
                    case let .error(error):
                        ErrorView(error: error) {
                            Task { await self.viewModel.refresh() }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("")
            .navigationDestinations(
                client: self.viewModel.client,
                playerBarNavigationAction: self.playerBarNavigationAction
            )
            .playerBarMusicNavigation(path: self.$navigationPath)
        }
        .playerBarMusicNavigation(path: self.$navigationPath)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlayerBar()
                .playerBarMusicNavigation(path: self.$navigationPath)
        }
        .onAppear {
            if self.viewModel.loadingState == .idle {
                Task {
                    await self.viewModel.load()
                }
            }
        }
        .popsNavigationStackOnSidebarReselect(path: self.$navigationPath, for: .home)
    }

    private var playerBarNavigationAction: PlayerBarNavigationAction {
        PlayerBarNavigationAction(
            openArtist: { self.navigationPath.append($0) },
            openAlbum: { self.navigationPath.append($0) }
        )
    }

    // MARK: - Views

    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                // Top Personalized Greeting
                self.homeHeaderView

                // Favorites section (hidden when empty)
                if self.authService.hasPersonalAccount, self.favoritesManager.isVisible {
                    FavoritesSection(
                        onNavigate: { destination in
                            if let playlist = destination as? Playlist {
                                self.navigationPath.append(playlist)
                            } else if let artist = destination as? Artist {
                                self.navigationPath.append(artist)
                            } else if let podcastShow = destination as? PodcastShow {
                                self.navigationPath.append(podcastShow)
                            }
                        },
                        contentInset: DetailContentLayout.horizontalInset
                    )
                    .staggeredAppearance(index: 0)
                }

                if let provisioned = self.viewModel.provisionedContent, !provisioned.isEmpty {
                    // Layer 1: Grand 16:9 Cinematic Hero Spotlight Stage
                    if !provisioned.heroItems.isEmpty {
                        HomeHeroSpotlightView(
                            heroItems: provisioned.heroItems,
                            onPlayTarget: { self.playTarget($0) },
                            onNavigateTarget: { self.navigateTarget($0) },
                            onNavigateArtist: { self.navigationPath.append($0) }
                        )
                        .padding(.horizontal, DetailContentLayout.horizontalInset)
                    }

                    // Layer 2: "Jump Back In" Recent Rotation Shelf (8 Items)
                    if let bento = provisioned.jumpBackIn {
                        HomeActivityBentoView(
                            bentoPayload: bento,
                            onPlaySong: { song in
                                Task { await self.playerService.playWithRadio(song: song) }
                            },
                            onPlayItem: { self.playSectionItem($0) },
                            onNavigateItem: { self.navigateSectionItem($0) },
                            onNavigateArtist: { self.navigationPath.append($0) },
                            onViewMore: {
                                // Navigate to library
                            },
                            contentInset: DetailContentLayout.horizontalInset
                        )
                    }

                    // Layer 3+: Classified Curated Downstream Shelves
                    ForEach(Array(provisioned.curatedShelves.enumerated()), id: \.element.id) { index, shelf in
                        self.curatedShelfView(shelf)
                            .staggeredAppearance(index: index + 3)
                    }
                } else {
                    // Fallback to legacy uniform shelves if provisionedContent is not ready
                    ForEach(self.viewModel.sections) { section in
                        self.sectionView(section)
                            .task {
                                await self.prefetchImagesAsync(for: section)
                            }
                    }
                }

                if self.viewModel.hasMoreSections || self.viewModel.loadingState == .loadingMore {
                    self.loadMoreControl
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier(AccessibilityID.Home.scrollView)
        .pullToRefresh {
            await self.viewModel.refresh()
        }
    }

    // MARK: - Header Greeting

    private var homeHeaderView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(self.greetingTitle)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Here's your personalized mix and listening highlights")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DetailContentLayout.horizontalInset)
        .padding(.top, 4)
    }

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting = if hour >= 5, hour < 12 {
            String(localized: "Good morning")
        } else if hour >= 12, hour < 17 {
            String(localized: "Good afternoon")
        } else {
            String(localized: "Good evening")
        }

        if let firstName = self.accountService.currentAccount?.name.components(separatedBy: " ").first, !firstName.isEmpty {
            return "\(timeGreeting), \(firstName)"
        }
        return timeGreeting
    }

    // MARK: - Curated Shelves

    @ViewBuilder
    private func curatedShelfView(_ shelf: HomeCuratedShelfPayload) -> some View {
        switch shelf.content {
        case let .songTracks(songs):
            HomeTrackColumnsView(
                title: shelf.title,
                songs: songs,
                onPlaySong: { song in
                    Task { await self.playerService.playWithRadio(song: song) }
                },
                onNavigateSong: { song in
                    Task { await self.playerService.playWithRadio(song: song) }
                },
                contentInset: DetailContentLayout.horizontalInset
            )

        case let .albumsAndPlaylists(items):
            HomeMediumCardsView(
                title: shelf.title,
                items: items,
                onPlayItem: { self.playSectionItem($0) },
                onNavigateItem: { self.navigateSectionItem($0) },
                contentInset: DetailContentLayout.horizontalInset
            )

        case let .videoPerformances(videos):
            HomeVideoPerformancesView(
                title: shelf.title,
                videos: videos,
                onPlayVideo: { song in
                    Task { await self.playerService.playWithRadio(song: song) }
                },
                onNavigateVideo: { song in
                    Task { await self.playerService.playWithRadio(song: song) }
                },
                contentInset: DetailContentLayout.horizontalInset
            )

        case let .artistPortraits(artists):
            HomeArtistPortraitsView(
                title: shelf.title,
                artists: artists,
                onNavigateArtist: { artist in
                    self.navigationPath.append(artist)
                },
                contentInset: DetailContentLayout.horizontalInset
            )
        }
    }

    private var loadMoreControl: some View {
        LoadMoreFooter(
            isLoading: self.viewModel.loadingState == .loadingMore,
            title: "Load More",
            loadingTitle: "Loading more...",
            autoLoad: true,
            autoLoadTrigger: self.viewModel.sections.count
        ) {
            await self.viewModel.loadMore()
        }
    }

    private func sectionView(_ section: HomeSection) -> some View {
        CarouselShelfSection(
            accessibilityLabel: section.title,
            items: Array(section.items.enumerated()),
            id: \.element.id,
            itemAlignment: .top,
            contentInset: DetailContentLayout.horizontalInset
        ) {
            Text(section.title)
                .font(.title2)
                .fontWeight(.semibold)
        } itemContent: { index, item in
            HomeSectionItemCard(
                item: item,
                rank: section.isChart ? index + 1 : nil,
                playAction: self.playlistPlayAction(for: item)
            ) {
                self.playSectionItem(item)
            }
            .contextMenu {
                self.contextMenuItems(for: item, in: section, at: index)
            }
        }
    }

    // MARK: - Target Play & Navigation Handlers

    private func playTarget(_ target: HomePlayTarget) {
        switch target {
        case let .song(song):
            Task { await self.playerService.playWithRadio(song: song) }
        case let .album(album):
            SongActionsHelper.playAlbum(
                album,
                client: self.viewModel.client,
                playerService: self.playerService
            )
        case let .playlist(playlist):
            SongActionsHelper.playPlaylist(
                playlist,
                client: self.viewModel.client,
                playerService: self.playerService
            )
        case let .artist(artist):
            self.navigationPath.append(artist)
        }
    }

    private func navigateTarget(_ target: HomePlayTarget) {
        switch target {
        case let .song(song):
            // CLICKING A SONG PLAYS THE SONG!
            Task { await self.playerService.playWithRadio(song: song) }
        case let .album(album):
            let playlist = Playlist(
                id: album.id,
                title: album.title,
                description: nil,
                thumbnailURL: album.thumbnailURL,
                trackCount: album.trackCount,
                author: Artist.inline(name: album.artistsDisplay, namespace: "album-artist")
            )
            self.navigationPath.append(playlist)
        case let .playlist(playlist):
            self.navigationPath.append(playlist)
        case let .artist(artist):
            self.navigationPath.append(artist)
        }
    }

    private func playSectionItem(_ item: HomeSectionItem) {
        switch item {
        case let .song(song):
            Task {
                await self.playerService.playWithRadio(song: song)
            }
        case let .album(album):
            SongActionsHelper.playAlbum(
                album,
                client: self.viewModel.client,
                playerService: self.playerService
            )
        case let .playlist(playlist):
            SongActionsHelper.playPlaylist(
                playlist,
                client: self.viewModel.client,
                playerService: self.playerService
            )
        case let .artist(artist):
            self.navigationPath.append(artist)
        }
    }

    private func navigateSectionItem(_ item: HomeSectionItem) {
        switch item {
        case let .song(song):
            // CLICKING A SONG PLAYS THE SONG!
            Task {
                await self.playerService.playWithRadio(song: song)
            }
        case let .album(album):
            let playlist = Playlist(
                id: album.id,
                title: album.title,
                description: nil,
                thumbnailURL: album.thumbnailURL,
                trackCount: album.trackCount,
                author: Artist.inline(name: album.artistsDisplay, namespace: "album-artist")
            )
            self.navigationPath.append(playlist)
        case let .playlist(playlist):
            self.navigationPath.append(playlist)
        case let .artist(artist):
            self.navigationPath.append(artist)
        }
    }

    // MARK: - Context Menu

    private func playlistPlayAction(for item: HomeSectionItem) -> (() -> Void)? {
        guard case let .playlist(playlist) = item,
              SongActionsHelper.canQuickPlayPlaylist(playlist)
        else {
            return nil
        }

        return {
            SongActionsHelper.playPlaylist(
                playlist,
                client: self.viewModel.client,
                playerService: self.playerService
            )
        }
    }

    @ViewBuilder
    private func contextMenuItems(for item: HomeSectionItem, in _: HomeSection, at _: Int) -> some View {
        switch item {
        case let .song(song):
            Button {
                Task { await self.playerService.play(song: song) }
            } label: {
                Label(String(localized: "Play"), systemImage: "play.fill")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: song, manager: self.favoritesManager)

            Divider()

            LikeDislikeContextMenu(song: song, likeStatusManager: self.likeStatusManager)

            Divider()

            StartRadioContextMenu.menuItem(for: song, playerService: self.playerService)

            Divider()

            ShareContextMenu.menuItem(for: song)

            Divider()

            AddToQueueContextMenu(song: song, playerService: self.playerService)

            Divider()

            AddToPlaylistContextMenu(song: song, client: self.viewModel.client)

            Divider()

            if let artist = song.artists.first(where: { $0.hasNavigableId }) {
                NavigationLink(value: artist) {
                    Label(String(localized: "Go to Artist"), systemImage: "person")
                }
            }

            if let album = song.album, album.hasNavigableId {
                let playlist = Playlist(
                    id: album.id,
                    title: album.title,
                    description: nil,
                    thumbnailURL: album.thumbnailURL ?? song.thumbnailURL,
                    trackCount: album.trackCount,
                    author: Artist.inline(name: album.artistsDisplay, namespace: "album-artist")
                )
                NavigationLink(value: playlist) {
                    Label(String(localized: "Go to Album"), systemImage: "square.stack")
                }
            }

        case let .album(album):
            Button {
                self.playSectionItem(item)
            } label: {
                Label(String(localized: "View Album"), systemImage: "square.stack")
            }

            Divider()

            Button {
                SongActionsHelper.playAlbum(
                    album,
                    client: self.viewModel.client,
                    playerService: self.playerService
                )
            } label: {
                Label(String(localized: "Play"), systemImage: "play.fill")
            }

            Button {
                SongActionsHelper.addAlbumToQueueNext(
                    album,
                    client: self.viewModel.client,
                    playerService: self.playerService
                )
            } label: {
                Label(String(localized: "Play Next"), systemImage: "text.insert")
            }

            Button {
                SongActionsHelper.addAlbumToQueueLast(
                    album,
                    client: self.viewModel.client,
                    playerService: self.playerService
                )
            } label: {
                Label(String(localized: "Add to Queue"), systemImage: "text.append")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: album, manager: self.favoritesManager)

            Divider()

            ShareContextMenu.menuItem(for: album)

        case let .playlist(playlist):
            Button {
                self.navigationPath.append(playlist)
            } label: {
                Label(String(localized: "View Playlist"), systemImage: "music.note.list")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: playlist, manager: self.favoritesManager)

            Divider()

            ShareContextMenu.menuItem(for: playlist)

        case let .artist(artist):
            Button {
                self.navigationPath.append(artist)
            } label: {
                Label(String(localized: "View Artist"), systemImage: "person")
            }

            Divider()

            FavoritesContextMenu.menuItem(for: artist, manager: self.favoritesManager)

            ShareContextMenu.menuItem(for: artist)
        }
    }

    // MARK: - Image Prefetching

    private static let thumbnailDisplaySize = CGSize(width: 160, height: 160)

    private func prefetchImagesAsync(for section: HomeSection) async {
        guard !Task.isCancelled else { return }

        let urls = section.items.prefix(6).compactMap { $0.thumbnailURL?.highQualityThumbnailURL }
        guard !urls.isEmpty else { return }

        await ImageCache.shared.prefetch(
            urls: urls,
            targetSize: Self.thumbnailDisplaySize,
            maxConcurrent: 2
        )
    }
}

#Preview {
    let authService = AuthService()
    let client = YTMusicClient(authService: authService, webKitManager: .shared)
    HomeView(viewModel: HomeViewModel(client: client))
        .environment(PlayerService())
        .environment(authService)
        .environment(AccountService(ytMusicClient: client, authService: authService))
        .environment(FavoritesManager.shared)
}
