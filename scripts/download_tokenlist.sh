#!/bin/bash
# Downlaods the latest currencies list to be embedded
filename="tokens.json"
host="stage2.breadwallet.com"
if [ "${CONFIGURATION}" == "Release" ]; then
  host="api.breadwallet.com"
fi
echo "Downloading ${filename} from ${host}..."
curl --silent --show-error --output "breadwallet/Resources/${filename}" https://${host}/currencies
