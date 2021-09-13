#!/bin/sh

IDENTITY="Skim Signing Certificate"

if [ "$#" -gt 2 ]; then 
  IDENTITY="Developer ID Application: $1 ($2)"
elif [ "$#" -gt 1 ]; then
  IDENTITY="$1"
fi

SKIM_BUNDLE_PATH="${!#}"

if [[ "$IDENTITY" == "Developer ID Application:"* ]]; then
  CODESIGN_OPTIONS="-o runtime"
else
  CODESIGN_OPTIONS=
fi

SKIM_ENTITLEMENTS=$(dirname "$0")/Skim.entitlements

# see https://mjtsai.com/blog/2021/02/18/code-signing-when-building-on-apple-silicon/
# and https://developer.apple.com/forums/thread/130855
CODESIGN_FLAGS="-v --timestamp -f --digest-algorithm=sha1,sha256"

CONTENTS_DIR="${SKIM_BUNDLE_PATH}/Contents"

# have to sign frameworks first
LOCATION="${CONTENTS_DIR}/Frameworks"
codesign ${CODESIGN_FLAGS} -s "${IDENTITY}" "${LOCATION}/SkimNotes.framework"
codesign ${CODESIGN_FLAGS} ${CODESIGN_OPTIONS} -s "${IDENTITY}" --identifier "org.sparkle-project.Sparkle.Autoupdate.fileop" "${LOCATION}/Sparkle.framework/Versions/A/Resources/Autoupdate.app/Contents/MacOS/fileop"
codesign ${CODESIGN_FLAGS} ${CODESIGN_OPTIONS} -s "${IDENTITY}" "${LOCATION}/Sparkle.framework/Versions/A/Resources/Autoupdate.app"
codesign ${CODESIGN_FLAGS} -s "${IDENTITY}" "${LOCATION}/Sparkle.framework"

LOCATION="${CONTENTS_DIR}/Library"
codesign ${CODESIGN_FLAGS} -s "${IDENTITY}" "${LOCATION}/Spotlight/SkimImporter.mdimporter/Contents/Frameworks/SkimNotesBase.framework"
codesign ${CODESIGN_FLAGS} ${CODESIGN_OPTIONS} -s "${IDENTITY}" "${LOCATION}/Spotlight/SkimImporter.mdimporter/Contents/MacOS/SkimImporter"
codesign ${CODESIGN_FLAGS} ${CODESIGN_OPTIONS} -s "${IDENTITY}" "${LOCATION}/QuickLook/Skim.qlgenerator/Contents/MacOS/Skim"

LOCATION="${CONTENTS_DIR}/Plugins"
codesign ${CODESIGN_FLAGS} ${CODESIGN_OPTIONS} --sign "${IDENTITY}" "${LOCATION}/SkimTransitions.plugin/Contents/MacOS/SkimTransitions"

LOCATION="${CONTENTS_DIR}/SharedSupport"
codesign ${CODESIGN_FLAGS} ${CODESIGN_OPTIONS} -s "${IDENTITY}" --identifier "net.sourceforge.skim-app.tool.skimnotes" "${LOCATION}/skimnotes"
codesign ${CODESIGN_FLAGS} ${CODESIGN_OPTIONS} -s "${IDENTITY}" --identifier "net.sourceforge.skim-app.tool.skimpdf" "${LOCATION}/skimpdf"

codesign ${CODESIGN_FLAGS} ${CODESIGN_OPTIONS} -s "${IDENTITY}" ${CODESIGN_OPTIONS:+--entitlements "${SKIM_ENTITLEMENTS}"} "${SKIM_BUNDLE_PATH}"
