#!/bin/bash

wsm=./opt.wasm
wsm=./lsum.wasm

input0() {
	printf ''
}

input1() {
	printf '4200 0000 0000 0000' | xxd -r -ps
}

input2() {
	(
		printf '4200 0000 0000 0000'
		printf '4200 0000 0000 0000'
	) | xxd -r -ps
}

ints2longs64le(){
  ifun='import functools;'
  isys='import sys;'
  iopr='import operator;'
  istr='import struct;'

  imports="${ifun} ${isys} ${iopr} ${istr}"

  sdef='s = struct.Struct("<q");'

  python3 -c "${imports} ${sdef}"' functools.reduce(
    lambda state, f: f(state),
    [
      functools.partial(map, int),
      functools.partial(map, s.pack),
      functools.partial(map, sys.stdout.buffer.write),
      lambda w: sum(1 for _ in w),
    ],
    sys.stdin.buffer,
  )'
}

sum4human(){
  ifun='import functools;'
  isys='import sys;'
  iopr='import operator;'
  istr='import struct;'

  imports="${ifun} ${isys} ${iopr} ${istr}"

  sdef='s = struct.Struct("<q");'

  python3 -c "${imports} ${sdef}"' functools.reduce(
    lambda state, f: f(state),
    [
      s.unpack,
      operator.itemgetter(0),
      print,
    ],
    sys.stdin.buffer.read(8),
  )'
}

input8191() {
  (
    dd \
      if=/dev/zero \
      bs=8 \
      count=8190 \
      status=none;

    printf '4200 0000 0000 0000' | xxd -r -ps
  )
}

sum4wazero() {
	\time -l wazero run "${wsm}"
}

input16gib(){
  (
    dd if=/dev/zero bs=1048576 count=16383 status=progress
    printf '4200 0000 0000 0000' | xxd -r -ps
    printf '4200 0000 0000 0000' | xxd -r -ps
  )
}

input16gib | sum4wazero | sum4human
