#!/usr/bin/env bash
# ocr-scan: like a screenshot tool, but it copies the text instead.
# Drag a box over text on screen -> the text lands in your clipboard.
#
#   ocr-scan [-l LANG] [-v]
#
#   -l ja    Japanese (default)
#   -l ko    Korean
#   -l zh    Chinese, simplified
#   -l zht   Chinese, traditional
#   -v       vertical text (manga, novels)
#   -h       show usage
set -euo pipefail

usage() {
  echo "usage: ocr-scan [-l ja|ko|zh|zht] [-v]" >&2
  exit "${1:-2}"
}

code="ja"
vertical=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--lang) code="${2:-}"; shift 2 || usage ;;
    -v|--vertical) vertical=1; shift ;;
    -h|--help) usage 0 ;;
    *) usage ;;
  esac
done

# Short-lived notification. Some notification daemons ignore the timeout and
# keep the popup forever, so also close it ourselves after a moment.
toast() {
  local id
  id="$(notify-send -a ocr-scan -t 2500 -p -h boolean:transient:true "$1" "$2")" || return 0
  [[ "$id" =~ ^[0-9]+$ ]] || return 0
  (
    sleep 3
    gdbus call --session --dest org.freedesktop.Notifications \
      --object-path /org/freedesktop/Notifications \
      --method org.freedesktop.Notifications.CloseNotification "$id" \
      >/dev/null 2>&1 || true
  ) >/dev/null 2>&1 &
}

case "$code" in
  ja)  base="jpn";     label="日本語" ;;
  ko)  base="kor";     label="한국어" ;;
  zh)  base="chi_sim"; label="中文 (简体)" ;;
  zht) base="chi_tra"; label="中文 (繁體)" ;;
  *) usage ;;
esac

if [[ "$vertical" -eq 1 ]]; then
  lang="${base}_vert"
  psm=5
else
  lang="$base"
  psm=6
fi

# Region picker, Catppuccin Mocha: gently dimmed screen, mauve (purple)
# outline, faint mauve fill, no size readout. Pressing Esc cancels quietly.
region="$(slurp -w 2 -b '#11111b59' -c '#cba6f7' -s '#cba6f726')" || exit 0

# Keep the screenshot in a private temp dir (tmpfs on most systems) and always
# delete it afterwards, so nothing you scan is left on disk.
tmp="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/ocr-scan.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

if ! grim -g "$region" "$tmp/shot.png"; then
  toast "Screenshot failed" "$label"
  exit 1
fi

# ocr-best tries several cleaned-up versions of the image and keeps the
# reading tesseract is most confident about (see ocr-best.py). It also tidies
# the text (trailing spaces, stray gaps between CJK characters, blank lines).
if ! text="$(ocr-best "$tmp/shot.png" "$lang" "$psm" 2>"$tmp/err")"; then
  toast "OCR failed" "$(head -c 200 "$tmp/err")"
  exit 1
fi

if [[ -z "${text//[[:space:]]/}" ]]; then
  toast "No text found" "$label"
  exit 0
fi

printf '%s' "$text" | wl-copy

preview="${text:0:120}"
toast "Copied · $label" "${preview//$'\n'/ }"
