#!/bin/bash
# Downlaods the latest currencies list to be embedded
filename="tokens.json"
host="api.breadwallet.com"
echo "Downloading ${filename} from ${host}..."
curl --silent --show-error --output "breadwallet/Resources/${filename}" https://${host}/currencies?type=erc20