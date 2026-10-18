#!/bin/zsh
# One command to put the signed archive on App Store Connect.
#
# Needs the App Store Connect API key (Team Key K6R4NZ46Z5) at the path the
# credentials file names. Nothing else. Run from the repository root:
#
#   ./scripts/upload.sh
#
# The key id and issuer id come from ~/.agent_credentials/apple/appstore-connect.env.

set -euo pipefail

cd "$(dirname "$0")/.."

CREDS="${HOME}/.agent_credentials/apple/appstore-connect.env"
if [[ ! -f "$CREDS" ]]; then
  echo "missing $CREDS" >&2
  exit 1
fi
source "$CREDS"

if [[ ! -f "$APP_STORE_CONNECT_KEY_FILEPATH" ]]; then
  echo "missing API key at $APP_STORE_CONNECT_KEY_FILEPATH" >&2
  echo "download it from App Store Connect, Integrations, Team Keys, key $APP_STORE_CONNECT_KEY_ID" >&2
  exit 1
fi

ARCHIVE="build/Larder.xcarchive"
EXPORT_DIR="build/export"

if [[ ! -d "$ARCHIVE" ]]; then
  echo "no archive yet, building one"
  xcodebuild -project Larder.xcodeproj -scheme Larder -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    -derivedDataPath build/dd-archive -allowProvisioningUpdates archive
fi

rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates

IPA=$(/usr/bin/find "$EXPORT_DIR" -name '*.ipa' | head -1)
if [[ -z "$IPA" ]]; then
  echo "export produced no ipa" >&2
  exit 1
fi
echo "exported $IPA"

xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

echo "uploaded to App Store Connect"
