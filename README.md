# 嘉信实时翻译 SchwabTranslate

给嘉信（Charles Schwab）App 用的实时翻译：录屏时识别画面里的英文，翻成中文，半透明盖在原来文字的位置上。

## 两种用法

**实时翻译（录屏）**
1. 打开嘉信 App，到要翻译的页面。
2. 从右上角下拉打开控制中心，长按“屏幕录制”。
3. 选择 SchwabTranslate，点“开始直播”。
4. 切回本 App，最新一帧的译文会盖在原文位置上（扩展每 1.5 秒抓一帧）。
5. 用完在控制中心点红色条停止录屏。

**截图翻译**
截一张嘉信 App 的图，在“截图翻译”里选图，识别完直接看，译文半透明盖在原文位置上。

## 技术

- 录屏：ReplayKit Broadcast Upload Extension（`SchwabTranslateBroadcast`）
- 识别：本机 Vision OCR（英文，accurate 模式）
- 翻译：Google 免费接口（`translate.googleapis.com`，不需要 key，需要联网）
- 扩展和主 App 之间用系统剪贴板传数据（未签名包没有 App Groups 权限）

## 实话实说：做不到的事

- iOS 不允许第三方 App 在别的 App 界面上悬浮显示，所以译文不能直接浮在嘉信 App 上面，只能切回本 App 查看。这是系统限制。
- 翻译要联网；断网时只能识别原文。
- 录屏扩展内存有限，抓帧频率不高，画面切太快会漏帧，等 1–2 秒刷新。
- 未编译验证前都是实验版：以 Codemagic 构建结果为准，装上手机实测才算数。

## 安装

未签名 IPA，用 AltStore / Sideloadly / SideStore 拿自己的 Apple ID 自签安装。免费账号证书 7 天有效，到期重签。

## 构建

Codemagic 手动触发：app `schwab-translate` → workflow `ios-unsigned` → branch `master`。
