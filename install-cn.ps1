# OpenDeepSeek CN smart installer for Windows PowerShell.
# This is a bootstrapper for the China-ready distribution path.

param(
  [string]$InstallDir = "$HOME\opendeepseek-cn",
  [string]$OfflineImages = $env:OPDS_CN_OFFLINE
)

$ErrorActionPreference = "Stop"

function Info($Message) { Write-Host "INFO $Message" -ForegroundColor Cyan }
function Ok($Message) { Write-Host "OK   $Message" -ForegroundColor Green }
function Warn($Message) { Write-Host "WARN $Message" -ForegroundColor Yellow }
function Fail($Message) { Write-Host "FAIL $Message" -ForegroundColor Red; exit 1 }

function Test-Command($Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function New-RandomHex {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Set-EnvValue($Path, $Key, $Value) {
  $lines = Get-Content $Path
  $found = $false
  $updated = foreach ($line in $lines) {
    if ($line -match "^$([regex]::Escape($Key))=") {
      $found = $true
      "$Key=$Value"
    } else {
      $line
    }
  }
  if (-not $found) {
    $updated += "$Key=$Value"
  }
  Set-Content -Path $Path -Value $updated -Encoding UTF8
}

Info "OpenDeepSeek CN installer"

if (-not (Test-Command "git")) { Fail "缺少 git，请先安装 Git for Windows。" }
if (-not (Test-Command "docker")) { Fail "缺少 Docker，请先安装并启动 Docker Desktop。" }

try {
  docker compose version | Out-Null
} catch {
  Fail "缺少 docker compose v2。"
}

$repo = $env:OPDS_CN_GITEE_REPO
if (-not $repo) { $repo = "https://gitee.com/luoxueai/opendeepseek.git" }
$fallback = $env:OPDS_GITHUB_REPO
if (-not $fallback) { $fallback = "https://github.com/mouxue56-debug/opendeepseek.git" }

if ((Test-Path "setup.sh") -and (Test-Path "docker-compose.cn.yml")) {
  Ok "当前目录已是 OpenDeepSeek 仓库"
} elseif (Test-Path "$InstallDir\.git") {
  Set-Location $InstallDir
  Ok "进入已有安装目录：$InstallDir"
} else {
  Info "克隆仓库：$repo"
  try {
    git clone $repo $InstallDir
  } catch {
    Warn "Gitee 克隆失败，尝试 GitHub fallback：$fallback"
    git clone $fallback $InstallDir
  }
  Set-Location $InstallDir
}

if (-not (Test-Path ".env")) {
  Copy-Item ".env.example.cn" ".env"
  Ok "已创建 .env"
}

$envText = Get-Content ".env" -Raw
if ($envText.Contains("your-deepseek-api-key-here")) {
  $key = Read-Host "请输入 DeepSeek API Key"
  if (-not $key) { Fail "DeepSeek API Key 不能为空" }
  Set-EnvValue ".env" "DEEPSEEK_API_KEY" $key
}

$envText = Get-Content ".env" -Raw
if ($envText.Contains("auto-generated-by-install-cn")) {
  Set-EnvValue ".env" "HERMES_API_KEY" (New-RandomHex)
  Set-EnvValue ".env" "WEBUI_SECRET_KEY" (New-RandomHex)
  Ok "已生成本机随机密钥"
}

if ($OfflineImages) {
  if (-not (Test-Path $OfflineImages)) { Fail "离线镜像包不存在：$OfflineImages" }
  Warn "Windows 版暂不自动解压 tar.zst。请先用 zstd 解压后执行 docker load。"
}

try {
  docker info | Out-Null
} catch {
  Fail "Docker daemon 未启动。请先打开 Docker Desktop。"
}

Info "启动 OpenDeepSeek CN"
docker compose -f docker-compose.cn.yml up -d
Ok "OpenDeepSeek CN 已启动：http://localhost:3000"
