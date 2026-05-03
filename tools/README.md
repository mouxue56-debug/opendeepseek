# Hermes Agent Tools for Open WebUI

本目录包含将 Hermes Agent 核心能力接入 Open WebUI 的自定义 Tool 文件。

## 6 个 Tool 说明

| Tool 函数 | 触发场景 | Hermes 内部能力 |
|-----------|----------|----------------|
| `schedule_task` | "30 分钟后提醒我..."、"每周一上午..." | Cron skill（写入 `/data/cron/jobs.json`） |
| `save_memory` | "记住我喜欢..."、"以后帮我..." | Memory skill（写入 `MEMORY.md` / `USER.md`） |
| `recall_memory` | "你记得我说过..."、"我之前提到..." | Memory skill（读取持久化记忆） |
| `parallel_research` | "同时查这三个..."、"对比一下..." | Subagent / delegate_task（并行 agent loop） |
| `file_operations` | "读取这个文件..."、"把结果写到..." | File + Terminal skill |
| `web_search` | "查一下今天..."、"搜索最新..." | web_search skill |

## 导入到 Open WebUI

1. 打开 Open WebUI，进入 **Admin Panel → Workspace → Tools**
2. 点击右上角 **+（新建 Tool）**
3. 将 `hermes_tools.py` 的全部内容粘贴进编辑器
4. 点击 **Save**，等待解析完成（6 个工具方法会自动出现）
5. 进入 **Admin Panel → Workspace → Models**，选择你要用的模型（如 DeepSeek）
6. 在该模型的 **Tools** 标签下，勾选 **Hermes Agent 工具集**，保存
7. 进入 **Admin Panel → Tools → Hermes Agent 工具集 → Valves**，填入：
   - `HERMES_API_KEY`：从项目根目录 `.env` 中复制 `HERMES_API_KEY` 的值
   - `HERMES_API_URL`：默认 `http://hermes:8642/v1`（Docker 内网，通常不用改）

## 快速测试

配置完成后，在对话框中依次测试：

```
# 测试 Cron（应能看到任务 ID）
30 分钟后提醒我喝水

# 测试 Memory 写入
记住我喜欢喝绿茶

# 测试 Memory 读取
你记得我有什么偏好吗？

# 测试 Web Search
查一下今天上海天气

# 测试 File
读取 /data/cron/jobs.json 这个文件

# 测试 Parallel Research
同时帮我查：1. Python 最新版本  2. Node.js 最新版本  3. Go 最新版本
```

观察对话旁边是否有 **Tool call** 标记展开，显示调用了对应的函数。

## 常见问题

**Q: 工具被触发但返回 `HERMES_API_KEY 未配置`**
A: 在 Admin Panel → Tools → Valves 中填入正确的 API Key。

**Q: 返回超时**
A: Hermes Agent loop 在复杂任务上可能需要较长时间。可在 Valves 中将 `DEFAULT_TIMEOUT` 从 120 调大（如 300 秒）。

**Q: `schedule_task` 执行后找不到任务**
A: 确认 Hermes 容器正常运行（`docker compose ps hermes`），并检查 `/data/cron/jobs.json` 是否有新记录。
