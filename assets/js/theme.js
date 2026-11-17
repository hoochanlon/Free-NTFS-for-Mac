/* 夜间模式：记住选择，图标用 theme-toggles Around，页面用 View Transition 圆形铺开。 */
(function () {
  var KEY = 'nigate-theme';

  function labels() {
    var path = location.pathname || '';
    if (/README\.en/.test(path)) {
      return { toLight: 'Switch to light mode', toDark: 'Switch to dark mode' };
    }
    if (/README\.ja/.test(path)) {
      return { toLight: 'ライトモードに切り替え', toDark: 'ダークモードに切り替え' };
    }
    return { toLight: '切换到日间模式', toDark: '切换到夜间模式' };
  }

  function isDark() {
    return document.documentElement.getAttribute('data-theme') === 'dark';
  }

  function currentTheme() {
    try {
      var saved = localStorage.getItem(KEY);
      if (saved === 'dark' || saved === 'light') return saved;
    } catch (err) {}
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function syncButton(button, theme) {
    var text = labels();
    var dark = theme === 'dark';
    button.classList.toggle('theme-toggle--toggled', dark);
    button.setAttribute('aria-label', dark ? text.toLight : text.toDark);
    button.setAttribute('title', dark ? text.toLight : text.toDark);
  }

  function apply(theme, button) {
    document.documentElement.setAttribute('data-theme', theme);
    try {
      localStorage.setItem(KEY, theme);
    } catch (err) {}
    if (button) syncButton(button, theme);
  }

  function reducedMotion() {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  function toggle(event, button) {
    var next = isDark() ? 'light' : 'dark';
    var paint = function () {
      apply(next, button);
    };

    if (reducedMotion() || typeof document.startViewTransition !== 'function') {
      paint();
      return;
    }

    var x = event.clientX;
    var y = event.clientY;
    if (!x && !y) {
      var box = button.getBoundingClientRect();
      x = box.left + box.width / 2;
      y = box.top + box.height / 2;
    }
    var radius = Math.hypot(
      Math.max(x, innerWidth - x),
      Math.max(y, innerHeight - y)
    );

    var transition = document.startViewTransition(paint);
    transition.ready
      .then(function () {
        document.documentElement.animate(
          {
            clipPath: [
              'circle(0px at ' + x + 'px ' + y + 'px)',
              'circle(' + radius + 'px at ' + x + 'px ' + y + 'px)'
            ]
          },
          {
            duration: 480,
            easing: 'ease-in-out',
            pseudoElement: '::view-transition-new(root)'
          }
        );
      })
      .catch(function () {});
  }

  function mount() {
    if (document.querySelector('.theme-toggle-wrap')) return;

    var wrap = document.createElement('div');
    wrap.className = 'theme-toggle-wrap';

    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'theme-toggle';
    button.innerHTML =
      '<svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" width="1em" height="1em" fill="currentColor" class="theme-toggle__around" viewBox="0 0 32 32">' +
      '<clipPath id="theme-toggle__around__cutout"><path d="M0 0h42v30a1 1 0 00-16 13H0Z"/></clipPath>' +
      '<g clip-path="url(#theme-toggle__around__cutout)">' +
      '<circle cx="16" cy="16" r="8.4"/>' +
      '<g>' +
      '<circle cx="16" cy="3.3" r="2.3"/>' +
      '<circle cx="27" cy="9.7" r="2.3"/>' +
      '<circle cx="27" cy="22.3" r="2.3"/>' +
      '<circle cx="16" cy="28.7" r="2.3"/>' +
      '<circle cx="5" cy="22.3" r="2.3"/>' +
      '<circle cx="5" cy="9.7" r="2.3"/>' +
      '</g></g></svg>';

    apply(currentTheme(), button);
    button.addEventListener('click', function (event) {
      toggle(event, button);
    });

    wrap.appendChild(button);
    document.body.appendChild(wrap);
  }

  apply(currentTheme(), null);

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mount);
  } else {
    mount();
  }
})();
