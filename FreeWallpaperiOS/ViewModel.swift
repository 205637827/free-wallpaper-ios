import Foundation
import SwiftUI

/// 单个壁纸流的状态：一个关键词对应一个可无限分页的流
@MainActor
final class WallpaperFeed: ObservableObject {
    @Published var items: [WallpaperItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = true

    var keyword: String
    private var page = 1
    private let api = WallpaperAPI.shared
    private let pageSize: Int

    init(keyword: String, pageSize: Int = 30) {
        self.keyword = keyword
        self.pageSize = pageSize
    }

    /// 换关键词（发现页搜索用）
    func reset(keyword: String) {
        self.keyword = keyword
    }

    /// 首次加载 / 重置
    func load() async {
        page = 1
        hasMore = true
        items = []
        errorMessage = nil
        await loadMore()
    }

    /// 加载下一页（通用词深翻零重复）
    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let new = try await api.search(keyword: keyword, page: page, size: pageSize)
            if new.isEmpty {
                hasMore = false
                if items.isEmpty { errorMessage = "暂时没有内容，换个分类试试" }
            } else {
                var seen = Set(items.map(\.id))
                let unique = new.filter { seen.insert($0.id).inserted }
                items.append(contentsOf: unique)
                page += 1
                // 返回数不足一页说明到底了
                if new.count < pageSize { hasMore = false }
            }
            if !items.isEmpty { errorMessage = nil }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}

/// 分类元数据（全部来自实测有数据的关键词）
struct WallpaperCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String       // 中文显示名
    let keyword: String     // API 搜索词
    let icon: String        // SF Symbol
}

/// 全局分类目录（20 个稳定词）
enum Categories {
    static let all: [WallpaperCategory] = [
        WallpaperCategory(title: "推荐", keyword: "wallpaper", icon: "star.fill"),
        WallpaperCategory(title: "风景", keyword: "nature", icon: "leaf.fill"),
        WallpaperCategory(title: "抽象", keyword: "abstract", icon: "scribble.variable"),
        WallpaperCategory(title: "唯美", keyword: "beautiful", icon: "sparkles"),
        WallpaperCategory(title: "爱情", keyword: "love", icon: "heart.fill"),
        WallpaperCategory(title: "城市", keyword: "city", icon: "building.2.fill"),
        WallpaperCategory(title: "汽车", keyword: "car", icon: "car.fill"),
        WallpaperCategory(title: "动漫", keyword: "anime", icon: "animoji"),
        WallpaperCategory(title: "游戏", keyword: "game", icon: "gamecontroller.fill"),
        WallpaperCategory(title: "花朵", keyword: "flower", icon: "flower.fill"),
        WallpaperCategory(title: "天空", keyword: "sky", icon: "cloud.sun.fill"),
        WallpaperCategory(title: "动物", keyword: "animal", icon: "pawprint.fill"),
        WallpaperCategory(title: "星空", keyword: "space", icon: "moon.stars.fill"),
        WallpaperCategory(title: "夜景", keyword: "night", icon: "moon.fill"),
        WallpaperCategory(title: "海洋", keyword: "ocean", icon: "water.waves"),
        WallpaperCategory(title: "山川", keyword: "mountain", icon: "mountain.2.fill"),
        WallpaperCategory(title: "人物", keyword: "girl", icon: "person.fill"),
        WallpaperCategory(title: "艺术", keyword: "art", icon: "paintbrush.fill"),
        WallpaperCategory(title: "简约", keyword: "minimal", icon: "square"),
        WallpaperCategory(title: "多彩", keyword: "colorful", icon: "circle.grid.3x3.fill"),
    ]
}
