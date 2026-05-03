# 贡献指南

## 1. 欢迎贡献

感谢你对 OpenDeepSeek 的关注！OpenDeepSeek 的目标是让每个人都能一键在本地部署属于自己的 Agentic AI 助手（DeepSeek V4 + Open WebUI + Hermes Agent），无需依赖任何云服务。我们欢迎各种形式的贡献，包括 bug 修复、新功能开发、文档改善、IM 适配器扩展以及多语言翻译。无论你是初学者还是资深开发者，都可以在这里找到适合自己的参与方式。

---

## 2. 行为准则

参与本项目即表示你同意遵守我们的行为准则：

- **友善**：对所有人保持礼貌和友好，无论其经验水平如何。
- **包容**：欢迎来自不同背景的贡献者，尊重多元视角。
- **专业**：专注于技术讨论，避免人身攻击或无建设性的批评。

本项目采用 [Contributor Covenant 行为准则 v2.1](https://www.contributor-covenant.org/zh-cn/version/2/1/code_of_conduct/)。如发现违规行为，请通过 issue 或邮件联系维护者。

---

## 3. 报告 Bug

请在 [GitHub Issues](https://github.com/opendeepseek/opendeepseek/issues) 提交 bug 报告。

**必须包含以下信息：**

- 操作系统及版本（如 macOS 15.0 / Ubuntu 24.04）
- Docker 版本（`docker --version` 输出）
- Docker Compose 版本（`docker compose version` 输出）
- 详细的复现步骤（最小可复现步骤）
- `docker compose logs` 的完整输出

**Issue 模板示例：**

```markdown
**Bug 描述**
简要描述问题现象。

**复现步骤**
1. 执行 `./setup.sh`
2. 访问 http://localhost:3000
3. 点击 ...
4. 出现错误

**期望行为**
描述你期望发生的事情。

**实际行为**
描述实际发生了什么。

**环境信息**
- OS: macOS 15.2
- Docker: 27.3.1
- Docker Compose: v2.30.3

**日志输出**
\`\`\`
在此粘贴 docker compose logs 输出
\`\`\`
```

---

## 4. 提交功能请求

在开 issue 之前，请先在 [GitHub Discussions](https://github.com/opendeepseek/opendeepseek/discussions) 发帖讨论，确认该功能符合项目方向并获得社区反馈。

功能请求 issue 应包含：

- **用户场景**：描述是谁在什么情况下需要这个功能（如"作为企业用户，我需要…"）
- **期望行为**：详细描述功能的预期效果
- **备选方案**：是否考虑过其他实现方式，各自的优劣是什么

---

## 5. 提交 Pull Request

请按以下完整流程操作：

1. **Fork 仓库**，并将 fork 后的仓库克隆到本地。

2. **创建 feature 分支**：

```bash
git checkout -b feature/your-feature
```

3. **准备本地环境**，先运行 setup 脚本确保依赖就绪：

```bash
./setup.sh
```

4. **完成开发后运行 smoke-test**，必须全部通过：

```bash
bash scripts/smoke-test.sh
```

输出应显示 `7/7 PASS`，任何失败均需修复后再提交。

5. **按规范书写 commit message**（见第 6 节）。

6. **Push 分支并创建 PR**：

```bash
git push origin feature/your-feature
```

在 GitHub 上创建 Pull Request，填写 PR 描述，说明改动内容和测试结果。

7. **等待 CI 通过 + 至少 1 位 maintainer review**，根据反馈修改后合并。

---

## 6. Commit Message 规范

本项目采用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/) 规范：

| 前缀 | 用途 |
|------|------|
| `feat:` | 新功能 |
| `fix:` | bug 修复 |
| `docs:` | 文档变更 |
| `chore:` | 杂项（依赖更新、构建脚本等） |
| `refactor:` | 重构（不改变功能） |
| `test:` | 新增或修改测试 |

**示例：**

```
feat: 添加飞书 IM 桥接适配器支持群消息推送
fix: 修复 setup.sh 在 macOS Apple Silicon 上 Docker 检测失败问题
docs: 更新 README 中的一键部署命令，兼容 Docker Compose v2
```

---

## 7. 代码风格

**Bash 脚本**

- 必须通过 `shellcheck -S error` 检查，零警告零错误
- 使用 4 空格缩进（不使用 tab）
- 变量命名使用小写下划线，如 `docker_version`、`service_name`

**Python（如有）**

- 使用 [black](https://github.com/psf/black) 格式化代码
- 使用 [ruff](https://github.com/astral-sh/ruff) 进行 lint 检查

**YAML**

- 遵循 `yamllint` 默认规则
- 最大行长设置为 200 个字符

**Markdown**

- 标题统一使用 ATX 风格（`#`、`##`，不使用 `===` 下划线风格）
- 代码块使用三反引号并标注语言，如 ` ```bash `、` ```yaml `

---

## 8. 测试要求

- **修改 `docker-compose.yml`、`setup.sh` 或 Hermes 相关配置**：必须重新运行 `bash scripts/smoke-test.sh`，确保 7/7 PASS。
- **修改文档**：检查所有内部链接是否有效；如涉及 YAML 或 Shell 文件，需分别通过 `yamllint` 和 `shellcheck` 检查。
- **新增功能**：须在 `scripts/smoke-test.sh` 中补充对应的检查项，保证新功能有自动化验证覆盖。

---

## 9. 添加新 IM 桥接适配器

OpenDeepSeek 当前已原生支持 5 个中国本土 IM 平台：**钉钉、飞书、企业微信、邮件和 QQ Bot**。

如果你希望为新平台添加桥接支持，请按以下步骤操作：

1. 修改 `docker-compose.yml` 中 `hermes` 服务的环境变量段，添加新平台的配置项。

2. 在 `.env.example` 中补充对应的环境变量占位说明。

3. 更新 `docs/IM-BRIDGE.md`，在支持列表中添加新平台条目。

4. 在文档中补充完整的使用说明，包括：
   - 如何在对应平台创建机器人/应用
   - 需要填写哪些 token / secret
   - 如何验证桥接是否生效

5. 运行 `bash scripts/smoke-test.sh` 验证新适配器不破坏现有功能。

---

## 10. 翻译贡献

- 项目文档以**简体中文（zh-CN）**为主语言。
- Open WebUI 原生支持 30 种语言的界面翻译，无需额外贡献。
- **英文版文档（en-US）**欢迎社区贡献：翻译文件请放置于 `docs/en/` 目录下（如目录不存在请自行创建）。
- 翻译时请保持与中文原文的结构和内容一致，技术术语保留英文原词。

---

## 11. 联系 Maintainer

如有任何问题或建议，欢迎通过以下方式联系：

- **GitHub**：[@mouxue56-debug](https://github.com/mouxue56-debug)（占位，待项目 owner 更新）
- **Discord**：服务器即将上线，敬请期待
- **邮件**：[contact@opendeepseek.example](mailto:contact@opendeepseek.example)（占位）

再次感谢你愿意为 OpenDeepSeek 贡献力量！
