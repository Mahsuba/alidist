package: EPOS4
version: "%(tag_basename)s"
tag: "v4.0.3-alice6"
source: https://github.com/alisw/EPOS4.git
requires:
  - ROOT
  - fastjet
  - HepMC3
  - alibuild-recipe-tools
license: GPL-2.0
env:
  EPO4VSN: "4.0.3"
---
#!/bin/bash -ex

export CC=gcc
export CXX=g++
export FC=gfortran
export COP=BASIC

# EPOS4's CMakeLists only enables its compile flags (including -cpp, needed
# to process #include in the Fortran sources) on x86_64/aarch64; on other
# arches the flags are silently skipped and compilation fails with missing
# parameters (kollmx etc). Add riscv64 to all three arch guards, and use
# -mcmodel=medany instead of -mcmodel=large (not supported by riscv64 gcc).
if [[ $ARCHITECTURE == *riscv64* ]]; then
  sed -i -e 's/MATCHES "x86_64|aarch64"/MATCHES "x86_64|aarch64|riscv64"/g' \
         -e 's/-mcmodel=large/-mcmodel=medany/g' \
         ${SOURCEDIR}/CMakeLists.txt
fi

export LIBRARY_PATH="$LD_LIBRARY_PATH"
cmake -S ${SOURCEDIR} -DCMAKE_INSTALL_PREFIX=${INSTALLROOT} \
          -DCOMPILE_OPTION=${COP} -DCMAKE_BUILD_TYPE=Release \
          -DFASTSYS=$FASTJET \
          -DCMAKE_INSTALL_MESSAGE=LAZY
cmake --build . -- ${JOBS:+-j $JOBS}
cmake --install .
if [[ $ALIBUILD_O2_TESTS ]]; then
  ctest --test-dir . --verbose
fi

rsync -a \
      --exclude='**/CMakeModules' \
      --exclude=CMakeLists.txt \
      --exclude='**/.git' \
      --exclude=*.h \
      --exclude=*.c \
      --exclude=*.cpp \
      --exclude=*.f \
      $SOURCEDIR/ $INSTALLROOT/

# Modulefile
MODULEDIR="$INSTALLROOT/etc/modulefiles"
MODULEFILE="$MODULEDIR/$PKGNAME"
mkdir -p "$MODULEDIR"
alibuild-generate-module --lib --bin >$MODULEFILE
cat >> "$MODULEFILE" <<EoF
setenv EPOS4_ROOT \$PKG_ROOT
setenv EPO4VSN 4.0.3
# Final slash is required by EPOS, please leave it be
setenv EPO4 \$PKG_ROOT/
prepend-path PATH \$::env(EPO4)bin
setenv OPT ./
setenv HTO ./
setenv CHK ./
EoF
