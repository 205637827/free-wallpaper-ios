import SwiftUI
import Photos

/// 首页 —— 模仿原「壁纸」App 界面，兼容 iOS 17.0+
/// 结构：浅色导航栏 + 顶部分类 Tab + 沉浸式双列瀑布流 + 底部 TabBar
/// iOS 26/27 使用液态玻璃，iOS 17~25 自动回退传统材质。
struct HomeView: View {
    @StateObject private var vm = WallpaperViewModel()
    @State private var searchText = ""
    @State private var selected: WallpaperItem?
    @State private var previewIndex = 0
    @State private var currentTab: Int = 0
    @Namespace private var glassNamespace

    // 顶部分类 Tab（对应原 App：专辑/热门/Live/免费/SVIP/年度）
    private let tabs: [(title: String, keyword: String)] = [
        ("推荐", "nature"),
        ("专辑", "album"),
        ("热门", "hot"),
        ("Live", "live photo"),
        ("免费", "free"),
        ("SVIP", "4k"),
        ("年度", "2024"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        TabView(selection: $currentTab) {
            // 首页
            NavigationStack {
                homeContent
            }
            .tabItem { Label("首页", systemImage: "house.fill") }
            .tag(0)

            // 发现
            NavigationStack {
                discoverContent
            }
            .tabItem { Label("发现", systemImage: "compass.fill") }
            .tag(1)

            // 视频（Live 壁纸）
            NavigationStack {
                videoContent
            }
            .tabItem { Label("视频", systemImage: "play.rectangle.fill") }
            .tag(2)

            // 相册（收藏/本地，用搜索占位）
            NavigationStack {
                albumContent
            }
            .tabItem { Label("相册", systemImage: "photo.stack.fill") }
            .tag(3)

            // 我的
            NavigationStack {
                mineContent
            }
            .tabItem { Label("我的", systemImage: "person.fill") }
            .tag(4)
        }
        .tint(.purple)
    }

    // MARK: - 首页内容
    private var homeContent: some View {
        ScrollView {
            // 顶部分类 Tab 栏
            categoryTabs

            if vm.items.isEmpty && !vm.isLoading {
                stateView
            } else {
                // 沉浸式双列瀑布流
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(vm.items) { item in
                        CardView(item: item)
                            .onTapGesture {
                                previewIndex = vm.items.firstIndex(of: item) ?? 0
                                selected = item
                            }
                            .task {
                                if item == vm.items.last { await vm.loadMore() }
                            }
                    }
                }
                .padding(.horizontal, 4)

                if vm.isLoading {
                    ProgressView().padding()
                }
                if !vm.hasMore && !vm.items.isEmpty {
                    Text("— 没有更多了 —")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("壁纸")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // 触发搜索焦点由 .searchable 处理
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索你喜欢的壁纸")
        .onSubmit(of: .search) {
            Task { await vm.search(searchText) }
        }
        .refreshable { await vm.search() }
        .fullScreenCover(item: $selected) { _ in previewLayer }
        .task {
            if vm.items.isEmpty { await vm.search("nature") }
        }
    }

    // MARK: - 分类 Tab 栏（浅色，选中下划线）
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { idx, tab in
                    Button {
                        searchText = tab.keyword
                        Task { await vm.search(tab.keyword) }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.title)
                                .font(.system(size: 15, weight: vm.keyword == tab.keyword ? .semibold : .regular))
                                .foregroundStyle(vm.keyword == tab.keyword ? .primary : .secondary)
                            if vm.keyword == tab.keyword {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: 20, height: 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - 发现页
    private var discoverContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(vm.items.prefix(60)) { item in
                    CardView(item: item)
                        .onTapGesture {
                            previewIndex = vm.items.firstIndex(of: item) ?? 0
                            selected = item
                        }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("发现")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.items.isEmpty { await vm.search("abstract") } }
    }

    // MARK: - 视频页（Live 壁纸）
    private var videoContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(vm.items.prefix(60)) { item in
                    CardView(item: item)
                        .onTapGesture {
                            previewIndex = vm.items.firstIndex(of: item) ?? 0
                            selected = item
                        }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("视频壁纸")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.items.isEmpty { await vm.search("live photo") } }
    }

    // MARK: - 相册页
    private var albumContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("收藏的壁纸")
                .font(.headline)
            Text("在壁纸预览中点击「保存壁纸」即可存入系统相册")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .navigationTitle("相册")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 我的页
    private var mineContent: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("清爽壁纸").font(.headline)
                        Text("免费 · 无广告 · 无内购").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section {
                Label("搜索壁纸", systemImage: "magnifyingglass")
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

    // MARK: - 空态 / 错误态
    @ViewBuilder
    private var stateView: some View {
        if let err = vm.errorMessage {
            ContentUnavailableView {
                Label("加载失败", systemImage: "wifi.exclamationmark")
            } description: {
                Text(err)
            } actions: {
                Button("重试") { Task { await vm.search() } }
                    .modifier(ProminentButtonCompat())
            }
        } else {
            ContentUnavailableView {
                Label("搜索壁纸", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text("选择上方分类或搜索关键词")
            }
        }
    }

    // MARK: - 全屏预览（左右滑动）
    private var previewLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $previewIndex) {
                ForEach(Array(vm.items.enumerated()), id: \.element.id) { idx, item in
                    AsyncImage(url: item.fullURL) { (phase: AsyncImagePhase) in
                        if let img = phase.image {
                            img.resizable().scaledToFit()
                        } else if phase.error != nil {
                            self.thumbFallback(url: item.thumbURL)
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
                    Button {
                        selected = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                    }
                    .modifier(GlassButtonCompat())
                    .accessibilityLabel("关闭")
                    .padding()
                }
                Spacer()
                if let item = safeItem {
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
                    .padding(14)
                    .modifier(ToolbarGlassCompat())
                    .padding()
                }
            }
        }
    }

    private var safeItem: WallpaperItem? {
        vm.items.indices.contains(previewIndex) ? vm.items[previewIndex] : vm.items.first
    }

    /// 缩略图回退：placeholder 重载的闭包参数是 Image，直接用
    private func thumbFallback(url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            ProgressView().tint(.white)
        }
    }
}

// MARK: - 瀑布流卡片（模仿原 App：沉浸式、底部渐变标题）
private struct CardView: View {
    let item: WallpaperItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.thumbURL) { (phase: AsyncImagePhase) in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else if phase.error != nil {
                    Color.gray.opacity(0.25)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                } else {
                    Color.gray.opacity(0.2)
                        .overlay(ProgressView())
                }
            }
            if item.animationUrl != nil {
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(5)
                    .modifier(CircleGlassCompat())
                    .padding(6)
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - 兼容层：分类玻璃（保留备用）
private struct ChipGlass: ViewModifier {
    let active: Bool
    let key: String
    let namespace: Namespace.ID
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffectID(key, in: namespace)
                .glassEffect(active ? Glass.regular.tint(Color.accentColor).interactive() : Glass.regular.interactive(), in: .capsule)
        } else {
            legacy(content, active: active)
        }
        #else
        legacy(content, active: active)
        #endif
    }
    @ViewBuilder
    private func legacy(_ content: Content, active: Bool) -> some View {
        content.background(active ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial), in: .capsule)
    }
}

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
            if saving {
                ProgressView().tint(.primary)
            } else {
                Label("保存壁纸", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .modifier(ProminentButtonCompat())
        .disabled(saving)
        .alert("提示", isPresented: Binding(get: { result != nil }, set: { _ in result = nil })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(result ?? "")
        }
    }

    private func save() async {
        guard let url = item.fullURL ?? item.thumbURL else { return }
        saving = true
        defer { saving = false }
        do {
            let data = try await WallpaperAPI.shared.imageData(from: url)
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            var granted = status == .authorized || status == .limited
            if status == .notDetermined {
                granted = await withCheckedContinuation { cont in
                    PHPhotoLibrary.requestAuthorization(for: .addOnly) {
                        cont.resume(returning: $0 == .authorized || $0 == .limited)
                    }
                }
            }
            guard granted else { result = "请在设置中允许访问照片"; return }
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: data, options: nil)
            }
            result = "已保存到相册"
        } catch {
            result = "保存失败：\(error.localizedDescription)"
        }
    }
}
