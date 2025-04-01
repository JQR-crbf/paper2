#!/bin/bash

# Check if Xcode is installed
if ! [ -d "/Applications/Xcode.app" ]; then
    echo "❌ Error: Xcode is not installed in /Applications"
    exit 1
fi

# Set Xcode as the active developer directory
# (Most ly working without this, then it don't require password. Uncomment if needed)
#sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Automatically detect the scheme
SCHEME=$(xcodebuild -list | sed -n '/Schemes:/,/Targets:/p' | sed -n '2p' | xargs)

if [ -z "$SCHEME" ]; then
    echo "❌ Error: No scheme found in the Xcode project."
    exit 1
fi

echo "🔍 Detected scheme: $SCHEME"

# Function to perform build
perform_build() {
    local clean=$1
    local build_cmd="xcodebuild -scheme \"$SCHEME\" \
        -destination \"platform=macOS,arch=arm64\""
    
    if [ "$clean" = true ]; then
        echo "🧹 Cleaning and rebuilding..."
        build_cmd="$build_cmd clean build"
    else
        echo "🏗️ Building project (using cache)..."
        build_cmd="$build_cmd build"
    fi
    
    BUILD_OUTPUT=$(eval "$build_cmd" 2>&1)
    
    # Check for errors
    if echo "$BUILD_OUTPUT" | grep -q "error:"; then
        echo "❌ Build failed with errors:"
        echo "$BUILD_OUTPUT" | grep -A 5 "error:"
        return 1
    fi
    
    # Check for warnings
    if echo "$BUILD_OUTPUT" | grep -q "warning:"; then
        echo "⚠️ Build succeeded with warnings:"
        echo "$BUILD_OUTPUT" | grep -A 5 "warning:"
    fi
    
    echo "✅ Build succeeded!"
    return 0
}

# First try building without cleaning
perform_build false

# If the first build failed, try cleaning and rebuilding
if [ $? -ne 0 ]; then
    echo "🔄 Initial build failed, trying clean build..."
    perform_build true
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi 