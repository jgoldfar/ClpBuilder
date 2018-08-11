# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder

name = "SiloBuilder"
version = v"0.1.0"

# Collection of sources required to build SiloBuilder
sources = [
    "https://wci.llnl.gov/content/assets/docs/simulation/computer-codes/silo/silo-4.10.2/silo-4.10.2-bsd.tar.gz" =>
    "4b901dfc1eb4656e83419a6fde15a2f6c6a31df84edfad7f1dc296e01b20140e",

]

# Bash recipe for building across all platforms
script = raw"""
set -e

cd $WORKSPACE/srcdir/silo-4.10.2-bsd/
./configure --disable-silex --disable-browser --prefix=$prefix --enable-shared --host=$target



# We need to do some patching to cross-compile for mingw32
if [ $target = "x86_64-w64-mingw32" ] || [ $target = "i686-w64-mingw32" ]; then
CURRENTFILE=src/silo/silo_win32_compatibility.h
cp ${CURRENTFILE} ${CURRENTFILE}.orig
sed -e 's/#include <sys\types.h>/#include <sys\/types.h>/' -e 's/#include <sys\stat.h>/#include <sys\/stat.h>/' ${CURRENTFILE}.orig > ${CURRENTFILE}



CURRENTFILE=SiloWindows/include/config.h
cp ${CURRENTFILE} ${CURRENTFILE}.orig

# We don't have FPCLASS
sed 's/#define HAVE_FPCLASS 1/#define HAVE_FPCLASS 0/' ${CURRENTFILE}.orig > ${CURRENTFILE}



CURRENTFILE=tools/silock/silock.c
cp ${CURRENTFILE} ${CURRENTFILE}.orig

# Generate silock source file patch (we don't build silock)
cat > $WORKSPACE/silock.c.patch << 'END'
--- tools/silock/silock.c.orig
+++ tools/silock/silock.c
@@ -111,26 +111,7 @@
    static char lastDir[1024], lastVar[1024];
    char errMsg[128];
 
-   /* try to produce a useful error message regarding the kind of NaN */
-#ifdef HAVE_FPCLASS
-   {  fpclass_t theClass = fpclass(value);
-      switch (theClass)
-      {
-      case FP_SNAN:    strcpy(errMsg,"signaling NaN"); break;
-      case FP_QNAN:    strcpy(errMsg,"quiet NaN"); break;
-      case FP_NINF:    strcpy(errMsg,"negative infinity"); break;
-      case FP_PINF:    strcpy(errMsg,"positive infinity"); break;
-      case FP_NDENORM: strcpy(errMsg,"negative denormalized non-zero"); break;
-      case FP_PDENORM: strcpy(errMsg,"positive denormalized non-zero"); break;
-      case FP_NZERO:   strcpy(errMsg,"negative zero"); break;
-      case FP_PZERO:   strcpy(errMsg,"positive zero"); break;
-      case FP_NNORM:   strcpy(errMsg,"negative normalized non-zero"); break;
-      case FP_PNORM:   strcpy(errMsg,"positive normalized non-zero"); break;
-      }
-   }
-#else
    strcpy(errMsg, "unkown NaN");
-#endif
 
    if (!disableVerbose)
    {
END

# Patch silock source file
patch -l ${CURRENTFILE}.orig $WORKSPACE/silock.c.patch -o ${CURRENTFILE}



# Generate Silock Makefile patch (we don't build silock)
CURRENTFILE=tools/silock/Makefile
cp ${CURRENTFILE} ${CURRENTFILE}.orig
cat > $WORKSPACE/silock-Makefile.patch << 'END'
--- tools/silock/Makefile.orig
+++ tools/silock/Makefile
@@ -401,7 +401,6 @@
        rm -f $$list
 silock$(EXEEXT): $(silock_OBJECTS) $(silock_DEPENDENCIES) 
        @rm -f silock$(EXEEXT)
-       $(CXXLINK) $(silock_OBJECTS) $(silock_LDADD) $(LIBS)
 
 mostlyclean-compile:
        -rm -f *.$(OBJEXT)
END

# Patch silock Makefile
patch -l ${CURRENTFILE}.orig $WORKSPACE/silock-Makefile.patch -o ${CURRENTFILE}

fi

make VERBOSE=1
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Linux(:i686, :glibc),
    Linux(:x86_64, :glibc),
    Linux(:armv7l, :glibc, :eabihf),
    Linux(:powerpc64le, :glibc),
    MacOS(:x86_64)
]

# The products that we will ensure are always built
products(prefix) = [
    LibraryProduct(prefix, "libsilo", :libsilo)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)

