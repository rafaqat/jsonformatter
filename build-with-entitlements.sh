#!/bin/bash

# Build the app
swift build -c release

# Sign with entitlements
codesign --force --deep --sign - --entitlements Sources/JSONFormatterApp/JSONFormatterApp.entitlements .build/release/JSONFormatterApp

echo "Build complete with entitlements!"
echo "Run with: .build/release/JSONFormatterApp"