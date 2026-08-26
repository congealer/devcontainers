#!/bin/bash

set -e

VERSION=${VERSION:-"3.12.2"}

ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)  ARCH="x64"   ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;;
esac

URL="https://storage.googleapis.com/dart-archive/channels/stable/release/${VERSION}/sdk/dartsdk-linux-${ARCH}-release.zip"

# The SDK zips avoid the apt repository entirely, which is what makes this short:
# apt would mean carrying GPG key rotation handling.
echo "Downloading Dart SDK ${VERSION}..."
curl -fL -o dart-sdk.zip "${URL}" \
    && unzip -q dart-sdk.zip -d /tmp \
    && mkdir -p /opt \
    && rm -rf /opt/dart \
    && mv /tmp/dart-sdk /opt/dart \
    && rm -f dart-sdk.zip

# A symlink rather than a PATH entry: /usr/local/bin is already on the default
# PATH, so this covers interactive shells, lifecycle hooks and `devcontainer
# exec` alike. Setting PATH from a feature's containerEnv is not an option --
# it is emitted verbatim as a Dockerfile `ENV`, where `${containerEnv:PATH}`
# does not expand.
ln -sf /opt/dart/bin/dart /usr/local/bin/dart

dart --version
