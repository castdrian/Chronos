#!/usr/bin/env zsh
set -euo pipefail

ACTION="${1:-Package}"
echo ">> action: ${ACTION}"

icloud_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs"

build_package() {
  rm -rf packages
  gmake clean package
}

case "$ACTION" in
  Package)
    build_package
    ;;
  "AirDrop Tweak")
    build_package
    shortcuts run AirDrop -i ./packages/*.deb
    ;;
  "Build IPA")
    build_package
    chmod +x build-local.sh
    ./build-local.sh
    ;;
  ".dylib -> iCloud Drive")
    build_package
    DYLIB=$(ls .theos/obj/*.dylib 2>/dev/null | head -n1 || true)
    if [[ -n "$DYLIB" && -f "$DYLIB" ]]; then
      [[ -d "$icloud_dir" ]] || { echo "Destination directory missing: $icloud_dir" >&2; exit 1; }
      cp -v "$DYLIB" "$icloud_dir/" || { echo "Copy failed" >&2; exit 1; }
    else
      echo "No dylib found in .theos/obj" >&2
      exit 1
    fi
    ;;
  ".deb -> iCloud Drive")
    build_package
    [[ -d "$icloud_dir" ]] || { echo "Destination directory missing: $icloud_dir" >&2; exit 1; }
    cp -v packages/*.deb "$icloud_dir/" || { echo "Copy failed" >&2; exit 1; }
    ;;
  ".ipa -> iCloud Drive")
    build_package
    chmod +x build-local.sh
    ./build-local.sh
    IPA=$(ls *.ipa 2>/dev/null | head -n1 || true)
    if [[ -n "${IPA}" ]]; then
      [[ -d "$icloud_dir" ]] || { echo "Destination directory missing: $icloud_dir" >&2; exit 1; }
      cp -v "$IPA" "$icloud_dir/" || { echo "Copy failed" >&2; exit 1; }
    else
      echo "No IPA found" >&2
      exit 1
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
