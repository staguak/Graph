#!/usr/bin/env bash
set -euo pipefail

# Import six ZIP snapshots from the temporary transfer branch.
# This script does not commit or push extracted content.
SOURCE_REF="origin/staguak-patch-1"
DEST_ROOT="docs/graphrag"
ARCHIVES=(
  "awesome-graph-universe-main.zip"
  "langchain4j-aideepin-main 2.zip"
  "FalkorDB-main.zip"
  "graphrag-main.zip"
  "graph-main.zip"
  "graph-rag-agent-master.zip"
)

git fetch origin
mkdir -p "$DEST_ROOT"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

for ARCHIVE in "${ARCHIVES[@]}"; do
  NAME="${ARCHIVE%.zip}"
  DEST="$DEST_ROOT/$NAME"
  if [[ -e "$DEST" ]]; then
    echo "ERROR: destination already exists, refusing to overwrite: $DEST" >&2
    exit 1
  fi
  echo "Importing $ARCHIVE"
  git show "$SOURCE_REF:$ARCHIVE" > "$WORK_DIR/$ARCHIVE"
  unzip -tq "$WORK_DIR/$ARCHIVE" > /dev/null

  # Reject absolute paths, parent-directory traversal and symbolic links.
  python3 - "$WORK_DIR/$ARCHIVE" <<'PY'
import pathlib, stat, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    for info in z.infolist():
        name = info.filename
        path = pathlib.PurePosixPath(name)
        mode = info.external_attr >> 16
        if (not name or path.is_absolute() or ".." in path.parts
            or "\\" in name or stat.S_ISLNK(mode)):
            sys.exit(f"Unsafe ZIP entry: {name!r}")
PY

  mkdir -p "$DEST"
  unzip -q "$WORK_DIR/$ARCHIVE" -d "$DEST"
done

echo "Imported regular files:"
find "$DEST_ROOT" -type f | wc -l
echo "Total unpacked size:"
du -sh "$DEST_ROOT"
echo "Files larger than 95 MiB (review before committing):"
find "$DEST_ROOT" -type f -size +95M -print
echo "Done. Review source contents, licenses and secrets before git add/commit/push."
