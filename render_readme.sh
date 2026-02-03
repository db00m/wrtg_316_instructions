#!/usr/bin/env bash
set -euo pipefail

# Renders README.md to HTML and injects it into template.html in place of {{context}}.
# Usage: ./render_readme.sh [output.html]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README="$ROOT/README.md"
TEMPLATE="$ROOT/template.html"
OUTPUT="${1:-readme.html}"
TMP_BODY="$(mktemp)"

cleanup() { rm -f "$TMP_BODY"; }
trap cleanup EXIT

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

require_file "$README"
require_file "$TEMPLATE"

render_with_pandoc() {
  pandoc --from=gfm --to=html5 "$README" -o "$TMP_BODY"
}

render_with_python_markdown() {
  python3 - <<'PY' "$README" "$TMP_BODY"
import sys
from pathlib import Path
try:
    import markdown
except ImportError:
    sys.exit(1)

source, dest = sys.argv[1], sys.argv[2]
text = Path(source).read_text(encoding="utf-8")
html = markdown.markdown(
    text,
    extensions=["extra", "toc", "fenced_code", "codehilite", "tables", "sane_lists"],
    output_format="html5",
)
Path(dest).write_text(html, encoding="utf-8")
PY
}

render_with_marked() {
  npx --yes marked -i "$README" -o "$TMP_BODY" >/dev/null
}

if command -v pandoc >/dev/null 2>&1; then
  render_with_pandoc
elif render_with_python_markdown; then
  :
elif command -v npx >/dev/null 2>&1; then
  render_with_marked
else
  echo "No renderer found. Install pandoc, python-markdown, or Node's marked." >&2
  exit 1
fi

python3 - <<'PY' "$TEMPLATE" "$TMP_BODY" "$OUTPUT"
import sys
from pathlib import Path

template_path, body_path, output_path = sys.argv[1:]
template = Path(template_path).read_text(encoding="utf-8")
body = Path(body_path).read_text(encoding="utf-8")

placeholder = "{{context}}"
if placeholder not in template:
    raise SystemExit("Placeholder {{context}} not found in template.")

Path(output_path).write_text(template.replace(placeholder, body), encoding="utf-8")
print(f"Wrote {output_path}")
PY
