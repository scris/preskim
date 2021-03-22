#!/bin/bash

# app name
NAME=Skim

# app bundle to copy, filename should be "${NAME}.app"
SRC_BUNDLE="$1"
SRC_BUNDLE=$(cd $(dirname "$SRC_BUNDLE"); pwd)/$(basename "$SRC_BUNDLE")

# version
VERSION=$(/usr/bin/defaults read "${SRC_BUNDLE}/Contents/Info" CFBundleShortVersionString)

# target name
DIST_NAME="${NAME}-${VERSION}"

# target zip archive
DIST_ARCHIVE="${HOME}/Desktop/${DIST_NAME}.zip"

# create archive
/usr/bin/ditto -c -k --keepParent "$SRC_BUNDLE" "$DIST_ARCHIVE"

# create the Sparkle appcast
# see http://www.entropy.ch/blog/Developer/2008/09/22/Sparkle-Appcast-Automation-in-Xcode.html

echo "Creating appcast for Sparkle..."

DATE=$(/bin/date +"%a, %d %b %Y %T %z")
SIZE=$(/usr/bin/stat -f %z "${DIST_ARCHIVE}")
VERSION_NUMBER=$(/usr/bin/defaults read "${SRC_BUNDLE}/Contents/Info" CFBundleVersion)
URL="https://sourceforge.net/projects/skim-app/files/${NAME}/${DIST_NAME}/${DIST_NAME}.zip/download"
APPCAST="${HOME}/Desktop/${DIST_NAME}.xml"
KEY_NAME="${NAME} Sparkle Key"
SIGNATURE=$(/usr/bin/openssl dgst -sha1 -binary < "${DIST_ARCHIVE}" | /usr/bin/openssl dgst -dss1 -sign <(security find-generic-password -g -s "${KEY_NAME}" 2>&1 1>/dev/null | perl -pe '($_) = /"(.+)"/; s/\\012/\n/g') | /usr/bin/openssl enc -base64)
if [ $? != 0 ]; then
    echo "warning: failed to generate signature.  You need the private key in a secure note named \"${KEY_NAME}\"" >&2
fi

/bin/cat > "${APPCAST}" << EOF
<?xml version="1.0" encoding="utf-8"?> 
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"  xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel> 
        <title>${NAME} Changelog</title>
        <link>https://skim-app.sourceforge.io</link>
        <description>PDF reader and note-taker</description>
        <item>
            <title>Version ${VERSION}</title>
            <description><![CDATA[
<h1>Version ${VERSION}</h1>

<h2>New Features</h2>
<ul>
<li></li>
</ul>

<h2>Bugs Fixed</h2>
<ul>
<li></li>
</ul>
            ]]></description>
            <pubDate>${DATE}</pubDate>
            <sparkle:minimumSystemVersion>10.10.0</sparkle:minimumSystemVersion>
            <enclosure sparkle:version="${VERSION_NUMBER}" sparkle:shortVersionString="${VERSION}" url="${URL}" sparkle:dsaSignature="${SIGNATURE}" length="${SIZE}" type="application/zip"/>
        </item>

    </channel>
</rss>
EOF
