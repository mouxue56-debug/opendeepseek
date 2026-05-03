#!/bin/bash
# scripts/hermes-fix-model.sh
# 修复 Hermes config.yaml 默认 model：anthropic/claude-opus-4.6 → deepseek-v4-flash
#
# 背景：Hermes 镜像 v2026.4.23 默认 config.yaml 写死 anthropic/claude-opus-4.6，
#       但 DeepSeek API 只支持 deepseek-v4-pro / deepseek-v4-flash。
#       不修复会导致 Hermes 调 DeepSeek 时报 400 invalid_request_error。
#
# 用法：./scripts/hermes-fix-model.sh [model_name]
# 前提：docker compose up -d 已启动 hermes 容器（healthy）
# 自动调用：setup.sh 末尾会调本脚本

set -e

# 读取目标 model（从参数 / .env / 默认 三层 fallback）
TARGET_MODEL="${1:-}"
if [ -z "$TARGET_MODEL" ] && [ -f .env ]; then
    TARGET_MODEL=$(grep -m1 "^DEFAULT_MODEL=" .env | cut -d'=' -f2- | tr -d '[:space:]"' || true)
fi
TARGET_MODEL="${TARGET_MODEL:-deepseek-v4-flash}"

echo "🔧 修复 Hermes config.yaml 默认 model → ${TARGET_MODEL}"

# 检查 hermes 容器是否运行
if ! docker compose ps --status running --format json 2>/dev/null | grep -q opendeepseek-hermes; then
    echo "❌ hermes 容器未运行，先跑 docker compose up -d"
    exit 1
fi

# 用 hermes 容器内的 python3 直接修改 config.yaml（容器一定有 python3）
docker compose exec -T hermes python3 - <<PYEOF
import os
import re

config_path = "/opt/data/config.yaml"
target_model = "${TARGET_MODEL}"

if not os.path.exists(config_path):
    print(f"❌ {config_path} 不存在（hermes 还没初始化完？）")
    exit(1)

with open(config_path, "r", encoding="utf-8") as f:
    content = f.read()

# 替换 default model（精确匹配 anthropic/claude-opus-4.6 → 目标）
new_content = re.sub(
    r'default:\s*"anthropic/claude-opus-4\.6"',
    f'default: "{target_model}"',
    content,
)

if new_content == content:
    if f'default: "{target_model}"' in content:
        print(f"✅ config.yaml 已是目标 model: {target_model}（无需修改）")
    else:
        print("⚠️  config.yaml 默认 model 不是预期值，请手动检查")
    exit(0)

with open(config_path, "w", encoding="utf-8") as f:
    f.write(new_content)
print(f"✅ config.yaml default model: anthropic/claude-opus-4.6 → {target_model}")
PYEOF

# 重启 hermes 让新 config 生效
echo "🔄 重启 hermes..."
docker compose restart hermes

# 等 healthy
echo -n "⏳ 等 hermes healthy..."
for i in $(seq 1 30); do
    if curl -s http://localhost:8642/health > /dev/null 2>&1; then
        echo " ✅ ready ($((i * 2))s)"
        break
    fi
    echo -n "."
    sleep 2
done

echo "✅ Hermes 已切到 ${TARGET_MODEL}"
