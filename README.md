# 清爽壁纸 iOS（FreeWallpaperiOS）

原生 **SwiftUI** 壁纸 App，部署目标 **iOS 17.0+**（兼容 iOS 17 / 18 / 19 / 26 / 27），直接对接从「壁纸 6.0.1」逆向出的壁纸 API。完全免费、无广告、无内购。已适配 **iOS 26/27 液态玻璃（Liquid Glass）**，低版本自动回退到传统材质。

## 系统兼容

- **iOS 26 / 27**：完整液态玻璃（`GlassEffectContainer`、`glassEffect`、`.glass` 按钮）
- **iOS 17 ~ 25**：所有玻璃 API 由 `#available(iOS 26.0, *)` 保护，自动回退到 `.regularMaterial` / `.bordered` 等传统样式，不会崩溃
- 部署目标：`IPHONEOS_DEPLOYMENT_TARGET = 17.0`

## 液态玻璃适配

`HomeView.swift` 使用 iOS 26+ 原生 Glass API（Apple 官方文档），并全部包在版本保护内：
- `GlassEffectContainer` + `glassEffectID`：热门分类胶囊彼此融合、随滚动变形
- `.glassEffect(.regular.interactive(), in: .capsule)`：可交互玻璃分类按钮
- `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`：关闭、保存等玻璃按钮
- 预览底部工具栏、圆形角标：`.glassEffect(...)`
- 低版本统一走兼容层 ViewModifier（`ChipGlass`/`GlassButtonCompat`/`ProminentButtonCompat`/`ToolbarGlassCompat`/`CircleGlassCompat`），回退到传统材质

## 打包 IPA

IPA 是 Mach-O 编译 + 签名产物，只能在 **macOS + Xcode** 上生成。提供两种方式：

**方式 A — 本地 Mac 一键打包**
```bash
cd FreeWallpaperiOS
bash build_ipa.sh
# 产物: build/FreeWallpaperiOS.ipa
```
需要 Mac + Xcode（编液态玻璃需 Xcode 26+；只编兼容版 iOS 17 SDK 用 Xcode 15+ 即可）。脚本 archive 后打包为未签名结构 IPA；要装真机可设置 `DEVELOPMENT_TEAM=你的TeamID` 走自动签名，或按脚本末尾提示用 `codesign` 重签。

**方式 B — GitHub Actions（推荐，无需本地 Mac）**
把本目录推到 GitHub 仓库，触发 `.github/workflows/build-ipa.yml`（`workflow_dispatch` 或 push）：
macOS runner 自动编译，在 Actions 的 Artifacts 下载 **FreeWallpaperiOS-IPA**。若 runner 的 Xcode 版本不匹配，把 workflow 里 `macos-15` 改成 `macos-latest`。

> 当前工作区为 Windows，无 Xcode 工具链，无法在此直接产出 IPA；上面两条是在 Mac 侧出真 IPA 的可执行路径。

## 打开与运行

1. 用 **Xcode 26+**（要液态玻璃；仅兼容模式可用 Xcode 15+）打开 `FreeWallpaperiOS.xcodeproj`
2. 选一个 iOS 17+ 模拟器或真机
3. 在 `Signing & Capabilities` 里选自己的 Team（Bundle ID：`com.freewallpaper.app`，可改）
4. `⌘R` 运行

> 最低系统 iOS 17.0。使用 `ContentUnavailableView`、`.searchable`、`.refreshable`、`LazyVGrid` 等 iOS 17 原生 API；液态玻璃部分通过 `#available(iOS 26.0, *)` 保护并向后回退。

## 功能

- 关键词搜索（中英文） + 12 个热门分类横条
- 双列瀑布流，滚动到底自动加载更多
- 下拉刷新 + 去重
- 全屏预览，左右滑动切换，显示标题/作者
- 一键保存原图到系统相册（带权限申请与结果提示）
- 动图角标识别

## API（逆向所得，内置于 Network.swift）

| 项 | 值 |
|---|---|
| 搜索 | `https://claritywallpaper.com/clarity/api/picture/annotateSearchPlus?keyword=&page=&size=` |
| 鉴权 | Header `authorization: ZmY4MDgwODE3OWE0MjRjZDAxNzliOTFiNzM0OTJlZjg=` |
| UA | `Clarity/7.1.2 (iPhone; iOS 14.2; Scale/3.00)` |
| 图片 | `https://wallpapers.claritywallpaper.com/{url}?key={key}` |

## 文件结构

```
FreeWallpaperiOS.xcodeproj/project.pbxproj   Xcode 项目（iOS 17+ target）
FreeWallpaperiOS/
  FreeWallpaperApp.swift    App 入口
  HomeView.swift            界面：搜索/瀑布流/预览/保存
  ViewModel.swift           状态与分页逻辑
  Network.swift             API 请求 + 图片下载（含重试/缓存）
  Models.swift              数据模型 + CDN URL 拼接
  Assets.xcassets/          图标与主题色
```

## 所需权限

- `NSPhotoLibraryAddUsageDescription`：保存壁纸到相册（已在项目配置中声明）

壁纸内容版权归原作者所有，本项目仅提供检索与展示。
