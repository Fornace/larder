#!/bin/bash
# Upload Larder to App Store Connect.
#
# The app record already exists:
#   Larder: Pantry and Dinner — App Store Connect ID 6824195346
#   Bundle ID app.fornace.larder (iOS and macOS, one multiplatform record)
#
# The single missing input is the App Store Connect API private key. Its
# metadata is already configured in ~/.agent_credentials/apple/appstore-connect.env
# (key K6R4NZ46Z5, issuer 69a6de75-aa34-47e3-e053-5b8c7c11a4d1, Admin), but the
# .p8 itself is not on this Mac and Apple lets you download it only once.
#
# To finish, restore the key to the path named in that env file:
#   App Store Connect ▸ Users and Access ▸ Integrations ▸ Team Keys
#   ▸ the key's ••• menu ▸ (create a new key if the old .p8 is lost)
#   ▸ download AuthKey_<KEYID>.p8 into ~/.agent_credentials/apple/
#   ▸ update APP_STORE_CONNECT_KEY_ID / _KEY_FILEPATH in appstore-connect.env
# Then run this script once.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID=6824195346
ENV_FILE="$HOME/.agent_credentials/apple/appstore-connect.env"
IPA=build/export/Larder.ipa

[ -f "$ENV_FILE" ] || { echo "missing $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"

if [ ! -f "${ASC_KEY_PATH:-/nonexistent}" ]; then
  echo "BLOCKED: App Store Connect API key not found."
  echo "  key id  : ${ASC_KEY_ID:-unknown}"
  echo "  expected: ${ASC_KEY_PATH:-unset}"
  echo
  echo "Download the .p8 once from App Store Connect ▸ Users and Access ▸ Integrations ▸ Team Keys,"
  echo "save it at that path, then run ./scripts/upload.sh again."
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
