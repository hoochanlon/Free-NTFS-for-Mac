/* GitHub Pages / Jekyll 把 > [!TYPE] 渲染成普通 blockquote。这里按 GitHub Alert 规则改写成 callout。 */
(function () {
  var MARKER = /^\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION|WARN)\]\s*/i;
  var TITLES = {
    NOTE: 'Note',
    TIP: 'Tip',
    IMPORTANT: 'Important',
    WARNING: 'Warning',
    CAUTION: 'Caution'
  };
  var ICONS = {
    NOTE: 'M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8Zm8-6.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13ZM6.5 7.75A.75.75 0 0 1 7.25 7h1a.75.75 0 0 1 .75.75v2.75h.25a.75.75 0 0 1 0 1.5h-2a.75.75 0 0 1 0-1.5h.25v-2h-.25a.75.75 0 0 1-.75-.75ZM8 6a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z',
    TIP: 'M8 1.5c-2.363 0-4 1.69-4 3.75 0 .984.424 1.625.984 2.304l.214.253c.10.0.2.3.428.651.124.183.179.313.221.425.039.111.06.235.06.367 0 .22-.087.42-.26.577a.75.75 0 1 0 1.06 1.06c.51-.51.79-1.16.79-1.89a3.09 3.09 0 0 0-.112-.582 4.197 4.197 0 0 0-.31-.583c-.136-.199-.328-.438-.541-.8l-.217-.256C5.706 6.089 5.5 5.758 5.5 5.25c0-1.11.89-2.25 2.5-2.25s2.5 1.14 2.5 2.25c0 .507-.206.838-.537 1.237l-.217.256c-.213.362-.405.601-.541.8a4.197 4.197 0 0 0-.31.583 3.09 3.09 0 0 0-.112.582c0 .73.28 1.38.79 1.89a.75.75 0 0 0 1.06-1.06c-.173-.157-.26-.357-.26-.577 0-.132.021-.256.06-.367.042-.112.097-.242.221-.425.154-.226.307-.45.428-.651.192-.232.425-.545.639-.926.214-.381.345-.77.345-1.228C12 3.19 10.363 1.5 8 1.5ZM5.75 14.5a.75.75 0 0 1 0-1.5h4.5a.75.75 0 0 1 0 1.5Z',
    IMPORTANT: 'M0 1.75C0 .784.784 0 1.75 0h12.5C15.216 0 16 .784 16 1.75v9.5A1.75 1.75 0 0 1 14.25 13H8.06l-2.573 2.573A1.458 1.458 0 0 1 3 14.543V13H1.75A1.75 1.75 0 0 1 0 11.25ZM1.75 1.5a.25.25 0 0 0-.25.25v9.5c0 .138.112.25.25.25h2a.75.75 0 0 1 .75.75v2.19l2.72-2.72a.749.749 0 0 1 .53-.22h6.5a.25.25 0 0 0 .25-.25v-9.5a.25.25 0 0 0-.25-.25Zm7 2.25v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 9a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z',
    WARNING: 'M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15H1.918a1.75 1.75 0 0 1-1.543-2.575Zm1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164a.25.25 0 0 0 .22-.368Zm.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z',
    CAUTION: 'M4.47.22A.749.749 0 0 1 5 0h6c.199 0 .389.079.53.22l4.25 4.25c.141.14.22.331.22.53v6a.749.749 0 0 1-.22.53l-4.25 4.25A.749.749 0 0 1 11 16H5a.749.749 0 0 1-.53-.22L.22 11.53A.749.749 0 0 1 0 11V5c0-.199.079-.389.22-.53Zm.84 1.28L1.5 5.31v5.38l3.81 3.81h5.38l3.81-3.81V5.31L10.69 1.5ZM8 4a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5A.75.75 0 0 1 8 4Zm0 8a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z'
  };

  function kindFrom(marker) {
    var kind = marker.toUpperCase();
    return kind === 'WARN' ? 'WARNING' : kind;
  }

  function icon(kind) {
    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 16 16');
    svg.setAttribute('width', '16');
    svg.setAttribute('height', '16');
    svg.setAttribute('aria-hidden', 'true');
    var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', ICONS[kind]);
    svg.appendChild(path);
    return svg;
  }

  function stripMarker(el) {
    var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    var textNode = walker.nextNode();
    if (textNode) {
      textNode.textContent = textNode.textContent.replace(MARKER, '');
    }
    if (!(el.textContent || '').trim()) {
      el.remove();
    }
  }

  function enhance(quote) {
    var first = quote.firstElementChild;
    if (!first) return;
    var match = (first.textContent || '').match(MARKER);
    if (!match) return;

    var kind = kindFrom(match[1]);
    stripMarker(first);

    var box = document.createElement('div');
    box.className = 'markdown-alert markdown-alert-' + kind.toLowerCase();
    box.setAttribute('role', 'note');

    var title = document.createElement('p');
    title.className = 'markdown-alert-title';
    title.appendChild(icon(kind));
    title.appendChild(document.createTextNode(TITLES[kind]));
    box.appendChild(title);

    while (quote.firstChild) {
      box.appendChild(quote.firstChild);
    }
    quote.replaceWith(box);
  }

  function run() {
    var quotes = document.querySelectorAll('.main-content blockquote, article blockquote, blockquote');
    Array.prototype.forEach.call(quotes, enhance);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
})();
