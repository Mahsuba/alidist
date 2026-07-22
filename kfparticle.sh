package: KFParticle
version: "%(tag_basename)s"
tag: v1.1-alice9
source: https://github.com/alisw/KFParticle
requires:
  - ROOT
  - "GCC-Toolchain:(?!osx)"
  - Vc
license: GPL-3.0
build_requires:
  - CMake
  - ninja
  - alibuild-recipe-tools
prepend_path:
  ROOT_INCLUDE_PATH: "$KFPARTICLE_ROOT/include"
---
#!/bin/bash -e

# KFParticle calls x86-only SSE intrinsics (_mm_malloc/_mm_free) directly in
# several of its own headers for aligned SIMD memory allocation. These don't
# exist at all on riscv64. Rather than patching KFParticle's own upstream
# headers, provide a tiny portable shim (posix_memalign/free, standard on
# every platform) and force it into every compile via -include.
RISCV64_MM_MALLOC_SHIM=""
case $ARCHITECTURE in
  *_riscv64)
    RISCV64_MM_MALLOC_SHIM="$PWD/mm_malloc_shim.h"
    cat > "$RISCV64_MM_MALLOC_SHIM" << 'SHIM_EOF'
#pragma once
#include <cstdlib>
static inline void* _mm_malloc(size_t size, size_t align) {
  if (align < sizeof(void*)) align = sizeof(void*);
  void* ptr = nullptr;
  if (posix_memalign(&ptr, align, size) != 0) return nullptr;
  return ptr;
}
static inline void _mm_free(void* ptr) {
  free(ptr);
}
SHIM_EOF
    ;;
esac

cmake $SOURCEDIR                                        \
      -G Ninja                                          \
      ${VC_REVISION:+-DVc_INCLUDE_DIR=$VC_ROOT/include} \
      ${VC_VERSIOM:+-DVc_LIBRARIES=$VCROOT/lib/libVc.a} \
      -DCMAKE_INSTALL_PREFIX="$INSTALLROOT"             \
      -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"            \
      "${RISCV64_MM_MALLOC_SHIM:+-DCMAKE_CXX_FLAGS=-include $RISCV64_MM_MALLOC_SHIM}" \
      -DFIXTARGET=FALSE
cmake --build . -- ${JOBS+-j $JOBS} install

# Modulefile
MODULEDIR="$INSTALLROOT/etc/modulefiles"
MODULEFILE="$MODULEDIR/$PKGNAME"
mkdir -p "$MODULEDIR"
cat > "$MODULEFILE" <<EoF
$(alibuild-generate-module --bin --lib --root)
# Our environment
setenv KFPARTICLE_ROOT \$PKG_ROOT
EoF
