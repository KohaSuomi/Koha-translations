#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect if script is in translations repo
if [[ -d "$SCRIPT_DIR/po" && -d "$SCRIPT_DIR/pot" ]]; then
  DEFAULT_TRANSLATIONS_PATH="$SCRIPT_DIR"
  DEFAULT_KOHA_PATH="$(cd "$SCRIPT_DIR/../Koha" 2>/dev/null && pwd || echo "")"
else
  # Script is in utility repo
  DEFAULT_KOHA_PATH="$(cd "$SCRIPT_DIR/../../Koha" 2>/dev/null && pwd || echo "")"
  DEFAULT_TRANSLATIONS_PATH="$HOME/Koha-translations"
fi

KOHA_PATH="${KOHA_PATH:-$DEFAULT_KOHA_PATH}"
PO_DIR=""
POT_DIR=""
TRANSLATIONS_PATH="${TRANSLATIONS_PATH:-$DEFAULT_TRANSLATIONS_PATH}"
LANG_FILTER=""
TYPE_FILTER=""
DRY_RUN=0
GENERATE_POT="auto"
COPY_TO_KOHA=0
PUSH_TO_GITHUB=0

TYPES=(
  "marc-MARC21"
  "marc-NORMARC"
  "marc-UNIMARC"
  "staff-help"
  "staff-prog"
  "opac-bootstrap"
  "opac-prog"
  "pref"
  "messages"
  "messages-js"
  "installer"
  "installer-MARC21"
  "installer-UNIMARC"
)

usage() {
  cat <<'EOF'
Update Koha PO files without Node.js.

This helper generates POT files from Koha sources and updates PO files with msgmerge.
It uses the same Perl extraction scripts as gulp but runs them directly.

Usage:
  update_koha_po_without_node.sh [options]

Options:
  -k, --koha-path PATH    Path to Koha repository (default: env KOHA_PATH or auto-detected)
  -r, --translations-path PATH
                          Path to translations repository (default: script directory if it contains po/pot,
                          otherwise env TRANSLATIONS_PATH or ~/Koha-translations)
  -o, --po-dir PATH       Path to .po directory to update (default: <translations-path>/po if exists,
                          otherwise <koha-path>/misc/translator/po)
  -p, --pot-dir PATH      Path to write Koha-<type>.pot files (default: <translations-path>/pot if exists,
                          otherwise <koha-path>/misc/translator)
  -g, --generate-pot MODE How to handle POT generation: auto (default: generate if missing),
                          always (always regenerate), never (skip generation, use existing)
  -l, --lang LANGS        Comma-separated language tags (e.g. fi-FI or fi-FI,sv-SE)
  -t, --type TYPES        Comma-separated PO types (e.g. pref,messages)
  -c, --copy-to-koha      Copy updated PO files to <koha-path>/misc/translator/po/
  -P, --push-to-github    Commit and push updated PO/POT files to GitHub (for test environments)
  -n, --dry-run           Print commands but do not modify files
  -h, --help              Show this help

Examples:
  update_koha_po_without_node.sh
  update_koha_po_without_node.sh --koha-path /home/koha/Koha --lang fi-FI
  update_koha_po_without_node.sh --translations-path /home/koha/Koha-translations --lang fi-FI
  update_koha_po_without_node.sh --generate-pot always --lang fi-FI,sv-SE --type pref,messages
EOF
}

contains_csv_value() {
  local list="$1"
  local value="$2"

  [[ ",$list," == *",$value,"* ]]
}

file_matches_language_filter() {
  local file_name="$1"
  local filter="$2"
  local lang=""

  IFS=',' read -r -a langs <<< "$filter"
  for lang in "${langs[@]}"; do
    if [[ "$file_name" == "$lang-"* ]]; then
      return 0
    fi
  done

  return 1
}

validate_type_filter() {
  local filter="$1"
  local item=""
  IFS=',' read -r -a req_types <<< "$filter"

  for item in "${req_types[@]}"; do
    local ok=0
    local known=""
    for known in "${TYPES[@]}"; do
      if [[ "$item" == "$known" ]]; then
        ok=1
        break
      fi
    done

    if [[ "$ok" -ne 1 ]]; then
      echo "Unknown type in --type: $item" >&2
      echo "Allowed types: ${TYPES[*]}" >&2
      exit 1
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--koha-path)
      KOHA_PATH="$2"
      shift 2
      ;;
    -l|--lang)
      LANG_FILTER="$2"
      shift 2
      ;;
    -r|--translations-path)
      TRANSLATIONS_PATH="$2"
      shift 2
      ;;
    -o|--po-dir)
      PO_DIR="$2"
      shift 2
      ;;
    -p|--pot-dir)
      POT_DIR="$2"
      shift 2
      ;;
    -g|--generate-pot)
      GENERATE_POT="$2"
      shift 2
      ;;
    -t|--type)
      TYPE_FILTER="$2"
      shift 2
      ;;
    -c|--copy-to-koha)
      COPY_TO_KOHA=1
      shift
      ;;
    -P|--push-to-github)
      PUSH_TO_GITHUB=1
      shift
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

if [[ -z "$PO_DIR" ]]; then
  if [[ -d "$TRANSLATIONS_PATH/po" ]]; then
    PO_DIR="$TRANSLATIONS_PATH/po"
  else
    PO_DIR="$KOHA_PATH/misc/translator/po"
  fi
fi

if [[ -z "$POT_DIR" ]]; then
  if [[ -d "$TRANSLATIONS_PATH/pot" ]]; then
    POT_DIR="$TRANSLATIONS_PATH/pot"
  else
    POT_DIR="$KOHA_PATH/misc/translator"
  fi
fi

if [[ ! -d "$PO_DIR" ]]; then
  echo "PO directory not found: $PO_DIR" >&2
  exit 1
fi

if [[ ! -d "$POT_DIR" ]]; then
  echo "POT directory not found: $POT_DIR" >&2
  exit 1
fi

if [[ -n "$TYPE_FILTER" ]]; then
  validate_type_filter "$TYPE_FILTER"
fi

if [[ "$GENERATE_POT" != "auto" && "$GENERATE_POT" != "always" && "$GENERATE_POT" != "never" ]]; then
  echo "Invalid --generate-pot value: $GENERATE_POT (must be auto, always, or never)" >&2
  exit 1
fi

if ! command -v msgmerge >/dev/null 2>&1; then
  echo "msgmerge not found. Install gettext tools first." >&2
  exit 1
fi

if ! command -v xgettext >/dev/null 2>&1; then
  echo "xgettext not found. Install gettext tools first." >&2
  exit 1
fi

if ! command -v msgcat >/dev/null 2>&1; then
  echo "msgcat not found. Install gettext tools first." >&2
  exit 1
fi

# POT extraction functions (mirror gulpfile.js logic)
extract_pot() {
  local type="$1"
  local pot_file="$POT_DIR/Koha-$type.pot"

  if [[ "$GENERATE_POT" == "never" ]]; then
    return 0
  fi

  if [[ "$GENERATE_POT" == "auto" && -f "$pot_file" ]]; then
    return 0
  fi

  echo "Extracting POT for type: $type"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: would extract $pot_file"
    return 0
  fi

  cd "$KOHA_PATH" || die "Cannot cd to $KOHA_PATH"

  case "$type" in
    marc-MARC21|marc-UNIMARC|marc-NORMARC)
      extract_marc "$type"
      ;;
    staff-prog)
      extract_staff_prog
      ;;
    opac-bootstrap)
      extract_opac_bootstrap
      ;;
    opac-prog)
      extract_opac_prog
      ;;
    pref)
      extract_pref
      ;;
    messages)
      extract_messages
      ;;
    messages-js)
      extract_messages_js
      ;;
    installer)
      extract_installer
      ;;
    installer-MARC21|installer-UNIMARC)
      extract_installer_marc "$type"
      ;;
    staff-help)
      echo "Skipping $type: extraction not implemented" >&2
      ;;
    *)
      echo "Unknown type for extraction: $type" >&2
      return 1
      ;;
  esac
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

extract_marc() {
  local marc_type="${1#marc-}"
  local files_list=$(mktemp)
  
  find koha-tmpl/*-tmpl/*/en -iname "*${marc_type}*" -type f > "$files_list" 2>/dev/null || true
  
  if [[ ! -s "$files_list" ]]; then
    echo "No files found for marc-$marc_type" >&2
    rm "$files_list"
    return 1
  fi

  misc/translator/xgettext.pl --charset=UTF-8 -F \
    -o "$POT_DIR/Koha-marc-$marc_type.pot" \
    -f "$files_list" || die "Failed to extract marc-$marc_type"
  
  rm "$files_list"
}

extract_staff_prog() {
  local files_list=$(mktemp)
  
  find koha-tmpl/intranet-tmpl/prog/en \
    \( -name "*.tt" -o -name "*.inc" \) \
    ! -iname "*MARC21*" ! -iname "*UNIMARC*" \
    ! -iname "*marc21*" ! -iname "*unimarc*" \
    -type f > "$files_list" 2>/dev/null || true
  
  find koha-tmpl/intranet-tmpl/prog/en/xslt -name "*.xsl" \
    ! -iname "*MARC21*" ! -iname "*UNIMARC*" \
    ! -iname "*marc21*" ! -iname "*unimarc*" \
    ! -iname "*NORMARC*" ! -iname "*normarc*" \
    -type f >> "$files_list" 2>/dev/null || true
  
  if [[ ! -s "$files_list" ]]; then
    echo "No files found for staff-prog" >&2
    rm "$files_list"
    return 1
  fi

  misc/translator/xgettext.pl --charset=UTF-8 -F \
    -o "$POT_DIR/Koha-staff-prog.pot" \
    -f "$files_list" || die "Failed to extract staff-prog"
  
  rm "$files_list"
}

extract_opac_bootstrap() {
  local files_list=$(mktemp)
  
  find koha-tmpl/opac-tmpl/bootstrap/en \
    \( -name "*.tt" -o -name "*.inc" \) \
    ! -iname "*MARC21*" ! -iname "*UNIMARC*" \
    ! -iname "*marc21*" ! -iname "*unimarc*" \
    -type f > "$files_list" 2>/dev/null || true
  
  find koha-tmpl/opac-tmpl/bootstrap/en/xslt -name "*.xsl" \
    ! -iname "*MARC21*" ! -iname "*UNIMARC*" \
    ! -iname "*marc21*" ! -iname "*unimarc*" \
    ! -iname "*NORMARC*" ! -iname "*normarc*" \
    -type f >> "$files_list" 2>/dev/null || true
  
  if [[ ! -s "$files_list" ]]; then
    echo "No files found for opac-bootstrap" >&2
    rm "$files_list"
    return 1
  fi

  misc/translator/xgettext.pl --charset=UTF-8 -F \
    -o "$POT_DIR/Koha-opac-bootstrap.pot" \
    -f "$files_list" || die "Failed to extract opac-bootstrap"
  
  rm "$files_list"
}

extract_opac_prog() {
  local files_list=$(mktemp)
  
  find koha-tmpl/opac-tmpl/prog/en \
    \( -name "*.tt" -o -name "*.inc" \) \
    ! -iname "*MARC21*" ! -iname "*UNIMARC*" \
    ! -iname "*marc21*" ! -iname "*unimarc*" \
    -type f > "$files_list" 2>/dev/null || true
  
  if [[ ! -s "$files_list" ]]; then
    echo "No files found for opac-prog" >&2
    rm "$files_list"
    return 1
  fi

  misc/translator/xgettext.pl --charset=UTF-8 -F \
    -o "$POT_DIR/Koha-opac-prog.pot" \
    -f "$files_list" || die "Failed to extract opac-prog"
  
  rm "$files_list"
}

extract_pref() {
  local files_list=$(mktemp)
  
  find koha-tmpl/intranet-tmpl/prog/en/modules/admin/preferences \
    -name "*.pref" -type f > "$files_list" 2>/dev/null || true
  
  if [[ ! -s "$files_list" ]]; then
    echo "No .pref files found" >&2
    rm "$files_list"
    return 1
  fi

  misc/translator/xgettext-pref \
    -o "$POT_DIR/Koha-pref.pot" \
    -f "$files_list" || die "Failed to extract pref"
  
  rm "$files_list"
}

extract_messages_js() {
  local files_list=$(mktemp)
  
  find koha-tmpl/intranet-tmpl/prog/js/vue -name "*.vue" -type f > "$files_list" 2>/dev/null || true
  find koha-tmpl/intranet-tmpl/prog/js -name "*.js" -type f >> "$files_list" 2>/dev/null || true
  find koha-tmpl/opac-tmpl/bootstrap/js -name "*.js" -type f >> "$files_list" 2>/dev/null || true
  
  if [[ ! -s "$files_list" ]]; then
    echo "No JS files found" >&2
    rm "$files_list"
    return 1
  fi

  xgettext -L JavaScript \
    --from-code=UTF-8 --package-name Koha \
    -k -k__ -k__x -k__n:1,2 -k__nx:1,2 -k__xn:1,2 \
    -k__p:1c,2 -k__px:1c,2 -k__np:1c,2,3 -k__npx:1c,2,3 -kN__ \
    -kN__n:1,2 -kN__p:1c,2 -kN__np:1c,2,3 \
    -k -k\$__ -k\$__x -k\$__n:1,2 -k\$__nx:1,2 -k\$__xn:1,2 \
    --force-po \
    -o "$POT_DIR/Koha-messages-js.pot" \
    -f "$files_list" || die "Failed to extract messages-js"
  
  rm "$files_list"
}

extract_messages() {
  local perl_list=$(mktemp)
  local tt_list=$(mktemp)
  local perl_pot="$POT_DIR/Koha-perl.pot.tmp"
  local tt_pot="$POT_DIR/Koha-tt.pot.tmp"
  
  find . -name "*.pl" -o -name "*.pm" | grep -v "/blib/" | grep -v "/\.git/" > "$perl_list" 2>/dev/null || true
  
  find koha-tmpl/intranet-tmpl/prog/en -name "*.tt" -o -name "*.inc" > "$tt_list" 2>/dev/null || true
  find koha-tmpl/opac-tmpl/bootstrap/en -name "*.tt" -o -name "*.inc" >> "$tt_list" 2>/dev/null || true
  
  if [[ -s "$perl_list" ]]; then
    xgettext -L Perl \
      --from-code=UTF-8 --package-name Koha \
      -k -k__ -k__x -k__n:1,2 -k__nx:1,2 -k__xn:1,2 \
      -k__p:1c,2 -k__px:1c,2 -k__np:1c,2,3 -k__npx:1c,2,3 -kN__ \
      -kN__n:1,2 -kN__p:1c,2 -kN__np:1c,2,3 \
      -k -k\$__ -k\$__x -k\$__n:1,2 -k\$__nx:1,2 -k\$__xn:1,2 \
      --force-po \
      -o "$perl_pot" \
      -f "$perl_list" || die "Failed to extract Perl messages"
  fi
  
  if [[ -s "$tt_list" ]]; then
    misc/translator/xgettext-tt2 --from-code=UTF-8 \
      -o "$tt_pot" \
      -f "$tt_list" || die "Failed to extract TT messages"
  fi
  
  # Merge Perl and TT POTs
  if [[ -f "$perl_pot" && -f "$tt_pot" ]]; then
    msgcat --use-first "$perl_pot" "$tt_pot" -o "$POT_DIR/Koha-messages.pot" || die "Failed to merge messages POTs"
    rm -f "$perl_pot" "$tt_pot"
  elif [[ -f "$perl_pot" ]]; then
    mv "$perl_pot" "$POT_DIR/Koha-messages.pot"
  elif [[ -f "$tt_pot" ]]; then
    mv "$tt_pot" "$POT_DIR/Koha-messages.pot"
  fi
  
  rm -f "$perl_list" "$tt_list"
}

extract_installer() {
  local files_list=$(mktemp)
  
  find installer/data/mysql/en/mandatory -name "*.yml" -type f > "$files_list" 2>/dev/null || true
  find installer/data/mysql/en/optional -name "*.yml" -type f >> "$files_list" 2>/dev/null || true
  
  if [[ ! -s "$files_list" ]]; then
    echo "No installer YAML files found" >&2
    rm "$files_list"
    return 1
  fi

  misc/translator/xgettext-installer \
    -o "$POT_DIR/Koha-installer.pot" \
    -f "$files_list" || die "Failed to extract installer"
  
  rm "$files_list"
}

extract_installer_marc() {
  local marc_type="${1#installer-}"
  local marc_dir="${marc_type,,}"  # Convert to lowercase for directory name
  local files_list=$(mktemp)
  
  find "installer/data/mysql/en/marcflavour/$marc_dir" -name "*.yml" -type f > "$files_list" 2>/dev/null || true
  
  if [[ ! -s "$files_list" ]]; then
    echo "No installer files found for $marc_type" >&2
    rm "$files_list"
    return 1
  fi

  misc/translator/xgettext-installer \
    -o "$POT_DIR/Koha-installer-$marc_type.pot" \
    -f "$files_list" || die "Failed to extract installer-$marc_type"
  
  rm "$files_list"
}

# Determine which types to process
PROCESS_TYPES=()
if [[ -n "$TYPE_FILTER" ]]; then
  IFS=',' read -r -a PROCESS_TYPES <<< "$TYPE_FILTER"
else
  # If updating POs, determine types from existing PO files
  # If only extracting, use all types
  if [[ -d "$PO_DIR" ]]; then
    shopt -s nullglob
    for po in "$PO_DIR"/*.po; do
      file_name="$(basename "$po")"
      for known_type in "${TYPES[@]}"; do
        suffix="-$known_type.pot"
        if [[ "$file_name" == *"-$known_type.po" ]]; then
          if ! contains_csv_value "$(IFS=,; echo "${PROCESS_TYPES[*]}")" "$known_type"; then
            PROCESS_TYPES+=("$known_type")
          fi
          break
        fi
      done
    done
  else
    PROCESS_TYPES=("${TYPES[@]}")
  fi
fi

# Extract POTs for selected types
extracted=0
extract_failed=0

for type in "${PROCESS_TYPES[@]}"; do
  if extract_pot "$type"; then
    extracted=$((extracted + 1))
  else
    echo "Warning: POT extraction failed for $type" >&2
    extract_failed=$((extract_failed + 1))
  fi
done

echo "POT extraction: extracted=$extracted failed=$extract_failed"
echo

# Update PO files if PO directory exists
if [[ ! -d "$PO_DIR" ]]; then
  echo "PO directory not found: $PO_DIR (skipping PO update)"
  echo "Summary: POT extraction complete. No PO files to update."
  exit 0
fi

shopt -s nullglob
updated=0
skipped=0
failed=0
missing_pot=0

for po in "$PO_DIR"/*.po; do
  file_name="$(basename "$po")"

  if [[ -n "$LANG_FILTER" ]] && ! file_matches_language_filter "$file_name" "$LANG_FILTER"; then
    skipped=$((skipped + 1))
    continue
  fi

  type=""
  language=""

  for known_type in "${TYPES[@]}"; do
    suffix="-$known_type.po"
    if [[ "$file_name" == *"$suffix" ]]; then
      type="$known_type"
      language="${file_name%$suffix}"
      break
    fi
  done

  if [[ -z "$type" || -z "$language" ]]; then
    echo "Skipping $file_name: unable to determine language/type" >&2
    skipped=$((skipped + 1))
    continue
  fi

  if [[ -n "$LANG_FILTER" ]] && ! contains_csv_value "$LANG_FILTER" "$language"; then
    skipped=$((skipped + 1))
    continue
  fi

  if [[ -n "$TYPE_FILTER" ]] && ! contains_csv_value "$TYPE_FILTER" "$type"; then
    skipped=$((skipped + 1))
    continue
  fi

  pot="$POT_DIR/Koha-$type.pot"
  if [[ ! -f "$pot" ]]; then
    echo "Skipping $file_name: missing POT $pot" >&2
    missing_pot=$((missing_pot + 1))
    skipped=$((skipped + 1))
    continue
  fi

  cmd=(msgmerge --backup=off --no-wrap --quiet -F --update "$po" "$pot")
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: ${cmd[*]}"
    updated=$((updated + 1))
    continue
  fi

  if "${cmd[@]}"; then
    echo "Updated $file_name"
    updated=$((updated + 1))
  else
    echo "Failed $file_name" >&2
    failed=$((failed + 1))
  fi
done

echo
echo "Summary: updated=$updated skipped=$skipped missing_pot=$missing_pot failed=$failed"

if [[ "$updated" -eq 0 && "$missing_pot" -gt 0 ]]; then
  echo "Hint: provide --pot-dir with pre-generated POT files if Koha-*.pot are not present in $POT_DIR" >&2
fi

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi

# Copy PO files to Koha repository if requested
if [[ "$COPY_TO_KOHA" -eq 1 ]]; then
  echo
  echo "Copying PO files to Koha repository..."
  
  KOHA_PO_DIR="$KOHA_PATH/misc/translator/po"
  
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: would create directory $KOHA_PO_DIR"
    echo "DRY-RUN: would copy $PO_DIR/*.po to $KOHA_PO_DIR/"
  else
    mkdir -p "$KOHA_PO_DIR" || {
      echo "Failed to create directory $KOHA_PO_DIR" >&2
      exit 1
    }
    
    copied=0
    copy_failed=0
    
    for po_file in "$PO_DIR"/*.po; do
      if [[ -f "$po_file" ]]; then
        file_name="$(basename "$po_file")"
        
        # Apply language filter if set
        if [[ -n "$LANG_FILTER" ]]; then
          if ! file_matches_language_filter "$file_name" "$LANG_FILTER"; then
            continue
          fi
        fi
        
        # Apply type filter if set
        if [[ -n "$TYPE_FILTER" ]]; then
          matched=0
          for type in "${TYPES[@]}"; do
            if [[ "$file_name" == *"-$type.po" ]] && contains_csv_value "$TYPE_FILTER" "$type"; then
              matched=1
              break
            fi
          done
          if [[ "$matched" -eq 0 ]]; then
            continue
          fi
        fi
        
        if cp "$po_file" "$KOHA_PO_DIR/"; then
          echo "Copied $file_name"
          copied=$((copied + 1))
        else
          echo "Failed to copy $file_name" >&2
          copy_failed=$((copy_failed + 1))
        fi
      fi
    done
    
    echo "Copied $copied PO files to $KOHA_PO_DIR"
    
    if [[ "$copy_failed" -gt 0 ]]; then
      echo "Warning: $copy_failed files failed to copy" >&2
    fi
  fi
fi

# Push to GitHub if requested
if [[ "$PUSH_TO_GITHUB" -eq 1 ]]; then
  echo
  echo "Pushing changes to GitHub..."
  
  # Change to translations directory
  cd "$TRANSLATIONS_PATH" || {
    echo "Failed to change to translations directory: $TRANSLATIONS_PATH" >&2
    exit 1
  }
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: $TRANSLATIONS_PATH is not a git repository" >&2
    exit 1
  fi
  
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: would run git add po/ pot/"
    echo "DRY-RUN: would run git commit -m 'Update PO and POT files from Koha sources'"
    echo "DRY-RUN: would run git push"
  else
    # Check if there are changes to commit
    if git diff --quiet po/ pot/ 2>/dev/null && git diff --cached --quiet po/ pot/ 2>/dev/null; then
      echo "No changes to commit in po/ or pot/ directories"
    else
      # Add PO and POT files
      git add po/ pot/ || {
        echo "Failed to add files to git" >&2
        exit 1
      }
      
      # Create commit message with timestamp and languages/types if filtered
      COMMIT_MSG="Update PO and POT files from Koha sources ($(date +'%Y-%m-%d %H:%M'))"
      if [[ -n "$LANG_FILTER" ]]; then
        COMMIT_MSG="$COMMIT_MSG [langs: $LANG_FILTER]"
      fi
      if [[ -n "$TYPE_FILTER" ]]; then
        COMMIT_MSG="$COMMIT_MSG [types: $TYPE_FILTER]"
      fi
      
      # Commit changes
      if git commit -m "$COMMIT_MSG"; then
        echo "Committed changes: $COMMIT_MSG"
        
        # Push to remote
        if git push; then
          echo "Successfully pushed to GitHub"
        else
          echo "Failed to push to GitHub" >&2
          exit 1
        fi
      else
        echo "Failed to commit changes" >&2
        exit 1
      fi
    fi
  fi
fi
