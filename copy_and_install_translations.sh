#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect defaults when running from Koha-translations repo.
if [[ -d "$SCRIPT_DIR/po" ]]; then
  DEFAULT_TRANSLATIONS_PATH="$SCRIPT_DIR"
  DEFAULT_KOHA_PATH="$(cd "$SCRIPT_DIR/../Koha" 2>/dev/null && pwd || echo "")"
else
  DEFAULT_TRANSLATIONS_PATH="$HOME/Koha-translations"
  DEFAULT_KOHA_PATH="$(cd "$SCRIPT_DIR/../../Koha" 2>/dev/null && pwd || echo "")"
fi

KOHA_PATH="${KOHA_PATH:-$DEFAULT_KOHA_PATH}"
TRANSLATIONS_PATH="${TRANSLATIONS_PATH:-$DEFAULT_TRANSLATIONS_PATH}"
LANG_FILTER="${LANG_FILTER:-fi-FI,sv-SE}" # Default languages to install if not specified. Can be overridden with --lang or LANG_FILTER env var.
DRY_RUN=0

usage() {
  cat <<'EOF'
Copy PO files from Koha-translations to Koha and install translations.

Usage:
  copy_and_install_translations.sh [options]

Options:
  -k, --koha-path PATH          Path to Koha repository
  -r, --translations-path PATH  Path to Koha-translations repository
  -l, --lang LANGS              Comma-separated language tags (e.g. fi-FI or fi-FI,sv-SE)
  -n, --dry-run                 Print actions without changing files
  -h, --help                    Show this help

Examples:
  ./copy_and_install_translations.sh
  ./copy_and_install_translations.sh --koha-path /home/koha/Koha
  ./copy_and_install_translations.sh --lang fi-FI,sv-SE
EOF
}

contains_csv_value() {
  local list="$1"
  local value="$2"

  [[ ",$list," == *",$value,"* ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--koha-path)
      KOHA_PATH="$2"
      shift 2
      ;;
    -r|--translations-path)
      TRANSLATIONS_PATH="$2"
      shift 2
      ;;
    -l|--lang)
      LANG_FILTER="$2"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$KOHA_PATH" ]]; then
  echo "Koha path is empty. Use --koha-path or KOHA_PATH env var." >&2
  exit 1
fi

SOURCE_PO_DIR="$TRANSLATIONS_PATH/po"
KOHA_PO_DIR="$KOHA_PATH/misc/translator/po"
TRANSLATOR_DIR="$KOHA_PATH/misc/translator"

if [[ ! -d "$SOURCE_PO_DIR" ]]; then
  echo "Source PO directory not found: $SOURCE_PO_DIR" >&2
  exit 1
fi

if [[ ! -d "$TRANSLATOR_DIR" ]]; then
  echo "Koha translator directory not found: $TRANSLATOR_DIR" >&2
  exit 1
fi

if [[ ! -x "$TRANSLATOR_DIR/translate" ]]; then
  echo "Koha translate script not found or not executable: $TRANSLATOR_DIR/translate" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would create directory $KOHA_PO_DIR"
else
  mkdir -p "$KOHA_PO_DIR"
fi

shopt -s nullglob
copied=0
copy_failed=0
declare -A install_langs=()

for po_file in "$SOURCE_PO_DIR"/*.po; do
  file_name="$(basename "$po_file")"

  language="${file_name%%-*}"

  # Language is expected to be like fi-FI, so rebuild from first two parts.
  if [[ "$file_name" =~ ^([^-]+-[^-]+)-.+\.po$ ]]; then
    language="${BASH_REMATCH[1]}"
  fi

  if [[ -n "$LANG_FILTER" ]] && ! contains_csv_value "$LANG_FILTER" "$language"; then
    continue
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: would copy $file_name -> $KOHA_PO_DIR/"
    copied=$((copied + 1))
    install_langs["$language"]=1
    continue
  fi

  if cp "$po_file" "$KOHA_PO_DIR/"; then
    echo "Copied $file_name"
    copied=$((copied + 1))
    install_langs["$language"]=1
  else
    echo "Failed to copy $file_name" >&2
    copy_failed=$((copy_failed + 1))
  fi
done

if [[ "$copied" -eq 0 ]]; then
  if [[ -n "$LANG_FILTER" ]]; then
    echo "No PO files matched --lang=$LANG_FILTER in $SOURCE_PO_DIR" >&2
  else
    echo "No PO files found in $SOURCE_PO_DIR" >&2
  fi
  exit 1
fi

echo "Copied $copied PO files to $KOHA_PO_DIR"

if [[ "$copy_failed" -gt 0 ]]; then
  echo "Warning: $copy_failed files failed to copy" >&2
fi

echo

echo "Installing translations..."

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ -n "$LANG_FILTER" ]]; then
    IFS=',' read -r -a langs <<< "$LANG_FILTER"
    for lang in "${langs[@]}"; do
      echo "DRY-RUN: would run (cd $TRANSLATOR_DIR && ./translate install $lang)"
    done
  else
    echo "DRY-RUN: would run (cd $TRANSLATOR_DIR && ./translate install)"
  fi
  exit 0
fi

cd "$TRANSLATOR_DIR"

if [[ -n "$LANG_FILTER" ]]; then
  IFS=',' read -r -a langs <<< "$LANG_FILTER"
  for lang in "${langs[@]}"; do
    echo "Installing $lang"
    ./translate install "$lang"
  done
else
  ./translate install
fi

echo "Translation install completed."
