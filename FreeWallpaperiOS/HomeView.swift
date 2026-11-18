import SwiftUI
import Photos

/// 主界面 —— 模仿原「壁纸」App，兼容 iOS 17.0+
/// 数据源：claritywallpaper 搜索 API（20 个精选关键词 + 通用词无限深翻）
struct HomeView: View {
    @StateObject private var featuredFeed = WallpaperFeed(keyword: "wallpaper")   // 首页精选无限流
    @StateObject private var searchFeed = WallpaperFeed(keyword: "nature", pageSize: 30)
    @State private var searchText = ""
    @State private var selected: WallpaperItem?
    @State private var previewIndex = 0
    @State private var currentTab = 0

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        TabView(selection: $currentTab) {
            NavigationStack { featuredView }
                .tabItem { Label("首页", systemImage: "house.fill") }.tag(0)
            NavigationStack { categoryView }
                .tabItem { Label("分类", systemImage: "square.grid.2x2.fill") }.tag(1)
            NavigationStack { searchView }
                .tabItem { Label("发现", systemImage: "magnifyingglass") }.tag(2)
            NavigationStack { albumView }
                .tabItem { Label("相册", systemImage: "photo.stack.fill") }.tag(3)
            NavigationStack { mineView }
                .tabItem { Label("我的", systemImage: "person.fill") }.tag(4)
        }
        .tint(.purple)
    }

    // MARK: - 首页：精选无限流
    private var featuredView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(featuredFeed.items) { item in
                    cardView(item)
                        .task { if item == featuredFeed.items.last { await featuredFeed.loadMore() } }
                }
            }
            .padding(.horizontal, 4)
            if featuredFeed.isLoading { ProgressView().padding() }
            if !featuredFeed.hasMore && !featuredFeed.items.isEmpty {
                Text("— 没有更多了 —").font(.footnote).foregroundStyle(.secondary).padding()
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("壁纸")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await featuredFeed.load() }
        .fullScreenCover(item: $selected) { _ in previewLayer(for: featuredFeed) }
        .task { if featuredFeed.items.isEmpty { await featuredFeed.load() } }
    }

    // MARK: - 分类页：20 个精选分类网格，点进去看该分类壁纸
    private var categoryView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Categories.all) { cat in
                    NavigationLink {
                        CategoryFeedView(category: cat, columns: columns) { item, feed in
                            openPreview(item, feed: feed)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 70)
                                .background(
                                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text(cat.title).font(.subheadline).foregroundStyle(.primary)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("分类")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 发现页：搜索
    private var searchView: some View {
        ScrollView {
            if searchFeed.items.isEmpty && !searchFeed.isLoading {
                ContentUnavailableView {
                    Label("发现壁纸", systemImage: "magnifyingglass")
                } description: {
                    Text("在上方搜索你想找的壁纸")
                }
            } else {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(searchFeed.items) { item in
                        cardView(item)
                            .task { if item == searchFeed.items.last { await searchFeed.loadMore() } }
                    }
                }
                .padding(.horizontal, 4)
                if searchFeed.isLoading { ProgressView().padding() }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("发现")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索壁纸（中英文均可）")
        .onSubmit(of: .search) { Task { await runSearch() } }
        .refreshable { await runSearch() }
        .fullScreenCover(item: $selected) { _ in previewLayer(for: searchFeed) }
    }

    private func runSearch() async {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return }
        // 用新关键词重建 feed
        searchFeed.reset(keyword: kw)
        await searchFeed.load()
    }

    // MARK: - 相册页
    private var albumView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack").font(.system(size: 56)).foregroundStyle(.secondary)
            Text("收藏的壁纸").font(.headline)
            Text("在壁纸预览中点击「保存壁纸」，即可存入系统相册")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .navigationTitle("相册")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 我的页
    private var mineView: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.circle.fill").font(.system(size: 54)).foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("清爽壁纸").font(.headline)
                        Text("免费 · 无广告 · 无内购").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
            }
            Section {
                Label("20+ 高清分类", systemImage: "square.grid.2x2")
                Label("无限壁纸流", systemImage: "infinity")
                Label("保存原图到相册", systemImage: "square.and.arrow.down")
                Label("适配 iOS 17 及以上", systemImage: "iphone")
            }
            Section {
                Text("壁纸内容版权归原作者所有").font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 卡片
    private func cardView(_ item: WallpaperItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.thumbURL) { (phase: AsyncImagePhase) in
                if let img = phase.image {
                    img.resizable().scaledToFill().frame(maxWidth: .infinity).clipped()
                } else if phase.error != nil {
                    Color.gray.opacity(0.25).overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                } else {
                    Color.gray.opacity(0.2).overlay(ProgressView())
                }
            }
            if item.animationUrl != nil {
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
                Image(systemName: "play.fill").font(.caption2).foregroundStyle(.white)
                    .padding(5).modifier(CircleGlassCompat()).padding(6)
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { openPreviewFromCurrent(item) }
    }

    // 打开预览：根据当前 Tab 选对应 feed
    private func openPreviewFromCurrent(_ item: WallpaperItem) {
        let feed: WallpaperFeed = (currentTab == 0) ? featuredFeed : searchFeed
        openPreview(item, feed: feed)
    }

    private func openPreview(_ item: WallpaperItem, feed: WallpaperFeed) {
        previewIndex = feed.items.firstIndex(of: item) ?? 0
        selected = item
        activeFeed = feed
    }

    // 当前预览绑定的 feed（用于左右切换）
    @State private var activeFeed: WallpaperFeed?

    private func previewLayer(for feed: WallpaperFeed) -> some View {
        PreviewLayer(items: feed.items, index: $previewIndex, selected: $selected)
    }

    // MARK: - 兼容层
}

// MARK: - 分类详情页（独立 feed）
private struct CategoryFeedView: View {
    let category: WallpaperCategory
    let columns: [GridItem]
    let onOpen: (WallpaperItem, WallpaperFeed) -> Void
    @StateObject private var feed: WallpaperFeed

    init(category: WallpaperCategory, columns: [GridItem], onOpen: @escaping (WallpaperItem, WallpaperFeed) -> Void) {
        self.category = category
        self.columns = columns
        self.onOpen = onOpen
        _feed = StateObject(wrappedValue: WallpaperFeed(keyword: category.keyword))
    }

    var body: some View {
        ScrollView {
            if feed.items.isEmpty && !feed.isLoading {
                if let err = feed.errorMessage {
                    ContentUnavailableView("加载失败", systemImage: "wifi.exclamationmark", description: Text(err))
                } else {
                    ProgressView().padding()
                }
            } else {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(feed.items) { item in
                        CategoryCard(item: item)
                            .onTapGesture { onOpen(item, feed) }
                            .task { if item == feed.items.last { await feed.loadMore() } }
                    }
                }
                .padding(.horizontal, 4)
                if feed.isLoading { ProgressView().padding() }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if feed.items.isEmpty { await feed.load() } }
    }
}

private struct CategoryCard: View {
    let item: WallpaperItem
    var body: some View {
        AsyncImage(url: item.thumbURL) { (phase: AsyncImagePhase) in
            if let img = phase.image {
                img.resizable().scaledToFill().frame(maxWidth: .infinity).clipped()
            } else {
                Color.gray.opacity(0.2).overlay(ProgressView())
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - 全屏预览层
private struct PreviewLayer: View {
    let items: [WallpaperItem]
    @Binding var index: Int
    @Binding var selected: WallpaperItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    AsyncImage(url: item.fullURL) { (phase: AsyncImagePhase) in
                        if let img = phase.image {
                            img.resizable().scaledToFit()
                        } else if phase.error != nil {
                            AsyncImage(url: item.thumbURL) { p in
                                if let t = p.image { t.resizable().scaledToFit() }
                            }
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            VStack {
                HStack {
                    Spacer()
                    Button { selected = nil } label: {
                        Image(systemName: "xmark").font(.title3.weight(.semibold))
                    }
                    .modifier(GlassButtonCompat()).padding()
                }
                Spacer()
                if index >= 0 && index < items.count {
                    let item = items[index]
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayTitle).font(.headline)
                            if !item.author.isEmpty {
                                Text("by \(item.author)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        SaveButton(item: item)
                    }
                    .padding(14).modifier(ToolbarGlassCompat()).padding()
                }
            }
        }
    }
}

// MARK: - 兼容层 modifier
private struct GlassButtonCompat: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { content.buttonStyle(.glass) }
        else { content.buttonStyle(.bordered).tint(.white) }
        #else
        content.buttonStyle(.bordered).tint(.white)
        #endif
    }
}
private struct ProminentButtonCompat: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { content.buttonStyle(.glassProminent) }
        else { content.buttonStyle(.borderedProminent) }
        #else
        content.buttonStyle(.borderedProminent)
        #endif
    }
}
private struct ToolbarGlassCompat: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.background(shape.fill(.regularMaterial)).glassEffect(.regular, in: shape)
        } else {
            content.background(shape.fill(.regularMaterial))
        }
        #else
        content.background(shape.fill(.regularMaterial))
        #endif
    }
}
private struct CircleGlassCompat: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { content.glassEffect(.regular, in: .circle) }
        else { content.background(.regularMaterial, in: .circle) }
        #else
        content.background(.regularMaterial, in: .circle)
        #endif
    }
}

// MARK: - 保存到相册
private struct SaveButton: View {
    let item: WallpaperItem
    @State private var saving = false
    @State private var result: String?
    var body: some View {
        Button {
            Task { await save() }
        } label: {
            if saving { ProgressView().tint(.primary) }
            else { Label("保存壁纸", systemImage: "square.and.arrow.down").font(.subheadline.weight(.semibold)) }
        }
        .modifier(ProminentButtonCompat()).disabled(saving)
        .alert("提示", isPresented: Binding(get: { result != nil }, set: { _ in result = nil })) {
            Button("好", role: .cancel) {}
        } message: { Text(result ?? "") }
    }
    private func save() async {
        guard let url = item.fullURL ?? item.thumbURL else { return }
        saving = true; defer { saving = false }
        do {
            let data = try await WallpaperAPI.shared.imageData(from: url)
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            var granted = status == .authorized || status == .limited
            if status == .notDetermined {
                granted = await withCheckedContinuation { cont in
                    PHPhotoLibrary.requestAuthorization(for: .addOnly) { cont.resume(returning: $0 == .authorized || $0 == .limited) }
                }
            }
            guard granted else { result = "请在设置中允许访问照片"; return }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            result = "已保存到相册"
        } catch { result = "保存失败：\(error.localizedDescription)" }
    }
}
