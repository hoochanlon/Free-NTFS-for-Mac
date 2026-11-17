#!/usr/bin/env python3
"""本地 Pages 预览：每次请求从当前 README*.md 渲染，不读线上快照。

启动（仓库根目录）：

    python3 -m pip install --user markdown
    python3 _preview_server.py

浏览器打开：

    http://127.0.0.1:4173/_preview.html      中文 README.md
    http://127.0.0.1:4173/README.en.html     英文
    http://127.0.0.1:4173/README.ja.html     日文

改 Markdown 后页面会自动刷新。停掉：终端 Ctrl+C。
端口被占用时：lsof -nP -iTCP:4173 -sTCP:LISTEN
"""
from __future__ import annotations

import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import markdown
from markdown.extensions.toc import slugify_unicode

ROOT = Path(__file__).resolve().parent
PORT = 4173
WATCHED = (
    ROOT / "README.md",
    ROOT / "README.en.md",
    ROOT / "README.ja.md",
    ROOT / "_preview_server.py",
    ROOT / "assets" / "css" / "github-alerts.css",
    ROOT / "assets" / "css" / "theme.css",
    ROOT / "assets" / "js" / "github-alerts.js",
    ROOT / "assets" / "js" / "theme.js",
)

PAGES = {
    "/": "README.md",
    "/index.html": "README.md",
    "/_preview.html": "README.md",
    "/README.html": "README.md",
    "/README.md": "README.md",
    "/README.en.html": "README.en.md",
    "/README.en.md": "README.en.md",
    "/README.ja.html": "README.ja.md",
    "/README.ja.md": "README.ja.md",
}

LINK_REWRITES = (
    ('href="README.md"', 'href="/_preview.html"'),
    ("href='README.md'", 'href="/_preview.html"'),
    ('href="README.en.md"', 'href="/README.en.html"'),
    ("href='README.en.md'", 'href="/README.en.html"'),
    ('href="README.ja.md"', 'href="/README.ja.html"'),
    ("href='README.ja.md'", 'href="/README.ja.html"'),
)

FENCE_RE = re.compile(r"^\s*(```|~~~)")
ALERT_RE = re.compile(r"^>\s*\[!\w+\]")
LIST_RE = re.compile(r"^((?:> ?)*)([ \t]*)([*+-]|\d+\.)([ \t].*)$")
PRE_RE = re.compile(r"<pre>.*?</pre>", re.S)

TEMPLATE = """<!DOCTYPE html>
<html lang="en-US">
  <head>
    <meta charset="UTF-8">
    <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Nigate(Free-NTFS-for-Mac)</title>
    <script>
      (function () {
        try {
          var saved = localStorage.getItem('nigate-theme');
          var dark = saved ? saved === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches;
          document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
        } catch (e) {}
      })();
    </script>
    <link rel="stylesheet" href="https://hoochanlon.github.io/Free-NTFS-for-Mac/assets/css/style.css">
    <link rel="stylesheet" href="/assets/css/github-alerts.css?__QS__">
    <link rel="stylesheet" href="/assets/css/theme.css?__QS__">
    <script src="/assets/js/github-alerts.js?__QS__" defer></script>
    <script src="/assets/js/theme.js?__QS__" defer></script>
  </head>
  <body>
    <div class="container-lg px-3 my-5 markdown-body main-content">
      __CONTENT__
      <div class="footer border-top border-gray-light mt-5 pt-3 text-right text-gray">
        Local preview of <code>__SOURCE__</code>. Auto-reloads when Markdown changes.
      </div>
    </div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/anchor-js/4.1.0/anchor.min.js" crossorigin="anonymous"></script>
    <script>anchors.add();</script>
    <script>
      (function () {
        var stamp = "__STAMP__";
        function check() {
          fetch("/_preview_stamp", { cache: "no-store" })
            .then(function (r) { return r.text(); })
            .then(function (next) { if (next && next !== stamp) location.reload(); })
            .catch(function () {});
        }
        setInterval(check, 800);
        window.addEventListener("pageshow", check);
      })();
    </script>
  </body>
</html>
"""


def source_stamp() -> str:
    parts = []
    for path in WATCHED:
        try:
            parts.append(f"{path.name}:{path.stat().st_mtime_ns}")
        except OSError:
            parts.append(f"{path.name}:missing")
    return "|".join(parts)


def expand_gfm_lists(text: str) -> str:
    """GitHub/kramdown 用 2 空格嵌套；python-markdown 要 4 空格。"""
    in_fence = False
    out: list[str] = []
    for line in text.splitlines():
        if FENCE_RE.match(line):
            in_fence = not in_fence
            out.append(line)
            continue
        if in_fence:
            out.append(line)
            continue
        found = LIST_RE.match(line)
        if found:
            quote, indent, marker, rest = found.groups()
            spaces = len(indent.replace("\t", "    "))
            level = (spaces + 1) // 2
            line = f"{quote}{'    ' * level}{marker}{rest}"
        out.append(line)
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")


def isolate_alerts(text: str) -> str:
    """相邻 callout 会被 python-markdown 合成一块引用；插入注释切断。"""
    return re.sub(r"\n{2,}(>\s*\[!\w+\])", r"\n\n<!-- -->\n\n\1", text)


def preprocess_alerts(text: str) -> str:
    """python-markdown 需要空的 > 行，才能把 callout 标题和列表拆开。"""
    lines = text.splitlines()
    out: list[str] = []
    in_alert = False
    for line in lines:
        if ALERT_RE.match(line):
            in_alert = True
            out.append(line)
            continue
        if in_alert:
            if not line.startswith(">"):
                in_alert = False
                out.append(line)
                continue
            body = line[1:].lstrip()
            is_list = body.startswith(("* ", "- ", "+ ")) or re.match(r"\d+\.\s", body)
            prev = out[-1] if out else ""
            prev_list = bool(re.match(r"^>\s*([*+-]|\d+\.)\s", prev))
            if is_list and prev not in {">", "> "} and not prev_list:
                out.append(">")
            out.append(line)
            continue
        out.append(line)
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")


def wrap_fences(html: str) -> str:
    def repl(match: re.Match[str]) -> str:
        block = match.group(0)
        found = re.search(r'class="language-([^"]+)"', block)
        lang = found.group(1) if found else "text"
        return (
            f'<div class="language-{lang} highlighter-rouge">'
            f'<div class="highlight">{block}</div></div>'
        )

    return PRE_RE.sub(repl, html)


def render(source: str) -> bytes:
    raw = (ROOT / source).read_text(encoding="utf-8")
    text = preprocess_alerts(expand_gfm_lists(isolate_alerts(raw)))
    html = markdown.markdown(
        text,
        extensions=["extra", "sane_lists", "toc"],
        extension_configs={"toc": {"permalink": False, "slugify": slugify_unicode}},
    )
    html = wrap_fences(html)
    for old, new in LINK_REWRITES:
        html = html.replace(old, new)
    stamp = source_stamp()
    page = (
        TEMPLATE.replace("__CONTENT__", html)
        .replace("__SOURCE__", source)
        .replace("__STAMP__", stamp)
        .replace("__QS__", stamp.replace("|", "_"))
    )
    return page.encode("utf-8")


def send_bytes(handler: SimpleHTTPRequestHandler, body: bytes, content_type: str) -> None:
    handler.send_response(200)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
    handler.send_header("Pragma", "no-cache")
    handler.send_header("Expires", "0")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        print(fmt % args, flush=True)

    def _dynamic(self):
        path = self.path.split("?", 1)[0]
        if path == "/_preview_stamp":
            body = source_stamp().encode("utf-8")
            send_bytes(self, body, "text/plain; charset=utf-8")
            return body
        source = PAGES.get(path)
        if source is None:
            return None
        body = render(source)
        send_bytes(self, body, "text/html; charset=utf-8")
        return body

    def do_HEAD(self):
        if self._dynamic() is None:
            return super().do_HEAD()

    def do_GET(self):
        body = self._dynamic()
        if body is None:
            return super().do_GET()
        self.wfile.write(body)

    def end_headers(self):
        path = self.path.split("?", 1)[0]
        if path not in PAGES and path != "/_preview_stamp":
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        super().end_headers()


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"preview http://127.0.0.1:{PORT}/_preview.html", flush=True)
    server.serve_forever()
