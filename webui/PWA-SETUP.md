# OpenDeepSeek PWA 安装指南

让 OpenDeepSeek 像真 App 一样使用 —— 全屏、无浏览器 UI、桌面/主屏幕图标。

---

## 目录

1. [iOS Safari — 添加到主屏幕](#ios-safari)
2. [Android Chrome — 安装为 App](#android-chrome)
3. [桌面 PWA — Chrome / Edge](#desktop-pwa)
4. [启用安装引导脚本](#启用安装引导脚本)
5. [自定义 App 图标](#自定义图标)

---

## iOS Safari

> 适用：iPhone / iPad，Safari 浏览器

**步骤：**

1. 用 Safari 打开 `http://<你的服务器IP>:3000`
2. 点底部工具栏中间的 **分享** 按钮（方框+向上箭头 ↑）
3. 向下滑动列表，找到 **添加到主屏幕**，点击
4. 在弹出的界面中确认名称（默认"OpenDeepSeek"），点右上角 **添加**
5. 回到主屏幕，找到 OpenDeepSeek 图标，点击即可全屏启动

**注意事项：**
- 必须使用 Safari，Chrome/Firefox for iOS 不支持"添加到主屏幕"PWA
- iPad 的分享按钮在顶部地址栏旁边
- 添加后图标默认显示为机器人 emoji；如需真正的图标，见[自定义图标](#自定义图标)

---

## Android Chrome

> 适用：Android 手机/平板，Chrome 浏览器

**方式 A：使用自动弹出的安装提示（推荐）**

1. 用 Chrome 打开 `http://<你的服务器IP>:3000`
2. 等待 2-3 秒，页面底部会出现 OpenDeepSeek 引导横幅
3. 点击横幅中的 **安装** 按钮
4. Chrome 弹出原生安装对话框，点 **安装**
5. 安装完成，主屏幕出现图标

**方式 B：通过浏览器菜单手动安装**

1. 打开页面后，点右上角三个点菜单（⋮）
2. 找到 **添加到主屏幕** 或 **安装应用**
3. 确认并安装

---

## Desktop PWA

> 适用：Windows / macOS / Linux，Chrome 或 Edge 浏览器

**Chrome：**

1. 打开 `http://localhost:3000`
2. 地址栏最右侧会出现一个 **⊕ 安装** 图标（电脑+向下箭头）
3. 点击该图标，在弹出框中点 **安装**
4. OpenDeepSeek 会作为独立窗口打开，并在任务栏/Dock 中固定

**Edge：**

1. 打开 `http://localhost:3000`
2. 地址栏右侧点 **应用** 图标（或菜单 → 应用 → 将此站点安装为应用）
3. 确认安装

**macOS Dock 快捷方式（Chrome）：**
- 安装 PWA 后，在 Finder → 应用程序 → Chrome Apps 文件夹中可找到
- 将其拖到 Dock 即可

---

## 启用安装引导脚本

`loader.js` 会自动加载 `pwa-prompt.js`，无需再进入 Open WebUI 后台粘贴 Custom JS。

### docker compose 挂载（已配置）

`docker-compose.yml` 已将以下文件挂载到容器：

```
./webui/loader.js       → /app/build/static/loader.js
./webui/pwa-prompt.js   → /app/build/static/pwa-prompt.js
./webui/pwa-prompt.css  → /app/build/static/pwa-prompt.css
```

刷新 `http://localhost:3000` 后，Open WebUI 会执行 `loader.js`，再自动载入 PWA 引导脚本。

### 验证引导效果

| 操作 | 预期结果 |
|------|---------|
| 用手机 Safari 打开（首次） | 2.5 秒后出现底部横幅，显示三步引导 |
| 用 Android Chrome 打开（首次） | 出现横幅，点"安装"触发原生 install prompt |
| 点横幅 ✕ 关闭 | 7 天内不再显示 |
| 成功添加到主屏幕后再打开 | 永久不再显示横幅 |
| 以 standalone 模式打开（已安装） | 不显示横幅 |

### localStorage 调试

在浏览器控制台运行以下命令可重置提示状态：

```javascript
// 重置：让横幅下次访问时重新显示
localStorage.removeItem('ods_pwa_dismissed_until');
localStorage.removeItem('ods_pwa_installed');
location.reload();
```

---

## 自定义图标

`webui/manifest-override.json` 中的图标目前使用 SVG Base64 emoji 占位。
生产环境建议替换为真实 PNG 图标：

1. 准备 192×192 和 512×512 的 PNG 图标（OpenDeepSeek logo）
2. 将图标放入 `webui/icons/` 目录
3. 在 `docker-compose.yml` 中添加 volume mount：
   ```yaml
   - ./webui/icons:/app/build/static/icons:ro
   ```
4. 修改 `webui/manifest-override.json` 中的 `icons` 字段：
   ```json
   "icons": [
     { "src": "/static/icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
     { "src": "/static/icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
   ]
   ```
5. 重启容器：`docker compose restart open-webui`

### manifest-override.json 的使用说明

Open WebUI v0.9.2 已内置 `manifest.json`，通常无需替换。
如果需要自定义 App 名称、主题色等，可将 `manifest-override.json` 内容提交给 Open WebUI 的
manifest 端点覆盖（需要修改 Open WebUI 源码或使用 Nginx 代理拦截）。

对于大多数用户，直接使用 Open WebUI 内置的 manifest.json 即可，
PWA 引导脚本 (`pwa-prompt.js`) 不依赖 manifest 内容即可工作。

---

## 常见问题

**Q：iOS 添加到主屏幕后，打开时显示的不是全屏？**
A：确认添加时使用的是 Safari，而非 Chrome/Edge。Chrome for iOS 添加的快捷方式不是真正的 PWA。

**Q：Android 没有出现安装横幅？**
A：需要满足 Chrome 的 PWA 可安装条件：HTTPS 或 localhost、存在 manifest.json、有 Service Worker。
在局域网 IP（如 192.168.x.x）访问时可能因非 HTTPS 而不触发。建议配置 Nginx + 自签名证书，
或通过 Tailscale 访问（Tailscale 域名被 Chrome 视为安全来源）。

**Q：桌面 Chrome 地址栏没有安装图标？**
A：PWA 可安装条件未满足，或者已经安装过（不会重复显示）。可通过菜单 → 更多工具 → 创建快捷方式勾选"在窗口中打开"作为替代。

**Q：Custom JS 字段在哪里找不到？**
A：该字段位于 Admin Panel（管理员面板）→ Settings → Interface 标签页，在页面底部，需要有管理员权限才能看到。
如果是 `WEBUI_AUTH=false`（无登录模式），可以直接访问 `/admin/settings`。
