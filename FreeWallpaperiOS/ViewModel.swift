import Foundation
import SwiftUI

@MainActor
final class WallpaperViewModel: ObservableObject {
    @Published var items: [WallpaperItem] = []
    @Published var keyword: String = "nature"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = true

    private var page = 1
    private let api = WallpaperAPI.shared

    let hotKeywords = ["nature", "abstract", "星空", "风景", "汽车", "美女", "动物", "建筑", "4k", "city", "flower", "sky"]

    func search(_ text: String? = nil) async {
        let kw = (text ?? keyword).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return }
        keyword = kw
        page = 1
        hasMore = true
        items = []
        errorMessage = nil
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let new = try await api.search(keyword: keyword, page: page, size: 24)
            if new.isEmpty {
                hasMore = false
                if items.isEmpty { errorMessage = "没有找到相关壁纸，换个关键词试试" }
            } else {
                // 去重（API 分页偶尔重复）
                var seen = Set(items.map(\.id))
                let unique = new.filter { seen.insert($0.id).inserted }
                items.append(contentsOf: unique)
                page += 1
                if new.count < 12 { hasMore = false }
            }
            errorMessage = items.isEmpty ? errorMessage : nil
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}
