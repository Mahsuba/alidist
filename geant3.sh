package: GEANT3
version: "%(tag_basename)s"
tag: v4-5
requires:
  - ROOT
  - VMC
license: LGPL-2.1
build_requires:
  - CMake
  - ninja-fortran
  - "Xcode:(osx.*)"
  - alibuild-recipe-tools
source: https://github.com/vmc-project/geant3
prepend_path:
  LD_LIBRARY_PATH: "$GEANT3_ROOT/lib64"
  ROOT_INCLUDE_PATH: "$GEANT3_ROOT/include/TGeant3"
---
#!/bin/bash -e

# added/dummies.c enables x86-only FPU exception trapping (via glibc's
# fpu_control.h _FPU_MASK_* macros, tied to the old x87 FPU control
# register format). It already excludes __ia64 and __aarch64__ for the
# same reason -- riscv64 has no equivalent mechanism either, so extend
# the same exclusion. This is a debug-only feature (trapping NaN/overflow
# during physics calculations), not something affecting simulation
# correctness -- already known-safe to skip on other architectures.
DUMMIES_C="$SOURCEDIR/added/dummies.c"
if [[ -f "$DUMMIES_C" ]]; then
  sed -i -e 's/!defined(__aarch64__))/!defined(__aarch64__) \&\& !defined(__riscv))/' "$DUMMIES_C"
fi

FVERSION=`gfortran --version | grep -i fortran | sed -e 's/.* //' | cut -d. -f1`
SPECIALFFLAGS=""
if [ $FVERSION -ge 10 ]; then
   echo "Fortran version $FVERSION"
   SPECIALFFLAGS=1
fi
cmake $SOURCEDIR -DCMAKE_INSTALL_PREFIX=$INSTALLROOT      \
                 -G Ninja                                 \
                 -DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE     \
                 ${CXXSTD:+-DCMAKE_CXX_STANDARD=$CXXSTD}  \
                 -DCMAKE_C_STANDARD=99                    \
                 -DCMAKE_SKIP_RPATH=TRUE \
                 ${SPECIALFFLAGS:+-DCMAKE_Fortran_FLAGS="-fallow-argument-mismatch -fallow-invalid-boz -fno-tree-loop-distribute-patterns"}

cmake --build . -- ${JOBS+-j $JOBS} install

[[ ! -d $INSTALLROOT/lib64 ]] && ln -sf lib $INSTALLROOT/lib64

# Modulefile
MODULEDIR="$INSTALLROOT/etc/modulefiles"
MODULEFILE="$MODULEDIR/$PKGNAME"
mkdir -p "$MODULEDIR"
cat > "$MODULEFILE" <<EoF
$(alibuild-generate-module --lib)
# Our environment
setenv GEANT3_ROOT \$PKG_ROOT
setenv GEANT3DIR \$PKG_ROOT
setenv G3SYS \$PKG_ROOT
prepend-path LD_LIBRARY_PATH \$PKG_ROOT/lib64
prepend-path ROOT_INCLUDE_PATH \$PKG_ROOT/include/TGeant3
EoF
