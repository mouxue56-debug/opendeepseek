/**
 * OpenDeepSeek PWA 安装引导脚本
 * 版本：v1.0.0
 * 功能：检测设备类型，引导用户"添加到主屏幕"，让 OpenDeepSeek 像真 App 一样使用
 *
 * 使用方式：
 *   由 /static/loader.js 自动加载，无需在后台粘贴 Custom JS
 *
 * 支持平台：
 *   - iOS Safari（教用户手动添加）
 *   - Android Chrome（原生 install prompt）
 *   - 桌面浏览器（友好提示）
 */

(function () {
  'use strict';

  // ──────────────────────────────────────────────
  // 配置
  // ──────────────────────────────────────────────
  var CONFIG = {
    STORAGE_KEY_DISMISSED: 'ods_pwa_dismissed_until',
    STORAGE_KEY_INSTALLED: 'ods_pwa_installed',
    DISMISS_DAYS: 7,           // 关闭后 N 天内不再提示
    SHOW_DELAY_MS: 2500,       // 页面加载后延迟显示（ms）
    BANNER_ID: 'ods-pwa-banner',
    CSS_FILE: '/static/pwa-prompt.css',
  };

  // ──────────────────────────────────────────────
  // 工具函数
  // ──────────────────────────────────────────────
  function isIOS() {
    return /iphone|ipad|ipod/i.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  }

  function isAndroid() {
    return /android/i.test(navigator.userAgent);
  }

  function isInStandaloneMode() {
    return (
      window.matchMedia('(display-mode: standalone)').matches ||
      window.navigator.standalone === true ||
      document.referrer.includes('android-app://')
    );
  }

  function isIOSSafari() {
    return isIOS() && /safari/i.test(navigator.userAgent) && !/crios|fxios|opios|mercury/i.test(navigator.userAgent);
  }

  function isAndroidChrome() {
    return isAndroid() && /chrome/i.test(navigator.userAgent) && !/opr\/|yabrowser|miui/i.test(navigator.userAgent);
  }

  function isMobile() {
    return isIOS() || isAndroid();
  }

  function shouldShow() {
    // 已安装，永久不提示
    if (localStorage.getItem(CONFIG.STORAGE_KEY_INSTALLED)) return false;
    // 已是 standalone 模式
    if (isInStandaloneMode()) {
      localStorage.setItem(CONFIG.STORAGE_KEY_INSTALLED, '1');
      return false;
    }
    // 7 天内已关闭
    var dismissedUntil = localStorage.getItem(CONFIG.STORAGE_KEY_DISMISSED);
    if (dismissedUntil && Date.now() < parseInt(dismissedUntil, 10)) return false;
    return true;
  }

  function markDismissed() {
    var until = Date.now() + CONFIG.DISMISS_DAYS * 24 * 60 * 60 * 1000;
    localStorage.setItem(CONFIG.STORAGE_KEY_DISMISSED, String(until));
  }

  function markInstalled() {
    localStorage.setItem(CONFIG.STORAGE_KEY_INSTALLED, '1');
    localStorage.removeItem(CONFIG.STORAGE_KEY_DISMISSED);
  }

  // ──────────────────────────────────────────────
  // 注入 CSS
  // ──────────────────────────────────────────────
  function injectCSS() {
    if (document.getElementById('ods-pwa-css')) return;
    var link = document.createElement('link');
    link.id = 'ods-pwa-css';
    link.rel = 'stylesheet';
    link.href = CONFIG.CSS_FILE;
    document.head.appendChild(link);
  }

  // ──────────────────────────────────────────────
  // Banner 构建
  // ──────────────────────────────────────────────
  function buildBanner(content) {
    var banner = document.createElement('div');
    banner.id = CONFIG.BANNER_ID;
    banner.className = 'ods-pwa-banner';
    banner.setAttribute('role', 'dialog');
    banner.setAttribute('aria-label', '添加到主屏幕');
    banner.innerHTML = content;
    return banner;
  }

  function removeBanner() {
    var existing = document.getElementById(CONFIG.BANNER_ID);
    if (existing) {
      existing.classList.add('ods-pwa-banner--hiding');
      setTimeout(function () {
        if (existing.parentNode) existing.parentNode.removeChild(existing);
      }, 350);
    }
  }

  function showBanner(banner) {
    document.body.appendChild(banner);
    // 触发入场动画
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        banner.classList.add('ods-pwa-banner--visible');
      });
    });

    // 关闭按钮
    var closeBtn = banner.querySelector('.ods-pwa-close');
    if (closeBtn) {
      closeBtn.addEventListener('click', function () {
        markDismissed();
        removeBanner();
      });
    }
  }

  // ──────────────────────────────────────────────
  // iOS Safari Banner
  // ──────────────────────────────────────────────
  function showIOSBanner() {
    var content = [
      '<div class="ods-pwa-inner">',
      '  <div class="ods-pwa-icon">🤖</div>',
      '  <div class="ods-pwa-body">',
      '    <div class="ods-pwa-title">添加到主屏幕，像 App 一样用</div>',
      '    <div class="ods-pwa-steps">',
      '      <span class="ods-pwa-step">',
      '        <span class="ods-pwa-step-icon">1</span>',
      '        点底部 <span class="ods-pwa-highlight">分享</span>',
      '        <span class="ods-pwa-emoji-btn">',
      '          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">',
      '            <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/>',
      '            <polyline points="16 6 12 2 8 6"/>',
      '            <line x1="12" y1="2" x2="12" y2="15"/>',
      '          </svg>',
      '        </span>',
      '      </span>',
      '      <span class="ods-pwa-arrow">→</span>',
      '      <span class="ods-pwa-step">',
      '        <span class="ods-pwa-step-icon">2</span>',
      '        选 <span class="ods-pwa-highlight">添加到主屏幕</span>',
      '        <span class="ods-pwa-emoji-btn">＋</span>',
      '      </span>',
      '      <span class="ods-pwa-arrow">→</span>',
      '      <span class="ods-pwa-step">',
      '        <span class="ods-pwa-step-icon">3</span>',
      '        点 <span class="ods-pwa-highlight">添加</span> ✅',
      '      </span>',
      '    </div>',
      '  </div>',
      '  <button class="ods-pwa-close" aria-label="关闭">✕</button>',
      '</div>',
      '<div class="ods-pwa-arrow-down"></div>',
    ].join('');

    var banner = buildBanner(content);
    banner.classList.add('ods-pwa-banner--ios');
    showBanner(banner);
  }

  // ──────────────────────────────────────────────
  // Android Chrome Banner（原生 prompt）
  // ──────────────────────────────────────────────
  var deferredPrompt = null;

  function showAndroidBanner() {
    var content = [
      '<div class="ods-pwa-inner">',
      '  <div class="ods-pwa-icon">🤖</div>',
      '  <div class="ods-pwa-body">',
      '    <div class="ods-pwa-title">安装为 App，速度更快</div>',
      '    <div class="ods-pwa-desc">无广告、全屏、离线可用，和真 App 一样</div>',
      '  </div>',
      '  <button class="ods-pwa-install-btn" id="ods-pwa-install">安装</button>',
      '  <button class="ods-pwa-close" aria-label="关闭">✕</button>',
      '</div>',
    ].join('');

    var banner = buildBanner(content);
    banner.classList.add('ods-pwa-banner--android');
    showBanner(banner);

    var installBtn = banner.querySelector('#ods-pwa-install');
    if (installBtn) {
      installBtn.addEventListener('click', function () {
        if (deferredPrompt) {
          deferredPrompt.prompt();
          deferredPrompt.userChoice.then(function (choiceResult) {
            if (choiceResult.outcome === 'accepted') {
              markInstalled();
            } else {
              markDismissed();
            }
            deferredPrompt = null;
            removeBanner();
          });
        }
      });
    }
  }

  // ──────────────────────────────────────────────
  // Desktop Banner
  // ──────────────────────────────────────────────
  function showDesktopBanner() {
    var content = [
      '<div class="ods-pwa-inner">',
      '  <div class="ods-pwa-icon">💻</div>',
      '  <div class="ods-pwa-body">',
      '    <div class="ods-pwa-title">想要桌面 App？</div>',
      '    <div class="ods-pwa-desc">Chrome/Edge：地址栏右侧点 <span class="ods-pwa-highlight">⊕ 安装</span> 图标，即可固定到桌面。',
      '    也可查看 <a class="ods-pwa-link" href="https://github.com/mouxue56-debug/opendeepseek/blob/main/docs/ONE-CLICK.md" target="_blank" rel="noopener noreferrer">安装指引</a>。</div>',
      '  </div>',
      '  <button class="ods-pwa-close" aria-label="关闭">✕</button>',
      '</div>',
    ].join('');

    var banner = buildBanner(content);
    banner.classList.add('ods-pwa-banner--desktop');
    showBanner(banner);
  }

  // ──────────────────────────────────────────────
  // Desktop Banner（含原生 install prompt 按钮）
  // ──────────────────────────────────────────────
  function showDesktopInstallBanner() {
    var content = [
      '<div class="ods-pwa-inner">',
      '  <div class="ods-pwa-icon">💻</div>',
      '  <div class="ods-pwa-body">',
      '    <div class="ods-pwa-title">安装为桌面 App</div>',
      '    <div class="ods-pwa-desc">无需浏览器，直接从桌面启动 OpenDeepSeek</div>',
      '  </div>',
      '  <button class="ods-pwa-install-btn" id="ods-pwa-install-desktop">安装</button>',
      '  <button class="ods-pwa-close" aria-label="关闭">✕</button>',
      '</div>',
    ].join('');

    var banner = buildBanner(content);
    banner.classList.add('ods-pwa-banner--desktop');
    showBanner(banner);

    var installBtn = banner.querySelector('#ods-pwa-install-desktop');
    if (installBtn && deferredPrompt) {
      installBtn.addEventListener('click', function () {
        deferredPrompt.prompt();
        deferredPrompt.userChoice.then(function (choiceResult) {
          if (choiceResult.outcome === 'accepted') {
            markInstalled();
          } else {
            markDismissed();
          }
          deferredPrompt = null;
          removeBanner();
        });
      });
    }
  }

  // ──────────────────────────────────────────────
  // 主逻辑
  // ──────────────────────────────────────────────
  function init() {
    if (!shouldShow()) return;

    injectCSS();

    // 监听 Android/Desktop 原生 install prompt
    window.addEventListener('beforeinstallprompt', function (e) {
      e.preventDefault();
      deferredPrompt = e;
    });

    // 监听 appinstalled（用户通过浏览器菜单安装了）
    window.addEventListener('appinstalled', function () {
      markInstalled();
      removeBanner();
    });

    // 延迟显示
    setTimeout(function () {
      if (!shouldShow()) return;

      if (isIOSSafari()) {
        showIOSBanner();
      } else if (isAndroidChrome()) {
        // Android：等 beforeinstallprompt 就绪后显示
        if (deferredPrompt) {
          showAndroidBanner();
        } else {
          // beforeinstallprompt 尚未触发，再等 1 秒
          setTimeout(function () {
            if (deferredPrompt) {
              showAndroidBanner();
            }
            // 没有 prompt（可能已安装或不支持），静默不显示
          }, 1000);
        }
      } else if (!isMobile()) {
        // 桌面
        if (deferredPrompt) {
          showDesktopInstallBanner();
        } else {
          showDesktopBanner();
        }
      }
    }, CONFIG.SHOW_DELAY_MS);
  }

  // DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
