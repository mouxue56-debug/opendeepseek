# WebUI 主题定制

OpenDeepSeek 自定义主题文件，风格：**Open WebUI / ChatGPT 中性色**。发布版避免纯色色块、糖果色和装饰渐变，尽量贴近原生对话产品。

## 文件说明

| 文件 | 作用 |
|------|------|
| `custom.css` | 主题 CSS，覆盖 Open WebUI 默认样式 |
| `loader.js` | 首屏轻量汉化，并自动加载 PWA 安装引导 |
| `pwa-prompt.js` | 手机 / 桌面 PWA 安装提示 |
| `pwa-prompt.css` | PWA 安装提示样式 |

## 挂载方式（已配置）

`docker-compose.yml` 已通过 bind mount 将本文件注入容器：

```yaml
volumes:
  - open-webui-data:/app/backend/data
  - ./webui/custom.css:/app/build/static/custom.css:ro
  - ./webui/loader.js:/app/build/static/loader.js:ro
  - ./webui/pwa-prompt.js:/app/build/static/pwa-prompt.js:ro
  - ./webui/pwa-prompt.css:/app/build/static/pwa-prompt.css:ro
```

Open WebUI 的构建产物会加载 `/static/custom.css` 和 `/static/loader.js`，覆盖这两个文件即可生效，**无需修改镜像**。

## 生效方式

```bash
# 重启 WebUI 服务即可热加载
docker compose restart open-webui
```

或在修改 CSS 后直接刷新浏览器（浏览器可能需要强制刷新 Ctrl+Shift+R / Cmd+Shift+R）。

## 主题设计规范

| 色彩角色 | 值 | 用途 |
|----------|-----|------|
| 主色 Primary | `#10A37F` | 发送按钮、激活态 |
| 背景底层 | `#F7F7F8` | 主背景 |
| 背景面板 | `#FFFFFF` | 对话区、浮层 |
| 边框 | `#E5E7EB` | 卡片、输入框 |
| 文字主色 | `#111827` | 正文 |
| 文字次色 | `#6B7280` | placeholder、辅助 |

## 自定义修改

直接编辑 `custom.css` 顶部的 CSS 变量（`:root` 块）：

```css
:root {
  --ods-accent: #10A37F;
  --ods-bg: #F7F7F8;
  --ods-surface: #FFFFFF;
}
```

修改后执行 `docker compose restart open-webui` 即可。

## 移动端适配

CSS 已内置：
- 触摸目标 ≥ 44px（iOS/Android 规范）
- 输入框 `font-size: 16px`（防止 iOS 自动缩放）
- 侧栏 `position: fixed` + 底部安全区 `env(safe-area-inset-bottom)`
- 代码块 / 表格横向滚动
- iPad 侧栏宽度优化（260px）
