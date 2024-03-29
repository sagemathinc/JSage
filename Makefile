BUILT = dist/.built

CWD = $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

export PATH := ${CWD}/packages/zig/dist:$(PATH)

all: lib/${BUILT} packages/jpython/${BUILT}

.PHONY: zig
zig:
	cd packages/zig && make

packages/gmp/${BUILT}: zig
	cd packages/gmp && make all
.PHONY: gmp
gmp: packages/gmp/${BUILT}

packages/mpfr/${BUILT}: packages/gmp/${BUILT} zig
	cd packages/mpfr && make all
.PHONY: mpfr
mpfr: packages/mpfr/${BUILT}

packages/mpc/${BUILT}: packages/gmp/${BUILT} packages/mpfr/${BUILT} zig
	cd packages/mpc && make all
.PHONY: mpc
mpc: packages/mpc/${BUILT}

packages/gf2x/${BUILT}: zig wasi
	cd packages/gf2x && make all
.PHONY: gf2x
gf2x: packages/gf2x/${BUILT}

packages/ntl/${BUILT}: wasi packages/gmp/${BUILT} packages/gf2x/${BUILT} zig
	cd packages/ntl && make all
.PHONY: ntl
ntl: packages/ntl/${BUILT}

packages/flint/${BUILT}: packages/gmp/${BUILT} packages/mpfr/${BUILT} packages/ntl/${BUILT} zig
	cd packages/flint && make all
.PHONY: flint
flint: packages/flint/${BUILT}

packages/wasm-posix/${BUILT}: zig
	cd packages/wasm-posix && make all
.PHONY: wasm-posix
wasm-posix: packages/wasm-posix/${BUILT}

packages/pari/${BUILT}: wasi packages/gmp/${BUILT} packages/wasm-posix/${BUILT} zig
	cd packages/pari && make all
.PHONY: pari
pari: packages/pari/${BUILT}

packages/eclib/${BUILT}: wasi packages/gmp/${BUILT} packages/mpfr/${BUILT} packages/pari/${BUILT} packages/ntl/${BUILT} packages/flint/${BUILT} zig
	cd packages/eclib && make all
.PHONY: eclib
eclib: packages/eclib/${BUILT}

lib/${BUILT}: packages/gmp/${BUILT} packages/pari/${BUILT} wasi zig # packages/python/${BUILT}
	cd lib && make all
.PHONY: lib
lib: lib/${BUILT}


# Included here since I did the work, but we're not using it.
packages/openssl/${BUILT}: zig
	cd packages/openssl && make all
.PHONY: openssl
openssl: packages/openssl/${BUILT}


packages/zlib/${BUILT}: zig
	cd packages/zlib && make all
.PHONY: zlib
zlib: packages/zlib/${BUILT}


packages/python/${BUILT}: packages/zlib/${BUILT} packages/wasm-posix/${BUILT} zig
	cd packages/python && make all
.PHONY: python
python: packages/python/${BUILT}

packages/jpython/${BUILT}: lib/${BUILT}
	cd packages/jpython && make all
.PHONY: jpython
jpython: packages/jpython/${BUILT}


packages/wasi/${BUILT}: lib/${BUILT}
	cd packages/wasi && make all
.PHONY: wasi
wasi: packages/wasi/${BUILT}


.PHONY: docker
docker:
	docker build --build-arg commit=`git ls-remote -h https://github.com/sagemathinc/jsage master | awk '{print $$1}'` -t jsage .

.PHONY: docker-nocache
docker-nocache:
	docker build --no-cache -t jsage .

clean:
	cd packages/gmp && make clean
	cd packages/gf2x && make clean
	cd packages/mpfr && make clean
	cd packages/mpc && make clean
	cd packages/ntl && make clean
	cd packages/flint && make clean
	cd packages/pari && make clean
	cd packages/eclib && make clean
	cd packages/wasi && make clean
	cd packages/jpython && make clean
	cd packages/python && make clean
	cd packages/openssl && make clean
	cd packages/zlib && make clean
	cd packages/wasm-posix && make clean
	cd packages/zig && make clean
	cd lib && make clean

