import Foundation

/// 直接对接壁纸 App 逆向出的 claritywallpaper 搜索 API
enum WallpaperAPI {
    static let shared = WallpaperAPI()

    private let endpoint = URL(string: "https://claritywallpaper.com/clarity/api/picture/annotateSearchPlus")!
    private let token = "ZmY4MDgwODE3OWE0MjRjZDAxNzliOTFiNzM0OTJlZjg="
    private let ua = "Clarity/7.1.2 (iPhone; iOS 14.2; Scale/3.00)"

    // 简易内存缓存
    private var cache: [String: (date: Date, items: [WallpaperItem])] = [:]
    private let ttl: TimeInterval = 300

    func search(keyword: String, page: Int, size: Int = 24) async throws -> [WallpaperItem] {
        let ck = "\(keyword)|\(page)|\(size)"
        if let hit = cache[ck], Date().timeIntervalSince(hit.date) < ttl {
            return hit.items
        }

        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size)),
        ]
        guard let url = comps.url else { throw APIError.badURL }

        var req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue(token, forHTTPHeaderField: "authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
                }
                let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                guard decoded.code == 200, let items = decoded.data else {
                    throw APIError.server(decoded.message ?? "未知错误")
                }
                cache[ck] = (Date(), items)
                return items
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 300_000_000 * UInt64(attempt + 1))
                }
            }
        }
        throw lastError ?? APIError.unknown
    }

    /// 下载原图数据（用于保存到相册）
    func imageData(from url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue("https://wallpapers.claritywallpaper.com/", forHTTPHeaderField: "Referer")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    enum APIError: LocalizedError {
        case badURL
        case http(Int)
        case server(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .badURL: return "地址构造失败"
            case .http(let c): return "网络错误 (\(c))"
            case .server(let m): return "服务返回：\(m)"
            case .unknown: return "未知错误"
            }
        }
    }
}
