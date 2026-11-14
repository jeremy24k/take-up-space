"""Convert between Twine 2 story files (Harlowe HTML) and Twee 3 text.

The writing workflow keeps each draft as a .twee file (plain text, easy to
diff and review) and builds a Twine HTML from it that opens in the Twine 2
desktop app and also plays in a browser.

    python narrative/tools/twine_tool.py to-twee "Escena Lia.html" lia.twee
    python narrative/tools/twine_tool.py build draft.twee "Borrador X.html"

The built HTML reuses the Harlowe engine from TEMPLATE (one of the user's own
published stories), so it matches their Twine setup (Harlowe 3.3.9).
"""

# =========================
# Setup
# =========================
import html
import json
import re
import sys
import uuid
from collections import deque
from pathlib import Path

TWINE_STORIES = Path.home() / "Documents" / "Twine" / "Stories"
TEMPLATE = TWINE_STORIES / "Escena Lia.html"
LINK = re.compile(r"\[\[(.+?)\]\]")
# Layout used when a passage has no position: one row per link depth.
GRID_X, GRID_Y, ORIGIN = 225, 200, (500, 100)


# =========================
# HTML -> Twee
# =========================
def _attrs(tag_body: str) -> dict:
    return {k: html.unescape(v) for k, v in re.findall(r'([\w-]+)="([^"]*)"', tag_body)}


def read_html(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    story = _attrs(re.search(r"<tw-storydata([^>]*)>", text).group(1))
    css = re.search(r'<style role="stylesheet"[^>]*>(.*?)</style>', text, re.S)
    js = re.search(r'<script role="script"[^>]*>(.*?)</script>', text, re.S)
    passages = []
    for m in re.finditer(r"<tw-passagedata([^>]*)>(.*?)</tw-passagedata>", text, re.S):
        a = _attrs(m.group(1))
        passages.append({
            "pid": a.get("pid"),
            "name": a["name"],
            "tags": a.get("tags", "").split(),
            "position": a.get("position"),
            "size": a.get("size", "100,100"),
            "text": html.unescape(m.group(2)),
        })
    start = next((p["name"] for p in passages if p["pid"] == story.get("startnode")), passages[0]["name"])
    return {
        "name": story.get("name", path.stem),
        "ifid": story.get("ifid"),
        "format": story.get("format", "Harlowe"),
        "format-version": story.get("format-version", "3.3.9"),
        "start": start,
        "css": html.unescape(css.group(1)) if css else "",
        "js": html.unescape(js.group(1)) if js else "",
        "passages": passages,
    }


def write_twee(story: dict, path: Path) -> None:
    data = {
        "ifid": story["ifid"],
        "format": story["format"],
        "format-version": story["format-version"],
        "start": story["start"],
    }
    out = [":: StoryTitle", story["name"], "", ":: StoryData", json.dumps(data, indent=2, ensure_ascii=False), ""]
    for p in story["passages"]:
        meta = {"position": p["position"], "size": p["size"]} if p["position"] else {}
        tags = f" [{' '.join(p['tags'])}]" if p["tags"] else ""
        head = f":: {p['name']}{tags}" + (f" {json.dumps(meta)}" if meta else "")
        out += [head, p["text"].rstrip("\n"), ""]
    path.write_text("\n".join(out), encoding="utf-8")


# =========================
# Twee -> HTML
# =========================
def read_twee(path: Path) -> dict:
    story = {"name": path.stem, "ifid": None, "format": "Harlowe", "format-version": "3.3.9",
             "start": None, "css": "", "js": "", "passages": []}
    chunks = re.split(r"^:: ", path.read_text(encoding="utf-8"), flags=re.M)[1:]
    for chunk in chunks:
        header, _, body = chunk.partition("\n")
        m = re.match(r"(.+?)(?:\s+\[([^\]]*)\])?(?:\s+(\{.*\}))?\s*$", header)
        name, tags, meta = m.group(1).strip(), (m.group(2) or "").split(), json.loads(m.group(3) or "{}")
        body = body.strip("\n")
        if name == "StoryTitle":
            story["name"] = body.strip()
        elif name == "StoryData":
            data = json.loads(body)
            story.update({k: data[k] for k in ("ifid", "format", "format-version", "start") if k in data})
        elif "stylesheet" in tags:
            story["css"] += body
        elif "script" in tags:
            story["js"] += body
        else:
            story["passages"].append({"name": name, "tags": tags, "position": meta.get("position"),
                                      "size": meta.get("size", "100,100"), "text": body})
    if not story["ifid"]:
        story["ifid"] = str(uuid.uuid4()).upper()
    if not story["start"]:
        story["start"] = story["passages"][0]["name"]
    _auto_layout(story)
    return story


def _targets(text: str) -> list:
    out = []
    for link in LINK.findall(text):
        target = link.split("|")[-1] if "|" in link else link.split("->")[-1]
        out.append(target.split("<-")[0].strip())
    return out


def _auto_layout(story: dict) -> None:
    """Gives every passage without a position a spot: rows by link depth."""
    by_name = {p["name"]: p for p in story["passages"]}
    depth, queue = {story["start"]: 0}, deque([story["start"]])
    while queue:
        name = queue.popleft()
        for t in _targets(by_name[name]["text"]) if name in by_name else []:
            if t in by_name and t not in depth:
                depth[t] = depth[name] + 1
                queue.append(t)
    rows: dict = {}
    for p in story["passages"]:
        rows.setdefault(depth.get(p["name"], max(depth.values(), default=0) + 1), []).append(p)
    for d, row in rows.items():
        for i, p in enumerate(row):
            if not p["position"]:
                x = ORIGIN[0] + (i - (len(row) - 1) / 2) * GRID_X
                p["position"] = f"{int(x)},{ORIGIN[1] + d * GRID_Y}"


def harlowe_safe(text: str) -> str:
    """Harlowe reads `_name` as a temp variable, even inside a word
    (plaza_lia_meet), and prints an error. Identifiers with underscores are
    shown verbatim (backticks); bare [[Passage_Name]] links get a readable
    label (Passage Name->Passage_Name)."""
    def link(m: re.Match) -> str:
        body = m.group(1)
        if "|" in body:
            label, target = body.rsplit("|", 1)
            return f"[[{label.replace('_', ' ')}|{target}]]"
        if "->" in body or "<-" in body:
            return m.group(0)
        return f"[[{body.replace('_', ' ')}->{body}]]" if "_" in body else m.group(0)
    parts = re.split(r"(\[\[.+?\]\]|`[^`]*`)", text)
    for i, part in enumerate(parts):
        if part.startswith("[["):
            parts[i] = LINK.sub(link, part)
        elif not part.startswith("`"):
            parts[i] = re.sub(r"(?<![\w`])(\w*_\w+)", r"`\1`", part)
    return "".join(parts)


def write_html(story: dict, path: Path) -> None:
    template = TEMPLATE.read_text(encoding="utf-8")
    i, j = template.index("<tw-storydata"), template.index("</tw-storydata>") + len("</tw-storydata>")
    esc = lambda s: html.escape(s, quote=True)
    names = [p["name"] for p in story["passages"]]
    start_pid = names.index(story["start"]) + 1
    parts = [
        f'<tw-storydata name="{esc(story["name"])}" startnode="{start_pid}" creator="Twine" '
        f'creator-version="2.11.1" format="{esc(story["format"])}" format-version="{esc(story["format-version"])}" '
        f'ifid="{story["ifid"]}" options="" tags="" zoom="1" hidden>',
        f'<style role="stylesheet" id="twine-user-stylesheet" type="text/twine-css">{esc(story["css"])}</style>',
        f'<script role="script" id="twine-user-script" type="text/twine-javascript">{esc(story["js"])}</script>',
    ]
    harlowe = story["format"].lower() == "harlowe"
    for pid, p in enumerate(story["passages"], start=1):
        text = harlowe_safe(p["text"]) if harlowe else p["text"]
        parts.append(
            f'<tw-passagedata pid="{pid}" name="{esc(p["name"])}" tags="{esc(" ".join(p["tags"]))}" '
            f'position="{p["position"]}" size="{p["size"]}">{esc(text)}</tw-passagedata>')
    parts.append("</tw-storydata>")
    out = template[:i] + "".join(parts) + template[j:]
    out = re.sub(r"<title>.*?</title>", f"<title>{esc(story['name'])}</title>", out, count=1, flags=re.S)
    path.write_text(out, encoding="utf-8")


def check_links(story: dict) -> list:
    names = {p["name"] for p in story["passages"]}
    return [(p["name"], t) for p in story["passages"] for t in _targets(p["text"]) if t not in names]


# =========================
# Command line
# =========================
if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    cmd, src, dst = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    if cmd == "to-twee":
        write_twee(read_html(src), dst)
    elif cmd == "build":
        story = read_twee(src)
        write_html(story, dst)
        for passage, target in check_links(story):
            print(f"WARNING: '{passage}' links to missing passage '{target}'")
        print(f"{dst} ({len(story['passages'])} passages, start: {story['start']})")
    else:
        sys.exit(f"unknown command {cmd}")
