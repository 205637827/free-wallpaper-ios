import Foundation

/// 壁纸条目 —— 对应 claritywallpaper API 返回字段
struct WallpaperItem: Identifiable, Hashable, Decodable {
    let id: String
    let url: String?
    let originalUrl: String?
    let animationUrl: String?
    let key: String?
    let title: String?
    let titleEn: String?
    let isFree: Bool?
    let isAi: Bool?
    let userInfo: UserInfo?

    struct UserInfo: Decodable, Hashable {
        let nickName: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, url, originalUrl, animationUrl, key, title, titleEn
        case isFree, isAi, userInfo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        url = try? c.decode(String.self, forKey: .url)
        originalUrl = try? c.decode(String.self, forKey: .originalUrl)
        animationUrl = try? c.decode(String.self, forKey: .animationUrl)
        key = try? c.decode(String.self, forKey: .key)
        title = try? c.decode(String.self, forKey: .title)
        titleEn = try? c.decode(String.self, forKey: .titleEn)
        isFree = try? c.decode(Bool.self, forKey: .isFree)
        isAi = try? c.decode(Bool.self, forKey: .isAi)
        userInfo = try? c.decode(UserInfo.self, forKey: .userInfo)
    }

    var displayTitle: String {
        let t = (title ?? titleEn ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "壁纸" : t
    }

    var author: String {
        userInfo?.nickName ?? ""
    }

    /// 图片 CDN 基址
    private static let cdn = "https://wallpapers.claritywallpaper.com/"

    private func cdnURL(_ path: String?) -> URL? {
        guard var p = path, !p.isEmpty else { return nil }
        var s = p.hasPrefix("http") ? p : Self.cdn + p.drop(while: { $0 == "/" })
        if let k = key, !k.isEmpty, !s.contains("?") {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
            s += "?key=" + (k.addingPercentEncoding(withAllowedCharacters: allowed) ?? k)
        }
        return URL(string: s)
    }

    /// 列表缩略图
    var thumbURL: URL? { cdnURL(url) }

    /// 原图（无 originalUrl 时退回 url）
    var fullURL: URL? { cdnURL(originalUrl ?? url) }

    /// 动图地址（如有）
    var animationURL: URL? { cdnURL(animationUrl) }
}

/// API 顶层响应
struct SearchResponse: Decodable {
    let code: Int?
    let message: String?
    let data: [WallpaperItem]?
}
