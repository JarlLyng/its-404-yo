"""Vendor the shared <ij-footer> from iamjarl-design into the site.

Run:  make footer                 (or: python3 scripts/vendor_footer.py v1.13.0)

Two things come from the design repo at a pinned tag:

  * dist/components/ij-footer.js  -> site/assets/ij-footer.js
  * dist/footers/its-404-yo.html  -> inlined between the cross-links markers in every page

Why vendored instead of loading the component from jsDelivr as the design README shows: the
site's privacy page names Umami as its only third party, and a CDN script would be a second,
undisclosed one. Vendoring keeps that promise true. The integrity check still happens, just at
build time: the downloaded file's sha384 must match the tag's dist/sri.json or nothing is written.

Why the cross-links are inlined rather than left to the component: crawlers that do not run
JavaScript (GPTBot, ClaudeBot, CCBot, PerplexityBot) only see links that are in the HTML. The
component slots inlined links instead of generating its own. The fragment is a snapshot, so
re-run this when the registry changes; its header comment names the version it came from.
"""
import base64, hashlib, re, sys, urllib.request
from pathlib import Path

APP = "its-404-yo"
ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
START = "<!-- ij-footer:cross-links -->"
END = "<!-- /ij-footer:cross-links -->"

def fetch(tag, path):
    url = f"https://raw.githubusercontent.com/JarlLyng/iamjarl-design/{tag}/{path}"
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read()

def main(tag):
    import json
    sri = json.loads(fetch(tag, "dist/sri.json"))
    js = fetch(tag, "dist/components/ij-footer.js")
    want = sri["files"]["dist/components/ij-footer.js"]
    got = "sha384-" + base64.b64encode(hashlib.sha384(js).digest()).decode()
    if got != want:
        sys.exit(f"integrity mismatch for ij-footer.js at {tag}\n  sri.json {want}\n  download {got}")
    fragment = fetch(tag, f"dist/footers/{APP}.html").decode().strip()

    (SITE / "assets" / "ij-footer.js").write_bytes(js)
    pages = sorted(SITE.glob("*.html"))
    block = re.compile(re.escape(START) + r".*?" + re.escape(END), re.S)
    missing = []
    for page in pages:
        html = page.read_text(encoding="utf-8")
        if START not in html:
            missing.append(page.name)
            continue
        # keep the indentation of the start marker for every inlined line
        indent = re.search(r"^([ \t]*)" + re.escape(START), html, re.M).group(1)
        body = "\n".join(indent + line for line in fragment.splitlines())
        html = block.sub(lambda _: f"{START}\n{body}\n{indent}{END}", html, count=1)
        page.write_text(html, encoding="utf-8")
    if missing:
        sys.exit(f"no cross-links markers in: {', '.join(missing)}")
    print(f"ij-footer.js {tag} verified ({want[:19]}...) and vendored")
    print(f"cross-links inlined into {len(pages)} pages")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "v1.13.0")
