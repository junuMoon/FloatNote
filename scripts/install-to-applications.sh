#!/bin/sh

set -eu

APP_NAME="${FULL_PRODUCT_NAME:-FloatNote.app}"
SOURCE_APP="${TARGET_BUILD_DIR:?}/${APP_NAME}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

resolve_destination_dir() {
  for candidate in \
    "${HOME}/Applications" \
    "${HOME}/Workspace/Applications" \
    "${HOME}/Desktop"
  do
    if [ -d "${candidate}" ]; then
      if [ -w "${candidate}" ]; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    else
      parent_dir="$(dirname "${candidate}")"
      if [ -w "${parent_dir}" ]; then
        mkdir -p "${candidate}"
        printf '%s\n' "${candidate}"
        return 0
      fi
    fi
  done

  return 1
}

if [ ! -d "${SOURCE_APP}" ]; then
  echo "FloatNote install skipped: app bundle not found at ${SOURCE_APP}" >&2
  exit 0
fi

DEST_DIR="$(resolve_destination_dir || true)"

if [ -z "${DEST_DIR}" ]; then
  echo "FloatNote install skipped: no writable application directory found" >&2
  exit 0
fi

DEST_APP="${DEST_DIR}/${APP_NAME}"
rm -rf "${DEST_APP}"
/usr/bin/ditto "${SOURCE_APP}" "${DEST_APP}"
/usr/bin/codesign --force --deep --sign - "${DEST_APP}" >/dev/null 2>&1 || true

if [ -x "${LSREGISTER}" ]; then
  "${LSREGISTER}" -f "${DEST_APP}" >/dev/null 2>&1 || true
fi

/usr/bin/mdimport "${DEST_APP}" >/dev/null 2>&1 || true

echo "Installed ${APP_NAME} to ${DEST_APP}"
