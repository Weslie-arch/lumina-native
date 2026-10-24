# Lumina · 原生版

这是**真正的 iOS App**，不是网页套壳。SwiftUI 写的，直连云服务的 REST 接口。

和套壳版的区别：

| | 套壳版 | 原生版（这个） |
|---|---|---|
| 登录状态 | 存在网页 localStorage，容易被系统清掉 | 存在**系统钥匙串 Keychain**，杀进程也丢不了 |
| 底栏 | 网页画的 | iOS 26 官方**液态玻璃 Tab** |
| 锁屏状态 | 没有 | **实时活动**（锁屏 + 灵动岛） |
| 联网 | 网页 SDK | 直连 REST（`/auth/v1/*` + PostgREST） |

---

## 一、装到手机

产物：`Lumina-Native.ipa`（约 490 KB，已含实时活动扩展）

1. iPhone 开**开发者模式**：设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启
2. 电脑装 [Sideloadly](https://sideloadly.io)（Windows 版）
3. USB 连手机，手机上点「信任此电脑」
4. Sideloadly 里拖入 `Lumina-Native.ipa`，填你的 Apple ID，点 **Start**
5. 装完后：手机 设置 → 通用 → VPN与设备管理 → 信任你的证书

> **重要**：IPA 里有两个 target（主 App + 实时活动扩展）。Sideloadly 会一起签，不用手动处理。
> 如果你的 Sideloadly 报扩展签名错误，换 [AltStore](https://altstore.io) 或 SideStore 装，它们对多 target 支持更好。

**7 天限制**：免费 Apple ID 签的 App 7 天过期（到期闪退）。Sideloadly 里勾上「Wi-Fi 自动刷新」，手机电脑连同一个 WiFi 就会自动续签。一年 688 的付费账号才能彻底免掉。

---

## 二、登录

第一次打开是注册流程（用的是你自己的邮箱）：

1. 填邮箱 + 邀请码 `LUMINA2026` → 点发送验证码
2. 收邮件里的 6 位码 → 填进去 → 自动进入
3. 也可以顺手设个密码，下次用密码直接登

**登录之后就一直在里面了。** 凭据写在系统钥匙串里，App 被杀掉、手机重启都不会掉。要掉只有两种情况：主动点「退出登录」，或者令牌彻底失效（那时会让你重新收一次验证码）。

---

## 三、实时活动（锁屏 + 灵动岛）

打开 App 后自动启动。锁屏和灵动岛上会显示：

- 安卓中转机**在线 / 同步中 / 离线**
- 未读会话数、待发指令数
- 最近更新时间

在「主页」或「我」里可以关掉这个开关。

**已知限制（免费 Apple ID）**：
- 一次实时活动最长 **8 小时**，到点自动消失；下次打开 App 会重新起一个
- 不支持推送更新（我们的场景不需要，都是 App 本地推）
- 需要 iOS 17 以上；灵动岛要 iPhone 14 Pro 及以上机型，普通机型只在锁屏显示

---

## 四、界面

底部是 iOS 26 的液态玻璃 Tab（主页 / 聊天 / 我）。iOS 26 以下自动降级成毛玻璃，布局不变。

- **主页**：安卓机在线状态、绑定码、三格统计、立即同步、实时活动开关、指令日志
- **聊天**：会话列表 → 点进去发消息（消息会写一条「代发」指令，安卓脚本接上后自动发出去）
- **我**：点头像那块编辑昵称和头像（上传图片 / 8 种渐变色 / 16 个表情）、绑定码、退出登录

---

## 五、接安卓中转机

1. 安卓旧手机装 **AutoJs6**（v6.7.0，安卓 7.0+）
2. 导入 `lumina-android/lumina.js`，开无障碍服务 + 电池优化设为不优化
3. 首次运行填：Lumina 邮箱、密码、这里的 6 位绑定码
4. 回 iPhone 点「立即同步」

---

## 六、工程结构

```
lumina-native/
├── project.yml                 xcodegen 工程描述（两个 target）
├── Lumina/
│   ├── Core/Cloud.swift        直连云 REST（auth + PostgREST）
│   ├── Core/Keychain.swift     登录凭据存钥匙串
│   ├── Core/Models.swift       会话/消息/设备/指令/资料
│   ├── App/AppState.swift      状态 + 轮询 + 实时活动
│   ├── Views/                  登录 / 主页 / 聊天 / 我
│   └── LiveActivity/           两个 target 共享的属性定义
└── LuminaActivityWidget/       实时活动的锁屏 + 灵动岛 UI
```

编译：推到 GitHub 就自动跑 Actions（`macos-26`，Xcode 26.5 + iOS 26 SDK），几分钟出 IPA。
仓库：<https://github.com/Weslie-arch/lumina-native>
