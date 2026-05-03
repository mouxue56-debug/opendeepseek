# WebUI 主题定制

OpenDeepSeek 自定义主题文件，风格：**DeepSeek 科技蓝 × 深空暗色**。

## 文件说明

| 文件 | 作用 |
|------|------|
| `custom.css` | 主题 CSS，覆盖 Open WebUI 默认样式 |

## 挂载方式（已配置）

`docker-compose.yml` 已通过 bind mount 将本文件注入容器：

```yaml
volumes:
  - open-webui-data:/app/backend/data
  - ./webui/custom.css:/app/build/static/custom.css:ro
```

Open WebUI 的 `app.html` 中固定加载 `/static/custom.css`，覆盖此文件即可生效，**无需修改镜像**。

## 生效方式

```bash
# 重启 WebUI 服务即可热加载
docker compose restart open-webui
```

或在修改 CSS 后直接刷新浏览器（浏览器可能需要强制刷新 Ctrl+Shift+R / Cmd+Shift+R）。

## 主题设计规范

| 色彩角色 | 值 | 用途 |
|----------|-----|------|
| 主色 Primary | `#1565C0` | 按钮、激活态、边框强调 |
| 深主色 Deep | `#0D47A1` | 按钮 hover、重要 UI |
| 强调青 Accent | `#00BCD4` | 链接、代码标签、设置标题 |
| 背景底层 | `#0A0F1E` | 主背景 |
| 背景面板 | `#0F172A` | 侧栏、卡片 |
| 背景浮层 | `#1E293B` | 输入框、模态框 |
| 文字主色 | `#E2E8F0` | 正文 |
| 文字次色 | `#94A3B8` | placeholder、辅助 |

## 自定义修改

直接编辑 `custom.css` 顶部的 CSS 变量（`:root` 块）：

```css
:root {
  --owds-blue-800: #1565C0;   /* 修改主色 */
  --owds-cyan-500: #00BCD4;   /* 修改强调色 */
  --owds-bg-base:  #0A0F1E;   /* 修改主背景 */
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
