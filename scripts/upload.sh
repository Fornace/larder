#!/bin/bash
# Upload Larder to App Store Connect.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID=6824195346
ENV_FILE="$HOME/.agent_credentials/apple/appstore-connect.env"
IPA=build/export/Larder.ipa

[ -f "$ENV_FILE" ] || { echo "missing $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"

if [ ! -f "${ASC_KEY_PATH:-/nonexistent}" ]; then
  echo "App Store Connect API key not configured in $ENV_FILE"
  exit 1
fi

chmod 600 "$ASC_KEY_PATH"
export ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH

if [ ! -f "$IPA" ]; then
  echo "No IPA yet, building one."
  xcodebuild -project Larder.xcodeproj -scheme Larder -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/Larder.xcarchive \
    -derivedDataPath build/dd-archive -allowProvisioningUpdates archive
  xcodebuild -exportArchive -archivePath build/Larder.xcarchive -exportPath build/export \
    -exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates
fi

"$HOME/.local/bin/asc" auth login --name larder \
  --key-id "$ASC_KEY_ID" --issuer-id "$ASC_ISSUER_ID" --private-key "$ASC_KEY_PATH" --fix-permissions

"$HOME/.local/bin/asc" builds upload --app "$APP_ID" --ipa "$IPA" --version 1.0 --build-number 1 --wait
