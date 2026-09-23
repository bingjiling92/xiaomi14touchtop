#!/system/bin/sh
MODDIR=${0%/*}
bind_tree() {
  local SRC="$1" DST="$2"
  mkdir -p "$DST"
  for f in "$SRC"/*; do
    [ -e "$f" ] || continue
    local name=$(basename "$f")
    if [ -d "$f" ]; then bind_tree "$f" "$DST/$name"
    else mount --bind "$f" "$DST/$name" 2>/dev/null; fi
  done
}
bind_tree "$MODDIR/Link/odm/firmware" "/odm/firmware"
