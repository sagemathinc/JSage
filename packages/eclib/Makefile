BUILD = build
CWD = $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
DIST = ${CWD}/dist
DIST_NATIVE = ${DIST}/native
DIST_WASM = ${DIST}/wasm
DIST_JS = ${DIST}/js
ZCC = ${CWD}/../../bin/zcc
ZXX = ${CWD}/../../bin/z++

GMP = ${CWD}/../gmp/dist
MPFR = ${CWD}/../mpfr/dist
PARI = ${CWD}/../pari/dist
NTL = ${CWD}/../ntl/dist
FLINT = ${CWD}/../flint/dist

all: ${DIST_NATIVE}/.built ${DIST_WASM}/.built

${BUILD}/eclib:
	mkdir -p ${BUILD}
	cd ${BUILD} && git clone https://github.com/JohnCremona/eclib.git && cd eclib

.PHONY: source
source: ${BUILD}/eclib


## Native library

${BUILD}/native: ${BUILD}/eclib
	rm -rf ${BUILD}/native
	cd ${BUILD} && git clone eclib native && cd native && ./autogen.sh

${DIST_NATIVE}/.built: ${BUILD}/native
	cd ${BUILD}/native && \
		CXXFLAGS="-I${GMP}/native/include  -I${MPFR}/native/include"  LDFLAGS="-L${GMP}/native/lib  -L${MPFR}/native/lib" \
		CC="zig cc" CXX="zig c++" AR="zig ar" RANLIB="zig ranlib"  \
		./configure \
			--with-pari=${PARI}/native  \
			--with-ntl=${NTL}/native    \
			--with-flint=${FLINT}/native   \
			--prefix=${DIST_NATIVE}
	# A hack -- change the empty BOOST_LIBS to let us link in gmp.
	cd ${BUILD}/native && make -j8 BOOST_LIBS="-lgmp -lmpfr" PTHREAD_CFLAGS=""
	cd ${BUILD}/native && make BOOST_LIBS="-lgmp -lmpfr" PTHREAD_CFLAGS="" install
	touch ${DIST_NATIVE}/.built

.PHONY: native
native: ${DIST_NATIVE}/.built


## WebAssembly library

${BUILD}/wasm: ${BUILD}/eclib
	rm -rf ${BUILD}/wasm
	cd ${BUILD} && git clone eclib wasm && cd wasm && ./autogen.sh

${DIST_WASM}/.built: ${BUILD}/wasm
	cd ${BUILD}/wasm && \
	CXXFLAGS="-I${GMP}/wasm/include  -I${MPFR}/wasm/include"  LDFLAGS="-L${GMP}/wasm/lib  -L${MPFR}/wasm/lib" \
	LIBS="-lgmp -lmpfr" \
	CC=${ZCC} CXX=${ZXX} AR="zig ar" RANLIB="zig ranlib" \
	./configure \
		--with-pari=${PARI}/wasm  \
		--with-ntl=${NTL}/wasm    \
		--with-flint=${FLINT}/wasm   \
		--prefix=${DIST_WASM} \
		--enable-shared=no \
		--enable-static=yes \
		--with-boost=no
	# We change PTHREAD_CFLAGS, which would be -pthread, which would break linking with all
	# our other libraries.   Also a hack -- change the empty BOOST_LIBS to let us link in gmp.
	cd ${BUILD}/wasm && make -j8 PTHREAD_CFLAGS="" BOOST_LIBS="-lgmp -lmpfr ${GMP}/wasm/lib/libgmp.a  ${PARI}/wasm/lib/libpari.a   ${NTL}/wasm/lib/libntl.a   ${FLINT}/wasm/lib/libflint.a  ${MPFR}/wasm/lib/libmpfr.a "
	cd ${BUILD}/wasm && make PTHREAD_CFLAGS="" BOOST_LIBS="-lgmp -lmpfr" install
	cp -v ${BUILD}/wasm/progs/*.wasm ${DIST_WASM}/bin
	touch ${DIST_WASM}/.built

.PHONY: wasm
wasm: ${DIST_WASM}/.built

clean:
	rm -rf ${DIST} ${BUILD} node_module