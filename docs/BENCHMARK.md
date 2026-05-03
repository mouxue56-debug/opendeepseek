# OpenDeepSeek Agent E2E Benchmark

最近一次端到端压测：

| 项目 | 结果 |
|---|---:|
| 模型路径 | `hermes-agent` → Smart Bridge → Hermes/DeepSeek → `deepseek-v4-flash` |
| 新会话数 | 10 |
| 每个会话轮数 | 3 |
| 总轮数 | 30 |
| 通过 | 10 / 10 |
| 失败 | 0 |
| 平均延迟 | 14.7 秒 |
| P95 延迟 | 123.1 秒 |
| Prompt tokens | 1,201,645 |
| Completion tokens | 15,856 |
| Total tokens | 1,217,501 |

## 覆盖能力

1. 中文身份与指令跟随
2. 多轮上下文记忆
3. `/host` 本机文件权限检查
4. 写入本机文件
5. 生成单文件 HTML 页面
6. 生成中文周报草稿
7. 生成短视频文案
8. Python / terminal 执行
9. 安全桌面整理方案（不移动、不删除）
10. Cron 能力说明与提醒模板

## 关键观察

- 文件类任务已能真实写入 `/host/OpenDeepSeek-Outputs/benchmark`。
- `/host/Desktop` 能通过 Hermes API 侧工具确认存在，说明 Open WebUI → Smart Bridge → Hermes → terminal/file 工具链打通。
- 当前 skills / system prompt 上下文较厚，复杂写作任务有明显长尾延迟；后续可优化默认 skill 注入和 benchmark prompt，降低 token 与延迟。

## 复现命令

```bash
python3 scripts/agent-e2e-benchmark.py
```

脚本会生成本地 JSON 报告到 `benchmark-results/`，该目录默认不发布到 GitHub。
