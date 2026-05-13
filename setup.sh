#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
SUPERTONIC_DIR="$PROJECT_DIR/../supertonic"

echo "=================================="
echo "  Oracle Setup"
echo "=================================="
echo ""

# Check dependencies
if ! command -v git &> /dev/null; then
    echo "Error: git is required but not installed."
    exit 1
fi

if ! command -v swift &> /dev/null; then
    echo "Error: Swift is required. Please install Xcode."
    exit 1
fi

if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen..."
    brew install xcodegen 2>/dev/null || {
        echo "Error: Failed to install xcodegen. Please install it manually:"
        echo "  brew install xcodegen"
        exit 1
    }
fi

# Install git-lfs
if ! command -v git-lfs &> /dev/null; then
    echo "Installing git-lfs..."
    brew install git-lfs 2>/dev/null || true
fi
git lfs install 2>/dev/null || true

# Clone Supertonic code
echo ""
echo "Cloning Supertonic..."
if [ ! -d "$SUPERTONIC_DIR" ]; then
    git clone https://github.com/supertone-inc/supertonic.git "$SUPERTONIC_DIR"
else
    echo "Supertonic already cloned."
fi

# Clone Supertonic assets (ONNX models + voice styles)
echo ""
echo "Downloading Supertonic ONNX models and voice styles..."
echo "(This may take a few minutes, models are ~100MB)"
cd "$SUPERTONIC_DIR"
if [ ! -d "assets" ]; then
    git clone https://huggingface.co/Supertone/supertonic-3 assets
else
    echo "Assets already downloaded."
fi

# Build Supertonic Swift executable
echo ""
echo "Building Supertonic executable..."
cd "$SUPERTONIC_DIR/swift"
swift build -c release

echo ""
echo "Supertonic built successfully at:"
echo "  $SUPERTONIC_DIR/swift/.build/release/example_onnx"

# Generate Xcode project
echo ""
echo "Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

echo ""
echo "=================================="
echo "  Setup Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Open Oracle.xcodeproj in Xcode"
echo "2. Select your team for code signing"
echo "3. Build and run (Cmd+R)"
echo "4. Add your LLM API keys in Oracle Settings"
echo "5. Press Cmd+Shift+Space to activate Oracle"
echo ""
