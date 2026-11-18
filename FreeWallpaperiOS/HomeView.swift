import SwiftUI
import Photos

/// 首页 —— 兼容 iOS 17.0+
/// iOS 26/27 使用液态玻璃（Liquid Glass）；iOS 17~25 自动回退到传统材质。
struct HomeView: View {
    @StateObject private var vm = WallpaperViewModel()
    @State private var searchText = ""
    @State private var selected: WallpaperItem?
    @State private var previewIndex = 0
    @Namespace private var glassNamespace

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if vm.items.isEmpty && !vm.isLoading {
                    stateView
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
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
                    .padding(10)

                    if vm.isLoading {
                        ProgressView("加载中…").padding()
                    }
                    if !vm.hasMore && !vm.items.isEmpty {
                        Text("没有更多了")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
            }
            .navigationTitle("清爽壁纸")
            .searchable(text: $searchText, prompt: "搜索：风景 / 星空 / nature…")
            .onSubmit(of: .search) {
                Task { await vm.search(searchText) }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                hotChips
            }
            .refreshable {
                await vm.search()
            }
            .fullScreenCover(item: $selected) { _ in
                previewLayer
            }
            .task {
                if vm.items.isEmpty { await vm.search("nature") }
            }
        }
    }

    // MARK: - 热门分类横条
    private var hotChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            chipsContainer
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var chipsContainer: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(vm.hotKeywords, id: \.self) { k in chip(k) }
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(vm.hotKeywords, id: \.self) { k in chip(k) }
            }
        }
        #else
        HStack(spacing: 8) {
            ForEach(vm.hotKeywords, id: \.self) { k in chip(k) }
        }
        #endif
    }

    @ViewBuilder
    private func chip(_ k: String) -> some View {
        let active = k == vm.keyword
        Button {
            searchText = k
            Task { await vm.search(k) }
        } label: {
            Text(k)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(active ? .white : .primary)
        }
        .buttonStyle(.plain)
        .modifier(ChipGlass(active: active, key: k, namespace: glassNamespace))
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
                Text("输入关键词或点上方分类开始")
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
                            Text(item.displayTitle)
                                .font(.headline)
                            if !item.author.isEmpty {
                                Text("by \(item.author)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

// MARK: - 兼容层：分类胶囊玻璃 / 传统材质
private struct ChipGlass: ViewModifier {
    let active: Bool
    let key: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffectID(key, in: namespace)
                .glassEffect(
                    active
                        ? Glass.regular.tint(Color.accentColor).interactive()
                        : Glass.regular.interactive(),
                    in: .capsule
                )
        } else {
            legacy(content, active: active)
        }
        #else
        legacy(content, active: active)
        #endif
    }

    @ViewBuilder
    private func legacy(_ content: Content, active: Bool) -> some View {
        content
            .background(
                active ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial),
                in: .capsule
            )
    }
}

// MARK: - 兼容层：普通玻璃按钮 / 传统描边按钮
private struct GlassButtonCompat: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered).tint(.white)
        }
        #else
        content.buttonStyle(.bordered).tint(.white)
        #endif
    }
}

// MARK: - 兼容层：强调玻璃按钮 / 传统强调按钮
private struct ProminentButtonCompat: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
        #else
        content.buttonStyle(.borderedProminent)
        #endif
    }
}

// MARK: - 兼容层：预览底部工具栏玻璃 / 传统材质
private struct ToolbarGlassCompat: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .background(shape.fill(.regularMaterial))
                .glassEffect(.regular, in: shape)
        } else {
            content.background(shape.fill(.regularMaterial))
        }
        #else
        content.background(shape.fill(.regularMaterial))
        #endif
    }
}

// MARK: - 兼容层：圆形角标玻璃 / 传统材质
private struct CircleGlassCompat: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content.background(.regularMaterial, in: .circle)
        }
        #else
        content.background(.regularMaterial, in: .circle)
        #endif
    }
}

// MARK: - 瀑布流卡片
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
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center, endPoint: .bottom
            )
            Text(item.displayTitle)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(8)

            if item.animationUrl != nil {
                Image(systemName: "motion")
                    .font(.caption)
                    .padding(6)
                    .modifier(CircleGlassCompat())
                    .padding(6)
            }
        }
        .aspectRatio(0.6, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            guard granted else {
                result = "请在设置中允许访问照片"
                return
            }
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
