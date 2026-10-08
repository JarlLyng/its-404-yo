"""Vendor this site's pieces of iamjarl-design at one pinned tag.

Run:  make design                 (or: python3 scripts/vendor_design.py v1.17.0)

From the design repo at DESIGN_TAG:

  * dist/components/ij-footer.js      -> site/assets/ij-footer.js
  * dist/footers/its-404-yo.html      -> inlined between the cross-links markers in every page
  * dist/identity/its-404-yo.css      -> site/assets/design/identity.css   (--ij-font-display)
  * dist/fonts/jetbrains-mono.css     -> site/assets/design/jetbrains-mono.css (src rewritten local)
  * fonts/jetbrains-mono-*.woff2      -> site/assets/design/  (+ its OFL licence, required with it)

Why vendored instead of loaded from jsDelivr as the design README shows: the site's privacy page
names Umami as its only third party, and a CDN request would be a second, undisclosed one.

Integrity is still checked, at build time, and nothing is written unless every check passes:
  * files listed in the tag's dist/sri.json must match their sha384;
  * the woff2 is not in sri.json, so it is cross-checked against the npm package the font CSS
    names in its header (@fontsource-variable/...@x.y.z). Two independent sources must agree.

Why the cross-links are inlined rather than left to the component: crawlers that do not run
JavaScript (GPTBot, ClaudeBot, CCBot, PerplexityBot) only see links that are in the HTML. The
component slots inlined links instead of generating its own. The fragment is a snapshot, so
re-run this when the registry changes; its header comment names the version it came from.
"""
import base64, hashlib, json, re, sys, urllib.request
from pathlib import Path

APP = "its-404-yo"
FONT = "jetbrains-mono"
ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
DEST = SITE / "assets" / "design"
START = "<!-- ij-footer:cross-links -->"
END = "<!-- /ij-footer:cross-links -->"

def get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read()

def repo(tag, path):
    return get(f"https://raw.githubusercontent.com/JarlLyng/iamjarl-design/{tag}/{path}")

def sha384(b):
    return "sha384-" + base64.b64encode(hashlib.sha384(b).digest()).decode()

def verified(tag, sri, path):
    data = repo(tag, path)
    want, got = sri["files"].get(path), sha384(data)
    if want != got:
        sys.exit(f"integrity mismatch for {path} at {tag}\n  sri.json {want}\n  download {got}")
    return data

def main(tag):
    sri = json.loads(repo(tag, "dist/sri.json"))
    if sri.get("version") != tag.lstrip("v"):
        sys.exit(f"sri.json says {sri.get('version')}, expected {tag}")

    footer_js = verified(tag, sri, "dist/components/ij-footer.js")
    identity = verified(tag, sri, f"dist/identity/{APP}.css")
    font_css = verified(tag, sri, f"dist/fonts/{FONT}.css").decode()
    fragment = repo(tag, f"dist/footers/{APP}.html").decode().strip()

    # The woff2 the font CSS points at, and the npm package it says the file came from.
    rel = re.search(r"url\('\.\./\.\./fonts/([^']+\.woff2)'\)", font_css).group(1)
    npm = re.search(r"from (@fontsource-variable/[a-z0-9-]+@\d+(?:\.\d+)*)", font_css).group(1)
    woff2 = repo(tag, f"fonts/{rel}")
    upstream = get(f"https://cdn.jsdelivr.net/npm/{npm}/files/{rel}")
    if sha384(woff2) != sha384(upstream):
        sys.exit(f"{rel} at {tag} does not match {npm}; refusing to vendor it")
    licence = repo(tag, f"fonts/LICENSE-{FONT}.txt")

    # All checks passed: write.
    (SITE / "assets" / "ij-footer.js").write_bytes(footer_js)
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "identity.css").write_bytes(identity)
    (DEST / f"{FONT}.css").write_text(
        font_css.replace(f"url('../../fonts/{rel}')", f"url('{rel}')"), encoding="utf-8")
    (DEST / rel).write_bytes(woff2)
    (DEST / f"LICENSE-{FONT}.txt").write_bytes(licence)

    pages = sorted(SITE.glob("*.html"))
    block = re.compile(re.escape(START) + r".*?" + re.escape(END), re.S)
    missing = []
    for page in pages:
        html = page.read_text(encoding="utf-8")
        if START not in html:
            missing.append(page.name)
            continue
        indent = re.search(r"^([ \t]*)" + re.escape(START), html, re.M).group(1)
        body = "\n".join(indent + line for line in fragment.splitlines())
        html = block.sub(lambda _: f"{START}\n{body}\n{indent}{END}", html, count=1)
        page.write_text(html, encoding="utf-8")
    if missing:
        sys.exit(f"no cross-links markers in: {', '.join(missing)}")

    print(f"{tag}: ij-footer.js, identity.css, {FONT}.css verified against sri.json")
    print(f"{rel} matches {npm} ({sha384(woff2)[:20]}...), vendored with its licence")
    print(f"cross-links inlined into {len(pages)} pages")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "v1.17.0")
