#!/usr/bin/env bash
# build-bitnet-ios.sh — compile bitnet.cpp for iOS and package BitNet.xcframework.
#
# Produces: Packages/NavAI/Frameworks/BitNet.xcframework
#   (device arm64 + simulator arm64), each a single static lib bundling
#   libllama + libggml* + our nava_bitnet wrapper, plus the public header.
#
# Requirements (run on a Mac):
#   - Xcode + command line tools (xcodebuild, libtool, clang)
#   - cmake >= 3.22
#   - python3 (bitnet.cpp uses it to generate its ternary lookup-table kernels)
#
# This is intentionally explicit rather than magic: bitnet.cpp's kernel codegen
# and CMake flags move over time, so the tunables are variables up top. If a
# build breaks after bumping BITNET_REF, the likely culprits are the codegen
# step and the -DBITNET_* / -DGGML_* flags.
set -euo pipefail

# ---- tunables --------------------------------------------------------------
BITNET_REPO="${BITNET_REPO:-https://github.com/microsoft/BitNet.git}"
BITNET_REF="${BITNET_REF:-main}"          # pin to a known-good commit for prod
MIN_IOS="${MIN_IOS:-17.0}"
# Quantization / kernel type for BitNet-b1.58-2B-4T. i2_s ships preset kernels
# and is the most portable choice for on-device.
QUANT_TYPE="${QUANT_TYPE:-i2_s}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK="${WORK:-$PKG_DIR/.build-native}"
BITNET_DIR="$WORK/BitNet"
OUT_XCFRAMEWORK="$PKG_DIR/Frameworks/BitNet.xcframework"
WRAPPER_SRC="$PKG_DIR/native/nava_bitnet.cpp"
HEADER_DIR="$PKG_DIR/native/include"

echo "==> NavAI bitnet.cpp iOS build"
echo "    repo=$BITNET_REPO ref=$BITNET_REF quant=$QUANT_TYPE min_ios=$MIN_IOS"

mkdir -p "$WORK"

# ---- 1. fetch bitnet.cpp (+ its llama.cpp submodule) -----------------------
if [ ! -d "$BITNET_DIR/.git" ]; then
    git clone --recursive "$BITNET_REPO" "$BITNET_DIR"
fi
git -C "$BITNET_DIR" fetch --all --tags
git -C "$BITNET_DIR" checkout "$BITNET_REF"
git -C "$BITNET_DIR" submodule update --init --recursive

# ---- 2. generate the ternary kernels for the 2B architecture ----------------
# bitnet.cpp generates lookup-table kernels sized to the model. For i2_s the
# preset generator covers BitNet-b1.58-2B-4T. This writes headers into
# 3rdparty/llama.cpp that the CMake build then compiles in.
if [ -f "$BITNET_DIR/utils/codegen_tl1.py" ]; then
    ( cd "$BITNET_DIR" && python3 utils/codegen_tl1.py \
        --model bitnet_b1_58-2B-4T --BM 256,128,256 --BK 128,64,128 --bm 32,32,32 \
        || echo "    (codegen_tl1 skipped/failed — i2_s uses preset kernels)" )
fi

LLAMA_DIR="$BITNET_DIR/3rdparty/llama.cpp"
[ -d "$LLAMA_DIR" ] || LLAMA_DIR="$BITNET_DIR"   # fallback if layout differs

# ---- 3. per-platform CMake build of the static libs ------------------------
build_platform() {
    local name="$1" sysroot="$2" arch="$3"
    local bdir="$WORK/build-$name"
    echo "==> building $name ($arch, $sysroot)"
    rm -rf "$bdir"

    cmake -S "$BITNET_DIR" -B "$bdir" -G Xcode \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT="$sysroot" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
        -DBUILD_SHARED_LIBS=OFF \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=OFF \
        -DGGML_METAL=OFF \
        -DGGML_ACCELERATE=ON \
        -DBITNET_ARM_TL1="${BITNET_ARM_TL1:-ON}"

    cmake --build "$bdir" --config Release --target llama -- -quiet

    # Compile our wrapper against the llama headers for the same target.
    local iphoneos_sdk
    iphoneos_sdk="$(xcrun --sdk "$sysroot" --show-sdk-path)"
    local target_triple="arm64-apple-ios${MIN_IOS}"
    [ "$sysroot" = "iphonesimulator" ] && target_triple="arm64-apple-ios${MIN_IOS}-simulator"

    xcrun --sdk "$sysroot" clang++ -c "$WRAPPER_SRC" \
        -o "$bdir/nava_bitnet.o" \
        -std=c++17 -O3 -fembed-bitcode=off \
        -isysroot "$iphoneos_sdk" -target "$target_triple" \
        -I "$LLAMA_DIR/include" -I "$LLAMA_DIR/ggml/include" -I "$HEADER_DIR"

    # Bundle llama + ggml + wrapper into one fat static lib.
    local libs
    libs="$(find "$bdir" -name 'libllama.a' -o -name 'libggml*.a' | tr '\n' ' ')"
    local combined="$WORK/lib-$name.a"
    libtool -static -o "$combined" $libs "$bdir/nava_bitnet.o"
    echo "$combined"
}

DEVICE_LIB="$(build_platform device iphoneos arm64 | tail -n1)"
SIM_LIB="$(build_platform simulator iphonesimulator arm64 | tail -n1)"

# ---- 4. assemble the xcframework -------------------------------------------
rm -rf "$OUT_XCFRAMEWORK"
mkdir -p "$PKG_DIR/Frameworks"
xcodebuild -create-xcframework \
    -library "$DEVICE_LIB" -headers "$HEADER_DIR" \
    -library "$SIM_LIB"    -headers "$HEADER_DIR" \
    -output "$OUT_XCFRAMEWORK"

echo "==> done: $OUT_XCFRAMEWORK"
echo "    Swift can now 'import BitNetCore'. Build the app in Xcode."
