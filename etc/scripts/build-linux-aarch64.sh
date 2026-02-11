#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"

SRC_HOME="$repo_root/src-homebrew/src"
SRC_XPDF="$repo_root/src-xpdf"

BUILD_ROOT=${BUILD_ROOT:-/tmp/scancode-build}
PREFIX=${PREFIX:-/tmp/scancode-prefix}

mkdir -p "$BUILD_ROOT" "$PREFIX"

pick_python() {
  for py in \
    /opt/python/cp314-cp314/bin/python \
    /opt/python/cp313-cp313/bin/python \
    /opt/python/cp312-cp312/bin/python \
    /opt/python/cp311-cp311/bin/python \
    /opt/python/cp310-cp310/bin/python; do
    if [ -x "$py" ]; then
      echo "$py"
      return 0
    fi
  done
  echo "python3"
}

PYTHON_BIN=$(pick_python)

log() {
  printf "\n==> %s\n" "$1"
}

ensure_python_build_tools() {
  log "Ensure Python build tooling"
  "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "$PYTHON_BIN" -m pip install --upgrade pip setuptools wheel
}

extract_tar() {
  local archive=$1
  local dest=$2
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xf "$archive" -C "$dest" --strip-components=1
}

pick_lib() {
  local pattern=$1
  local match
  match=$(ls -1 $pattern 2>/dev/null | head -n 1 || true)
  if [ -z "$match" ]; then
    echo "ERROR: no match for $pattern" >&2
    exit 1
  fi
  echo "$match"
}

build_zlib() {
  log "Build zlib"
  local src="$BUILD_ROOT/zlib"
  extract_tar "$SRC_HOME/zlib-1.2.11.tar.gz" "$src"
  pushd "$src" >/dev/null
  ./configure --prefix="$PREFIX"
  make -j"$(nproc)"
  make install
  popd >/dev/null
}

build_bzip2() {
  log "Build bzip2"
  local src="$BUILD_ROOT/bzip2"
  extract_tar "$SRC_HOME/bzip2-1.0.8.tar.gz" "$src"
  pushd "$src" >/dev/null
  make -f Makefile-libbz2_so -j"$(nproc)"
  mkdir -p "$PREFIX/lib"
  cp -f libbz2.so.1.0.8 "$PREFIX/lib/"
  popd >/dev/null
}

build_libb2() {
  log "Build libb2"
  local src="$BUILD_ROOT/libb2"
  extract_tar "$SRC_HOME/libb2-0.98.1.tar.gz" "$src"
  pushd "$src" >/dev/null
  ./configure --prefix="$PREFIX" --enable-shared --disable-static
  make -j"$(nproc)"
  make install
  popd >/dev/null
}

build_lz4() {
  log "Build lz4"
  local src="$BUILD_ROOT/lz4"
  extract_tar "$SRC_HOME/lz4-1.9.3.tar.gz" "$src"
  pushd "$src" >/dev/null
  make -j"$(nproc)"
  make PREFIX="$PREFIX" install
  popd >/dev/null
}

build_xz() {
  log "Build xz"
  local src="$BUILD_ROOT/xz"
  extract_tar "$SRC_HOME/xz-5.2.5.tar.gz" "$src"
  pushd "$src" >/dev/null
  ./configure --prefix="$PREFIX" --enable-shared --disable-static
  make -j"$(nproc)"
  make install
  popd >/dev/null
}

build_zstd() {
  log "Build zstd"
  local src="$BUILD_ROOT/zstd"
  extract_tar "$SRC_HOME/zstd-1.4.8.tar.gz" "$src"
  pushd "$src" >/dev/null
  make -j1 BUILD_SHARED=1 lib
  make -j1 PREFIX="$PREFIX" install
  popd >/dev/null
}

build_expat() {
  log "Build expat"
  local src="$BUILD_ROOT/expat"
  extract_tar "$SRC_HOME/expat-2.2.10.tar.xz" "$src"
  pushd "$src" >/dev/null
  ./configure --prefix="$PREFIX" --enable-shared --disable-static
  make -j"$(nproc)"
  make install
  popd >/dev/null
}

build_libarchive() {
  log "Build libarchive"
  local src="$BUILD_ROOT/libarchive"
  extract_tar "$SRC_HOME/libarchive-3.5.1.tar.xz" "$src"
  pushd "$src" >/dev/null
  ac_cv_sizeof_wchar_t=4 \
  ac_cv_have_decl_wchar_t=yes \
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
  CPPFLAGS="-I$PREFIX/include" \
  LDFLAGS="-L$PREFIX/lib" \
    ./configure \
      --prefix="$PREFIX" \
      --enable-shared \
      --disable-static \
      --without-xml2 \
      --without-openssl \
      --without-nettle
  make -j"$(nproc)"
  make install
  popd >/dev/null
}

build_file() {
  log "Build libmagic"
  local src="$BUILD_ROOT/file"
  extract_tar "$SRC_HOME/file-5.39.tar.gz" "$src"
  pushd "$src" >/dev/null
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
  CPPFLAGS="-I$PREFIX/include" \
  LDFLAGS="-L$PREFIX/lib" \
    ./configure --prefix="$PREFIX" --enable-shared --disable-static
  make -j"$(nproc)"
  make install
  popd >/dev/null
}

build_p7zip() {
  log "Build p7zip"
  local url="${SEVENZIP_URL:-https://www.7-zip.org/a/7z2501-linux-arm64.tar.xz}"
  local archive="$BUILD_ROOT/7zip-linux-arm64.tar.xz"
  local src="$BUILD_ROOT/7zip"
  if [ ! -f "$archive" ]; then
    curl -L "$url" -o "$archive"
  fi
  rm -rf "$src"
  mkdir -p "$src"
  tar -xf "$archive" -C "$src"
  if [ ! -x "$src/7zzs" ] && [ ! -x "$src/7zz" ]; then
    echo "ERROR: 7-Zip binaries not found in $archive" >&2
    exit 1
  fi
}

build_xpdf() {
  log "Build xpdf pdftotext"
  local src="$BUILD_ROOT/xpdf"
  extract_tar "$SRC_XPDF/xpdf-4.03.tar.gz" "$src"
  pushd "$src" >/dev/null
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  cmake --build build --target pdftotext -j"$(nproc)"
  popd >/dev/null
}

build_libdwarf() {
  log "Build libdwarf/dwarfdump"
  local src="$BUILD_ROOT/libdwarf"
  local url=${LIBDWARF_URL:-"https://github.com/davea42/libdwarf-code/releases/download/v0.10.1/libdwarf-0.10.1.tar.xz"}
  local archive="$BUILD_ROOT/libdwarf-0.10.1.tar.xz"
  if [ ! -f "$archive" ]; then
    curl -L "$url" -o "$archive"
  fi
  extract_tar "$archive" "$src"
  pushd "$src" >/dev/null
  ./configure --prefix="$PREFIX" --enable-shared --disable-static
  make -j"$(nproc)"
  make install
  popd >/dev/null
}

patch_libarchive_tree() {
  log "Patch libarchive plugin"
  local lib_dir="$repo_root/builtins/extractcode_libarchive-linux/src/extractcode_libarchive/lib"
  mkdir -p "$lib_dir"

  cp -f "$(pick_lib "$PREFIX/lib/libarchive.so.*")" "$lib_dir/libarchive.so"
  cp -f "$(pick_lib "$PREFIX/lib/libb2.so.*")" "$lib_dir/libb2-la3511.so.1"
  cp -f "$(pick_lib "$PREFIX/lib/libbz2.so.*")" "$lib_dir/libbz2-la3511.so.1.0"
  cp -f "$(pick_lib "$PREFIX/lib/libexpat.so.*")" "$lib_dir/libexpat-la3511.so.1"
  cp -f "$(pick_lib "$PREFIX/lib/liblz4.so.*")" "$lib_dir/liblz4-la3511.so.1"
  cp -f "$(pick_lib "$PREFIX/lib/liblzma.so.*")" "$lib_dir/liblzma-la3511.so.5"
  cp -f "$(pick_lib "$PREFIX/lib/libz.so.*")" "$lib_dir/libz-la3511.so.1"
  cp -f "$(pick_lib "$PREFIX/lib/libzstd.so.*")" "$lib_dir/libzstd-la3511.so.1"

  patchelf --set-soname libarchive.so "$lib_dir/libarchive.so"
  patchelf --set-rpath '$ORIGIN/.' "$lib_dir/libarchive.so"
  patchelf --replace-needed libb2.so.1 libb2-la3511.so.1 "$lib_dir/libarchive.so" || true
  patchelf --replace-needed libbz2.so.1.0 libbz2-la3511.so.1.0 "$lib_dir/libarchive.so" || true
  patchelf --replace-needed libexpat.so.1 libexpat-la3511.so.1 "$lib_dir/libarchive.so" || true
  patchelf --replace-needed liblz4.so.1 liblz4-la3511.so.1 "$lib_dir/libarchive.so" || true
  patchelf --replace-needed liblzma.so.5 liblzma-la3511.so.5 "$lib_dir/libarchive.so" || true
  patchelf --replace-needed libz.so.1 libz-la3511.so.1 "$lib_dir/libarchive.so" || true
  patchelf --replace-needed libzstd.so.1 libzstd-la3511.so.1 "$lib_dir/libarchive.so" || true

  patchelf --set-soname libb2-la3511.so.1 "$lib_dir/libb2-la3511.so.1"
  patchelf --set-soname libbz2-la3511.so.1.0 "$lib_dir/libbz2-la3511.so.1.0"
  patchelf --set-soname libexpat-la3511.so.1 "$lib_dir/libexpat-la3511.so.1"
  patchelf --set-soname liblz4-la3511.so.1 "$lib_dir/liblz4-la3511.so.1"
  patchelf --set-soname liblzma-la3511.so.5 "$lib_dir/liblzma-la3511.so.5"
  patchelf --set-soname libz-la3511.so.1 "$lib_dir/libz-la3511.so.1"
  patchelf --set-soname libzstd-la3511.so.1 "$lib_dir/libzstd-la3511.so.1"
}

patch_libmagic_tree() {
  log "Patch libmagic plugin"
  local lib_dir="$repo_root/builtins/typecode_libmagic-linux/src/typecode_libmagic/lib"
  local data_dir="$repo_root/builtins/typecode_libmagic-linux/src/typecode_libmagic/data"
  mkdir -p "$lib_dir" "$data_dir"

  cp -f "$(pick_lib "$PREFIX/lib/libmagic.so.*")" "$lib_dir/libmagic.so"
  cp -f "$(pick_lib "$PREFIX/lib/libz.so.*")" "$lib_dir/libz-lm539.so.1"
  cp -f "$PREFIX/share/misc/magic.mgc" "$data_dir/magic.mgc"

  patchelf --set-soname libmagic.so.1 "$lib_dir/libmagic.so"
  patchelf --set-rpath '$ORIGIN/.' "$lib_dir/libmagic.so"
  patchelf --replace-needed libz.so.1 libz-lm539.so.1 "$lib_dir/libmagic.so" || true
  patchelf --set-soname libz-lm539.so.1 "$lib_dir/libz-lm539.so.1"
}

patch_p7zip_tree() {
  log "Patch p7zip plugin"
  local bin_dir="$repo_root/builtins/extractcode_7z-linux/src/extractcode_7z/bin"
  local license_dir="$repo_root/builtins/extractcode_7z-linux/src/extractcode_7z/licenses/7zip"
  mkdir -p "$bin_dir"
  mkdir -p "$license_dir"
  local src="$BUILD_ROOT/7zip"
  local sevenz=""
  local sevenzso=""
  local sevenza
  if [ -x "$src/7zzs" ]; then
    sevenz="$src/7zzs"
  elif [ -x "$src/7zz" ]; then
    sevenz="$src/7zz"
  fi
  if [ -z "$sevenz" ] && [ -x /usr/bin/7z ]; then
    sevenz=/usr/bin/7z
  fi
  if [ -z "$sevenz" ] && [ -x /usr/bin/7za ]; then
    sevenz=/usr/bin/7za
  fi
  if [ -z "$sevenz" ]; then
    echo "ERROR: could not find 7-Zip binary" >&2
    exit 1
  fi
  cp -f "$sevenz" "$bin_dir/7z"
  chmod 755 "$bin_dir/7z"
  if [ -d "$src" ]; then
    for f in License.txt readme.txt History.txt; do
      if [ -f "$src/$f" ]; then
        cp -f "$src/$f" "$license_dir/$f"
      fi
    done
  fi
}

patch_xpdf_tree() {
  log "Patch xpdf plugin"
  local bin_dir="$repo_root/builtins/textcode_pdf2text-linux/src/textcode_pdf2text/bin"
  mkdir -p "$bin_dir"
  local src="$BUILD_ROOT/xpdf"
  local pdftotext
  pdftotext=$(find "$src" -type f -name pdftotext -perm -111 | head -n 1)
  if [ -z "$pdftotext" ]; then
    echo "ERROR: could not find pdftotext in xpdf build" >&2
    exit 1
  fi
  cp -f "$pdftotext" "$bin_dir/pdftotext"
  chmod 755 "$bin_dir/pdftotext"
}

patch_binary_analysis() {
  log "Patch binary-analysis plugins"
  local ctags_bin="$repo_root/binary-analysis/scancode-ctags-linux/src/scancode_ctags/bin"
  local readelf_bin="$repo_root/binary-analysis/scancode-readelf-linux/src/scancode_readelf/bin"
  local dwarf_bin="$repo_root/binary-analysis/scancode-dwarfdump-linux/src/scancode_dwarfdump/bin"
  mkdir -p "$ctags_bin" "$readelf_bin" "$dwarf_bin"

  if [ -x /usr/bin/ctags ]; then
    cp -f /usr/bin/ctags "$ctags_bin/ctags"
  else
    echo "ERROR: /usr/bin/ctags not found" >&2
    exit 1
  fi
  cp -f /usr/bin/readelf "$readelf_bin/readelf"
  cp -f /usr/bin/c++filt "$readelf_bin/c++filt"

  local dwarfdump="$PREFIX/bin/dwarfdump"
  if [ -x "$dwarfdump" ]; then
    cp -f "$dwarfdump" "$dwarf_bin/dwarfdump2"
  else
    echo "ERROR: dwarfdump not found at $dwarfdump" >&2
    exit 1
  fi

  cp -f /usr/lib64/libelf.so.1 "$dwarf_bin/libelf.so.0"
  cp -f /usr/lib64/libelf.so.1 "$dwarf_bin/libelf.so.0.8.10"
  ln -sf libelf.so.0 "$dwarf_bin/libelf.so"
  patchelf --set-soname libelf.so.0 "$dwarf_bin/libelf.so.0" || true
  patchelf --set-rpath '$ORIGIN' "$dwarf_bin/dwarfdump2" || true
  patchelf --replace-needed libelf.so.1 libelf.so.0 "$dwarf_bin/dwarfdump2" || true
  cp -f /usr/bin/nm "$dwarf_bin/nm-new"

  chmod 755 "$ctags_bin/ctags" "$readelf_bin/readelf" "$readelf_bin/c++filt" "$dwarf_bin/dwarfdump2" "$dwarf_bin/nm-new" || true
}

build_wheels() {
  log "Build manylinux2014_aarch64 wheels"
  local dist_dir="$repo_root/dist"
  mkdir -p "$dist_dir"
  local plugins=(
    builtins/extractcode_7z-linux
    builtins/extractcode_libarchive-linux
    builtins/textcode_pdf2text-linux
    builtins/typecode_libmagic-linux
    binary-analysis/scancode-ctags-linux
    binary-analysis/scancode-dwarfdump-linux
    binary-analysis/scancode-readelf-linux
  )

  for plugin in "${plugins[@]}"; do
    log "Wheel: $plugin"
    pushd "$repo_root/$plugin" >/dev/null
    rm -rf dist build
    "$PYTHON_BIN" setup.py clean --all bdist_wheel --plat-name manylinux2014_aarch64 --python-tag py3
    cp -f dist/*.whl "$dist_dir/"
    popd >/dev/null
  done
}

main() {
  if [ ! -d "$SRC_HOME" ] || [ ! -d "$SRC_XPDF" ]; then
    echo "ERROR: expected src-homebrew/src and src-xpdf under $repo_root" >&2
    exit 1
  fi

  build_zlib
  build_bzip2
  build_libb2
  build_lz4
  build_xz
  build_zstd
  build_expat
  build_libarchive

  build_file
  build_p7zip
  build_xpdf
  build_libdwarf

  patch_libarchive_tree
  patch_libmagic_tree
  patch_p7zip_tree
  patch_xpdf_tree
  patch_binary_analysis

  ensure_python_build_tools
  build_wheels
}

main "$@"
