#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.6}"
FLUTTER_DIR="${HOME}/.cache/flutter-${FLUTTER_VERSION}"

if [[ ! -x "${FLUTTER_DIR}/bin/flutter" ]]; then
  mkdir -p "$(dirname "${FLUTTER_DIR}")"
  git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter config --enable-web
flutter precache --web
flutter pub get
flutter build web --release
