#!/usr/bin/env python3
"""
OpenDeepSeek Onboarding Server
零依赖 HTTP server（仅用 Python 标准库）
监听 127.0.0.1:3001，引导用户填写 DeepSeek API Key
"""

import http.server
import json
import pathlib
import secrets
import subprocess
import sys
import threading
import time
import urllib.request
from urllib.parse import urlparse

# --------------------------------------------------------------------------- #
# 路径设置
# --------------------------------------------------------------------------- #
SCRIPT_DIR = pathlib.Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
STATIC_DIR = SCRIPT_DIR / "static"
INDEX_HTML = SCRIPT_DIR / "index.html"
ENV_FILE = PROJECT_ROOT / ".env"

PORT = 3001
HOST = "127.0.0.1"

# 全局启动状态（写入配置后由后台线程更新）
_startup_state = {
    "phase": "idle",       # idle | writing | starting | checking | ready | error
    "message": "",
    "error": "",
}
_startup_lock = threading.Lock()


# --------------------------------------------------------------------------- #
# 工具函数
# --------------------------------------------------------------------------- #

def _set_state(phase: str, message: str = "", error: str = ""):
    with _startup_lock:
        _startup_state["phase"] = phase
        _startup_state["message"] = message
        _startup_state["error"] = error


def _write_env(deepseek_api_key: str, model: str):
    """写入 .env 文件（覆盖已有内容中的相关行，保留其余内容）"""
    existing: dict[str, str] = {}
    original_lines: list[str] = []

    if ENV_FILE.exists():
        original_lines = ENV_FILE.read_text(encoding="utf-8").splitlines()
        for line in original_lines:
            stripped = line.strip()
            if stripped and not stripped.startswith("#") and "=" in stripped:
                k, _, v = stripped.partition("=")
                existing[k.strip()] = v.strip()

    # 注入/覆盖关键 key
    existing["DEEPSEEK_API_KEY"] = deepseek_api_key
    existing["DEFAULT_MODEL"] = model
    # 只在不存在时生成随机密钥（幂等）
    if not existing.get("HERMES_API_KEY"):
        existing["HERMES_API_KEY"] = secrets.token_hex(32)
    if not existing.get("WEBUI_SECRET_KEY"):
        existing["WEBUI_SECRET_KEY"] = secrets.token_hex(32)
    if not existing.get("HERMES_HOST_DIR"):
        existing["HERMES_HOST_DIR"] = str(pathlib.Path.home())

    updates = {
        "DEEPSEEK_API_KEY": existing["DEEPSEEK_API_KEY"],
        "DEFAULT_MODEL": existing["DEFAULT_MODEL"],
        "ENABLE_TITLE_GENERATION": "false",
        "ENABLE_TAGS_GENERATION": "false",
        "ENABLE_FOLLOW_UP_GENERATION": "false",
        "ENABLE_LIGHTWEIGHT_ROUTING": "true",
        "HERMES_AGENT_MAX_TOKENS": "32768",
        "HERMES_AGENT_STREAM": "false",
        "HERMES_PROGRESS_STREAM": "true",
        "OPDS_SHARED_MEMORY_PATH": "/host/OpenDeepSeek-Memory/profile.md",
        "OPDS_MEMORY_SNAPSHOT_MAX_CHARS": "4000",
        "OPDS_HOST_DISPLAY_PREFIX": existing["HERMES_HOST_DIR"],
        "HERMES_API_KEY": existing["HERMES_API_KEY"],
        "WEBUI_SECRET_KEY": existing["WEBUI_SECRET_KEY"],
        "HERMES_HOST_DIR": existing["HERMES_HOST_DIR"],
    }
    seen: set[str] = set()
    output_lines: list[str] = []

    for line in original_lines:
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            k, _, _ = stripped.partition("=")
            key = k.strip()
            if key in updates:
                output_lines.append(f"{key}={updates[key]}")
                seen.add(key)
                continue
        output_lines.append(line)

    if output_lines and output_lines[-1].strip():
        output_lines.append("")
    for key, value in updates.items():
        if key not in seen:
            output_lines.append(f"{key}={value}")

    ENV_FILE.write_text("\n".join(output_lines) + "\n", encoding="utf-8")


def _normalize_model(model: str) -> str:
    """兼容旧表单值，但最终只写 DeepSeek V4 模型名。"""
    aliases = {
        "deepseek-chat": "deepseek-v4-flash",
        # 2026-07-24 前的兼容别名：reasoner 是 V4 Flash 思考模式，不是 v4-pro。
        "deepseek-reasoner": "deepseek-v4-flash",
    }
    model = aliases.get(model, model)
    if model not in {"deepseek-v4-flash", "deepseek-v4-pro"}:
        return "deepseek-v4-flash"
    return model


def _check_service(url: str, timeout: int = 3) -> bool:
    """检查 URL 是否返回 2xx/3xx"""
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status < 400
    except Exception:
        return False


def _log(msg: str):
    """日志同时打印到 stderr 让用户能看到（setup.sh 跑时这里会进 onboarding-server.log）"""
    print(f"[onboarding] {msg}", file=sys.stderr, flush=True)


def _docker_up_and_wait():
    """后台线程：docker compose up → 轮询健康

    幂等：如果 stack 已健康，直接进 ready 状态（不重启服务）。
    如果未跑：docker compose up -d → 等 healthy → 跑 hermes-fix-model.sh。
    """
    # 端口正确：webui=3000, hermes=8642（之前写的 8080 是 bug）
    webui_url = "http://localhost:3000"
    hermes_health_url = "http://localhost:8642/health"

    # 1. 先检查 stack 是否已经在跑且健康（幂等）
    _set_state("checking", "检查容器状态…")
    if _check_service(webui_url) and _check_service(hermes_health_url):
        _log("Docker stack 已经在跑且健康，跳过启动")
        _set_state("ready", "服务已运行，正在跳转…")
        return

    # 2. 启动 docker compose
    _set_state("starting", "正在启动容器…")
    _log("docker compose up -d")

    try:
        result = subprocess.run(
            ["docker", "compose", "up", "-d"],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            timeout=180,
        )
        _log(f"docker compose stdout: {result.stdout[:500]}")
        if result.stderr:
            _log(f"docker compose stderr: {result.stderr[:500]}")
        if result.returncode != 0:
            _set_state(
                "error",
                "docker compose 启动失败",
                (result.stderr or result.stdout)[:2000],
            )
            return
    except FileNotFoundError:
        _set_state(
            "error",
            "找不到 docker 命令",
            "请先安装 Docker Desktop：https://www.docker.com/products/docker-desktop",
        )
        return
    except subprocess.TimeoutExpired:
        _set_state("error", "docker compose 超时（>180s）", "网络太慢或镜像拉取卡住")
        return
    except Exception as exc:
        _set_state("error", f"启动失败: {type(exc).__name__}", str(exc)[:1000])
        return

    # 3. 等服务 healthy
    _set_state("checking", "容器已启动，等待服务就绪（首次启动需 1-2 分钟）…")
    deadline = time.time() + 300

    while time.time() < deadline:
        webui_ok = _check_service(webui_url)
        hermes_ok = _check_service(hermes_health_url)
        _log(f"health: webui={webui_ok}, hermes={hermes_ok}")
        if webui_ok and hermes_ok:
            # 4. 跑 hermes-fix-model.sh 修正默认 model
            _set_state("checking", "应用 Hermes 模型修复（首次启动需要）…")
            fix_script = PROJECT_ROOT / "scripts" / "hermes-fix-model.sh"
            if fix_script.exists():
                try:
                    fix_result = subprocess.run(
                        ["bash", str(fix_script)],
                        cwd=str(PROJECT_ROOT),
                        capture_output=True,
                        text=True,
                        timeout=60,
                    )
                    _log(f"hermes-fix-model: {fix_result.stdout[:300]}")
                except Exception as exc:
                    _log(f"hermes-fix-model 失败（继续）: {exc}")
            _set_state("ready", "全部服务已就绪！")
            _log("✅ ready, frontend should redirect now")
            return
        time.sleep(3)

    _set_state(
        "error",
        "服务启动超时（5 分钟内未就绪）",
        f"webui_ok={_check_service(webui_url)}, hermes_ok={_check_service(hermes_health_url)}\n"
        "请运行 'docker compose logs' 查看具体错误",
    )

    _set_state(
        "error",
        "等待超时（5 分钟），服务未能在预期时间内就绪",
        "请检查 docker ps / docker compose logs",
    )


# --------------------------------------------------------------------------- #
# HTTP 请求处理
# --------------------------------------------------------------------------- #

class OnboardingHandler(http.server.BaseHTTPRequestHandler):
    # 关闭访问日志（减少终端噪音）
    def log_message(self, fmt, *args):  # noqa: N802
        pass

    # --- 路由分发 -----------------------------------------------------------

    def do_GET(self):  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        if path == "/":
            self._serve_file(INDEX_HTML, "text/html; charset=utf-8")
        elif path.startswith("/static/"):
            rel = path[len("/static/"):]
            self._serve_file(STATIC_DIR / rel)
        elif path == "/api/status":
            self._api_status()
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/api/configure":
            self._api_configure()
        else:
            self._send_json(404, {"error": "not found"})

    def do_OPTIONS(self):  # noqa: N802
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    # --- API 端点 -----------------------------------------------------------

    def _api_configure(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            data = json.loads(body)
        except Exception as exc:
            self._send_json(400, {"error": f"请求解析失败: {exc}"})
            return

        api_key: str = (data.get("deepseek_api_key") or "").strip()
        model: str = _normalize_model((data.get("model") or "deepseek-v4-flash").strip())

        # 基础校验
        if not api_key:
            self._send_json(400, {"error": "API Key 不能为空"})
            return
        if len(api_key) < 8:
            self._send_json(400, {"error": "API Key 格式不正确（太短）"})
            return

        # 写入 .env
        _set_state("writing", "正在写入配置文件…")
        try:
            _write_env(api_key, model)
        except Exception as exc:
            _set_state("error", "写入 .env 失败", str(exc))
            self._send_json(500, {"error": f"写入配置失败: {exc}"})
            return

        # 异步启动 docker
        t = threading.Thread(target=_docker_up_and_wait, daemon=True)
        t.start()

        self._send_json(202, {
            "status": "starting",
            "redirect": "http://localhost:3000",
            "check_url": "/api/status",
        })

    def _api_status(self):
        with _startup_lock:
            state = dict(_startup_state)

        ready = state["phase"] == "ready"
        self._send_json(200, {
            "ready": ready,
            "phase": state["phase"],
            "message": state["message"],
            "error": state["error"],
        })

    # --- 静态文件 -----------------------------------------------------------

    def _serve_file(self, path: pathlib.Path, content_type: str = None):
        path = pathlib.Path(path)
        if not path.exists() or not path.is_file():
            self._send_json(404, {"error": "file not found"})
            return

        if content_type is None:
            suffix = path.suffix.lower()
            content_type = {
                ".html": "text/html; charset=utf-8",
                ".css": "text/css; charset=utf-8",
                ".js": "application/javascript; charset=utf-8",
                ".json": "application/json",
                ".png": "image/png",
                ".svg": "image/svg+xml",
                ".ico": "image/x-icon",
            }.get(suffix, "application/octet-stream")

        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(data)

    # --- 辅助 ---------------------------------------------------------------

    def _send_json(self, status: int, payload: dict):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")


# --------------------------------------------------------------------------- #
# 启动入口
# --------------------------------------------------------------------------- #

def main():
    # 让端口可重用
    class ReusableServer(http.server.HTTPServer):
        allow_reuse_address = True

    server = ReusableServer((HOST, PORT), OnboardingHandler)

    print(f"\n✨ OpenDeepSeek Onboarding Server 已启动")
    print(f"   访问地址：http://localhost:{PORT}")
    print(f"   监听地址：{HOST}:{PORT}（仅本机）")
    print(f"   按 Ctrl+C 停止\n")

    # 尝试自动打开浏览器
    try:
        if sys.platform == "darwin":
            subprocess.Popen(["open", f"http://localhost:{PORT}"])
        elif sys.platform.startswith("linux"):
            subprocess.Popen(["xdg-open", f"http://localhost:{PORT}"])
        elif sys.platform == "win32":
            subprocess.Popen(["start", f"http://localhost:{PORT}"], shell=True)
    except Exception:
        pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n服务器已停止。")
        server.server_close()


if __name__ == "__main__":
    main()
