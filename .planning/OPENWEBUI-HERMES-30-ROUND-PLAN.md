# OpenWebUI + Hermes 30 轮完善 Debug 清单

> 生成时间：2026-05-04  
> 来源：Codex 本地验证 + OpenClaw sidecar：Qwen3.6 Plus / Kimi K2.6  
> 目标：让 OpenDeepSeek 不退化成普通聊天工具，而是“Open WebUI 的好用界面 + Hermes 的真 Agent 执行 + DeepSeek V4 Flash 的低价推理”。

## 调研依据

- OpenWebUI 适合保留 UI、聊天历史、知识库、上传、PWA、Native tools、Memory/Notes 这些用户界面层能力。
- Hermes 适合保留本机文件/终端、Cron、Skills、Subagent、执行态 Memory、长任务编排。
- DeepSeek 官方模型列表已包含 `deepseek-v4-flash` / `deepseek-v4-pro`；`deepseek-chat` 与 `deepseek-reasoner` 只是兼容别名，未来会废弃。
- DeepSeek 官方 Models & Pricing 页面显示 V4 Flash 支持 1M context、最大 384K output，并支持 JSON Output / Tool Calls。
- 本地日志已确认真实故障：`Response truncated`、`Truncated tool call`、`Unknown tool 'web_search'`、`Iteration budget exhausted (50/50)`、辅助摘要模型缺失。

参考：

- https://api-docs.deepseek.com/api/list-models/
- https://api-docs.deepseek.com/quick_start/pricing
- https://docs.openwebui.com/
- https://docs.opencomputer.dev/agents/cores/hermes

## 本轮已落地

1. Smart Bridge 在 Hermes 任务中注入执行规则：必须实际用工具完成，保存前验证文件存在且大小大于 0。
2. Smart Bridge 自动把 `/host/...` 追加成本机路径和 `file://` 打开地址，解决“小白找不到文件”。
3. Hermes Agent 任务默认 `max_tokens` 从 8192 提到 32768，降低网页/PPT长任务截断概率。
4. Hermes Agent 任务默认 `stream=false`，先让工具链完整执行再回传结果，避免 OpenWebUI 收到半截空回复。
5. `SOUL.md`、`wow-demo` skill、`docs/TROUBLESHOOT.md`、`scripts/smoke-test.sh` 同步加入验证与路径提示规则。

## 30 轮清单

| 轮次 | 优先级 | 目标 | 具体改进 | 验收 |
|---|---|---|---|---|
| 01 | P0 | 文件路径可信 | `/host` 自动映射成本机路径，回复带 `file://` | 生成文件后用户能直接在 Finder 找到 |
| 02 | P0 | 长网页/PPT不截断 | Hermes Agent `max_tokens=32768`，大文件要求分段/脚本生成 | 15 页 HTML/PPT 不出现空回复 |
| 03 | P0 | 承诺即验证 | SOUL + Bridge 要求 `test -s` / `wc -c` 后才能说已保存 | 0KB 文件不再被报成功 |
| 04 | P0 | smoke-test 防假阳性 | 第 9 项验证真实写 `/host`，并检查本机路径提示 | `bash scripts/smoke-test.sh` 通过 |
| 05 | P0 | 失败有解释 | 捕获 Hermes 500/截断/迭代耗尽，中文返回“卡在哪层” | 不再只显示空白或 Failed to fetch |
| 06 | P0 | 路由准确 | 普通问答轻量直连；文件/网页/提醒/记忆/图片强制 Hermes | 20 条路由用例命中率 > 95% |
| 07 | P0 | OpenWebUI 中文完整 | onboarding、建议词、错误 toast、默认提示全部中文 | 首屏截图无英文漏出 |
| 08 | P1 | Agent 状态可见 | 真任务显示“正在规划/写文件/验证/完成”状态 | 用户知道不是页面卡死 |
| 09 | P1 | web_search 冲突处理 | 禁止 Hermes 调不存在的 `web_search`，或建立可用 alias | 日志不再出现 Unknown tool |
| 10 | P1 | 迭代预算自救 | 接近 50 轮前总结当前状态并退出/重试简化版本 | 无 50/50 死循环 |
| 11 | P1 | 辅助摘要模型兜底 | Hermes 无 auxiliary model 时使用主模型压缩，或降级为短上下文任务 | 长会话不因摘要缺失失控 |
| 12 | P1 | Memory 分工互通 | OpenWebUI 保留聊天/知识库；Hermes 保留执行记忆；共享摘要同步偏好 | 新会话仍知道稳定偏好 |
| 13 | P1 | 记忆可视化 | 增加共享摘要查看/刷新入口 | 用户能看到“记住了什么” |
| 14 | P1 | 默认 wow 模版 | 内置桌面整理、个人网站、周报、旅行、错误诊断等 10 个中文 demo | 首次启动 30 秒内能跑 demo |
| 15 | P1 | 文件安全 | 删除、覆盖、移动、批量重命名前要求确认 | 不误删用户文件 |
| 16 | P1 | 输出目录规范 | 所有默认产物放 `/host/OpenDeepSeek-Outputs` | 输出不散落在奇怪目录 |
| 17 | P2 | 手机体验 | Tailscale/PWA 指南 + 手机端字体/按钮/状态检查 | 手机能正常发起 Agent 任务 |
| 18 | P2 | 图片任务稳定 | 图片先由 Bridge 落盘 OCR，Hermes 使用图片路径和 OCR 结果 | 不要求用户“别传图片” |
| 19 | P2 | OpenWebUI Native tools 融合 | OpenWebUI 自带 Knowledge/Notes/Memory 能做的保留；做不到的进 Hermes | 不重复造功能 |
| 20 | P2 | 一键部署前置检查 | 检查 Docker、端口、API key、磁盘权限、网络 | 小白安装失败原因清楚 |
| 21 | P2 | 隐私发布 | `.env`、本地数据、OpenWebUI 数据库、Hermes memory 不进 Git | GitHub 无密钥/隐私 |
| 22 | P2 | 统一日志 | Bridge/Hermes/OpenWebUI 一条请求能串起来 | Debug 不再靠猜 |
| 23 | P2 | 成本与速度指标 | 记录轻量路径 vs Agent 路径耗时/token | 能解释“为什么这次慢” |
| 24 | P2 | Release 包 | `package-release.sh` 生成干净压缩包和部署说明 | 小白下载即跑 |
| 25 | P3 | 示例输出图库 | 收集网站/PPT/周报成功产物截图 | GitHub README 更有说服力 |
| 26 | P3 | Agent 能力自报 | SOUL 能主动说明“我能看文件/做提醒/生成网页”但不刷屏 | 新用户知道怎么用 |
| 27 | P3 | 失败重试按钮 | OpenWebUI 里给“简化重试/继续生成/只生成大纲” | 长任务失败后能继续 |
| 28 | P3 | 压测脚本 | 10 个新对话 × 3 轮，覆盖聊天/文件/网页/记忆/提醒 | 发布前有真实报告 |
| 29 | P3 | GitHub PR/Release | 推到无隐私分支，准备 README、CHANGELOG、安装文档 | 外部用户能看懂 |
| 30 | P3 | 发布视频材料 | 数据飞轮、DeepSeek低价、Hermes Agent、默认 demo 串成视频 MD | 视频能解释项目初心 |

## 功能融合原则

1. OpenWebUI 不要被绕开：它负责用户界面、历史、知识库、上传和移动端体验。
2. Hermes 不要被削弱：它负责真执行、工具、Cron、Skills、Subagent、本机文件。
3. Smart Bridge 是判断层：不是所有问题都走 Agent，普通问答必须快；但真任务必须进 Hermes。
4. Memory 不要互相抢：OpenWebUI 记聊天和知识库，Hermes 记执行偏好，轻量共享摘要只存稳定偏好。
5. 发布前必须 trust but verify：看实际文件、看日志、跑 smoke-test，不信模型自报完成。

## 对话 `954d905f-c7e8-4cdc-989f-150656f74a98` 的结论

- 对话里提到的 `/host/OpenDeepSeek-Outputs/wow-ppt/index.html` 实际对应：

```text
/Users/lauralyu/OpenDeepSeek-Outputs/wow-ppt/index.html
```

- 这个文件存在。用户找不到是因为 UI 只给了容器路径。
- 后续“15+ 页”那轮出现空回复，结合 Hermes 日志看，主要是长任务工具调用截断/迭代耗尽，不是 OpenWebUI 页面单纯坏掉。
