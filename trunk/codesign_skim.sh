#!/bin/sh

IDENTITY="Skim Signing Certificate"

if [ "$#" -gt 2 ]; then 
  IDENTITY="Developer ID Application: $1 ($2)"
elif [ "$#" -gt 1 ]; then
  IDENTITY="$1"
fi

SKIM_BUNDLE_PATH="${!#}"

SKIM_ENTITLEMENTS=$(dirname "$0")/Skim.entitlements

# see https://mjtsai.com/blog/2021/02/18/code-signing-when-building-on-apple-silicon/
CODESIGN_FLAGS="--verbose --options runtime --timestamp --force --digest-algorithm=sha1,sha256"

CONTENTS_DIR="${SKIM_BUNDLE_PATH}/Contents"

# have to sign frameworks first
LOCATION="${CONTENTS_DIR}/Frameworks"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/SkimNotes.framework/Versions/A"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/Sparkle.framework/Versions/A/Resources/Autoupdate.app/Contents/MacOS/fileop"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/Sparkle.framework/Versions/A/Resources/Autoupdate.app/Contents/MacOS/Autoupdate"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/Sparkle.framework/Versions/A"

LOCATION="${CONTENTS_DIR}/Library"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/Spotlight/SkimImporter.mdimporter/Contents/Frameworks/SkimNotesBase.framework/Versions/A"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/Spotlight/SkimImporter.mdimporter/Contents/MacOS/SkimImporter"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/QuickLook/Skim.qlgenerator/Contents/MacOS/Skim"

LOCATION="${CONTENTS_DIR}/Plugins"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/SkimTransitions.plugin/Contents/MacOS/SkimTransitions"

LOCATION="${CONTENTS_DIR}/SharedSupport"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/skimnotes"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/skimpdf"

LOCATION="${CONTENTS_DIR}/MacOS"
codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" "${LOCATION}/relaunch"

codesign ${CODESIGN_FLAGS} --sign "${IDENTITY}" --entitlements "${SKIM_ENTITLEMENTS}" "${BIBDESK_BUNDLE_PATH}"
