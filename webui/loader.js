/**
 * OpenDeepSeek browser polish loaded by Open WebUI's /static/loader.js hook.
 * Keep this file dependency-free and safe to run before the Svelte app mounts.
 */
(function () {
  'use strict';

  var replacements = {
    Suggested: '建议',
    Prompt: '提示词',
    'How can I help you today?': '今天想让我帮你做什么？',
    'New Chat': '新对话',
    'Temporary Chat': '临时对话',
    'Search chats': '搜索对话',
    'Add Model': '添加模型',
    Controls: '控制',
    'Voice Input': '语音输入',
    'User Menu': '用户菜单',
    'No models found': '没有可用模型',
    'No models selected': '未选择模型',
    'Model not selected': '还没有选择模型',
  };

  function replaceTextNode(node) {
    var text = node.nodeValue;
    if (!text) return;
    var trimmed = text.trim();
    if (!trimmed || !Object.prototype.hasOwnProperty.call(replacements, trimmed)) return;
    node.nodeValue = text.replace(trimmed, replacements[trimmed]);
  }

  function walk(root) {
    if (!root) return;
    if (root.nodeType === Node.ELEMENT_NODE) replaceElementAttributes(root);
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    var node;
    while ((node = walker.nextNode())) replaceTextNode(node);

    var elements = root.querySelectorAll ? root.querySelectorAll('[aria-label], [title], [placeholder]') : [];
    elements.forEach(replaceElementAttributes);
  }

  function replaceElementAttributes(el) {
    ['aria-label', 'title', 'placeholder'].forEach(function (attr) {
      var value = el.getAttribute && el.getAttribute(attr);
      if (value && Object.prototype.hasOwnProperty.call(replacements, value.trim())) {
        el.setAttribute(attr, value.replace(value.trim(), replacements[value.trim()]));
      }
    });
  }

  function observeChineseUI() {
    walk(document.body);
    var observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (mutation) {
        if (mutation.type === 'attributes') {
          replaceElementAttributes(mutation.target);
          return;
        }
        mutation.addedNodes.forEach(function (node) {
          if (node.nodeType === Node.TEXT_NODE) {
            replaceTextNode(node);
          } else if (node.nodeType === Node.ELEMENT_NODE) {
            walk(node);
          }
        });
      });
    });
    observer.observe(document.body, {
      attributes: true,
      attributeFilter: ['aria-label', 'title', 'placeholder'],
      childList: true,
      subtree: true,
    });

    var passes = 0;
    var timer = window.setInterval(function () {
      walk(document.body);
      passes += 1;
      if (passes >= 16) window.clearInterval(timer);
    }, 500);
  }

  function loadScript(src) {
    if (document.querySelector('script[src="' + src + '"]')) return;
    var script = document.createElement('script');
    script.src = src;
    script.defer = true;
    script.crossOrigin = 'use-credentials';
    document.head.appendChild(script);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', observeChineseUI, { once: true });
  } else {
    observeChineseUI();
  }

  loadScript('/static/pwa-prompt.js');
})();
