#!/bin/zsh

echo "🔨 Building macOS Universal dylib (arm64 + x86_64)..."

# 最簡化版本，只保留必要參數
clang -dynamiclib \
    -framework Foundation \
    -arch arm64 \
    -arch x86_64 \
    -fobjc-arc \
    -o libmdns_ffi.dylib \
    mdns_ffi.m

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    lipo -info libmdns_ffi.dylib
else
    echo "❌ Build failed!"
    exit 1
fi
