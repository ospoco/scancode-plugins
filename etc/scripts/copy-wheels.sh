#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: copy-wheels.sh --target <dir> [options]

Options:
  --target <dir>        Destination directory.
  --layout <name>       Output layout: "flat" (default) or "repo".
                        flat: write wheels/index directly to <dir>
                        repo: write wheels/index to <dir>/dist
  --base-url <url>      Optional absolute base URL for index links.
  --all                 Copy every discovered wheel (skip package/platform filter).
  --no-index            Do not generate index.html
  --help                Show this help.
EOF
  exit 2
}

TARGET=""
LAYOUT="flat"
BASE_URL=""
COPY_ALL=0
GENERATE_INDEX=1

# ModelMonster wheel set and platform matrix.
PACKAGE_REGEX='^(extractcode_7z|extractcode_libarchive|typecode_libmagic|textcode_pdf2text|scancode_ctags|scancode_dwarfdump|scancode_readelf)-'
PLATFORM_REGEX='(manylinux2014_x86_64|manylinux2014_aarch64|macosx_15_0_arm64)\.whl$'

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      TARGET=${2:-}
      shift 2
      ;;
    --layout)
      LAYOUT=${2:-}
      shift 2
      ;;
    --base-url)
      BASE_URL=${2:-}
      shift 2
      ;;
    --all)
      COPY_ALL=1
      shift
      ;;
    --no-index)
      GENERATE_INDEX=0
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  usage
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"
root_dist_dir="$repo_root/dist"

if [ "$LAYOUT" != "flat" ] && [ "$LAYOUT" != "repo" ]; then
  echo "ERROR: unsupported --layout value: $LAYOUT" >&2
  exit 1
fi

if [ "$LAYOUT" = "repo" ]; then
  out_dir="$TARGET/dist"
else
  out_dir="$TARGET"
fi

if [ ! -d "$root_dist_dir" ]; then
  echo "ERROR: dist directory not found: $root_dist_dir" >&2
  exit 1
fi

mkdir -p "$out_dir"
find "$out_dir" -maxdepth 1 -type f \( -name '*.whl' -o -name 'index.html' \) -delete

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

{
  find "$root_dist_dir" -maxdepth 1 -type f -name '*.whl'
  find "$repo_root/builtins" "$repo_root/binary-analysis" "$repo_root/misc" \
    -type f -path '*/dist/*.whl' 2>/dev/null || true
} > "$tmp_list"

if [ ! -s "$tmp_list" ]; then
  echo "ERROR: no wheel files found under $repo_root" >&2
  exit 1
fi

copied=0
while IFS= read -r wheel; do
  name="$(basename "$wheel")"
  if [ "$COPY_ALL" -ne 1 ]; then
    if ! [[ "$name" =~ $PACKAGE_REGEX ]]; then
      continue
    fi
    if ! [[ "$name" =~ $PLATFORM_REGEX ]]; then
      continue
    fi
  fi
  if [ -f "$out_dir/$name" ]; then
    continue
  fi
  cp -f "$wheel" "$out_dir/$name"
  copied=$((copied + 1))
done < "$tmp_list"

if [ "$copied" -eq 0 ]; then
  echo "ERROR: no wheels matched the selection filter" >&2
  exit 1
fi

if [ "$GENERATE_INDEX" -eq 1 ]; then
  python3 - "$out_dir" "$BASE_URL" <<'PY'
from __future__ import annotations

import html
import urllib.parse
from datetime import datetime
from pathlib import Path
import sys

out_dir = Path(sys.argv[1])
base_url = sys.argv[2].strip()

def format_size(num_bytes: int) -> str:
    if num_bytes < 1024:
        return f"{num_bytes} B"
    if num_bytes < 1024 * 1024:
        return f"{num_bytes / 1024:.1f} KB"
    return f"{num_bytes / (1024 * 1024):.1f} MB"

files = sorted(out_dir.glob("*.whl"), key=lambda p: p.name)
today = datetime.now().strftime("%Y-%m-%d")

if base_url and not base_url.endswith("/"):
    base_url = f"{base_url}/"

rows = []
for path in files:
    stat = path.stat()
    date = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d")
    if base_url:
        href = urllib.parse.urljoin(base_url, urllib.parse.quote(path.name, safe=""))
    else:
        href = urllib.parse.quote(path.name, safe="")
    label = html.escape(path.name, quote=True)
    rows.append(
        "      <tr>\n"
        f"        <td><a href=\"{href}\">{label}</a></td>\n"
        f"        <td>{format_size(stat.st_size)}</td>\n"
        f"        <td>{date}</td>\n"
        "      </tr>"
    )

rows_html = "\n".join(rows) if rows else "      <tr><td colspan=\"3\">No files found</td></tr>"
index = f"""<!DOCTYPE html>
<html>
  <head>
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
    <title>Package Index for ScanCode Plugin Wheels</title>
    <style>
      body {{
        font-family: Arial, sans-serif;
        margin: 20px;
        line-height: 1.5;
      }}
      h1 {{
        color: #333;
        border-bottom: 1px solid #ccc;
        padding-bottom: 10px;
      }}
      table {{
        border-collapse: collapse;
        width: 100%;
        margin: 20px 0;
      }}
      th, td {{
        text-align: left;
        padding: 12px;
        border-bottom: 1px solid #ddd;
      }}
      th {{
        background-color: #f2f2f2;
      }}
      a {{
        color: #0366d6;
        text-decoration: none;
      }}
      a:hover {{
        text-decoration: underline;
      }}
      .footer {{
        margin-top: 30px;
        color: #777;
        font-size: 0.9em;
        text-align: center;
      }}
      code {{
        background: #f6f8fa;
        padding: 2px 6px;
        border-radius: 4px;
      }}
    </style>
  </head>
  <body>
    <h1>ScanCode Plugin Wheels</h1>
    <p>
      Generated by <code>etc/scripts/copy-wheels.sh</code>.
    </p>
    <h2>Available files</h2>
    <table>
      <tr>
        <th>Filename</th>
        <th>Size</th>
        <th>Date</th>
      </tr>
{rows_html}
    </table>
    <div class=\"footer\">
      Last updated: {today}
    </div>
  </body>
</html>
"""

(out_dir / "index.html").write_text(index, encoding="utf-8")
print(f"Wrote {(out_dir / 'index.html')}")
PY
fi

echo "Copied $copied wheel(s) to $out_dir"
