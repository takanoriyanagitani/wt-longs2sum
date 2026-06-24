(module

  (memory 2)

  (func $v2lsum (export "v2lsum") (param $v v128) (result i64)
    local.get $v
    i64x2.extract_lane 0
    local.get $v
    i64x2.extract_lane 1
    i64.add
  )

  (func $buf2lsum (param $buf i32) (param $byte_len i32) (result i64 i32)
    ;; result:
    ;;   - i64: the sum
    ;;   - i32: 0 on no data, non-zero w/ data

    (local $sum i64)

    (local $cur_ptr i32)
    (local $end_ptr i32)

    (local $valid i32)

    i64.const 0
    local.set $sum

    local.get $buf
    local.tee $cur_ptr

    local.get $byte_len
    i32.const 3
    i32.shr_u
    i32.const 3
    i32.shl
    i32.add
    local.set $end_ptr

    i32.const 0
    local.set $valid

    loop
      local.get $end_ptr
      local.get $cur_ptr
      i32.le_u
      if
        local.get $sum
        local.get $valid
        return
      end

      local.get $cur_ptr
      i64.load
      local.get $sum
      i64.add
      local.set $sum

      i32.const 1
      local.set $valid

      local.get $cur_ptr
      i32.const 8
      i32.add
      local.set $cur_ptr

      br 0
    end

    unreachable
  )

  (func $t0a (export "t0a_buf2lsum_empty") (result i32)
    (local $ret i32)
    (local $sum i64)

    i32.const 0 ;; dummy
    i32.const 0
    call $buf2lsum
    local.set $ret
    local.set $sum

    local.get $ret
    i32.const 0
    i32.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $t0b (export "t0b_buf2lsum_too_small") (result i32)
    (local $ret i32)
    (local $sum i64)

    i32.const 0 ;; dummy
    i32.const 7
    call $buf2lsum
    local.set $ret
    local.set $sum

    local.get $ret
    i32.const 0
    i32.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $t0c (export "t0c_buf2lsum_single") (result i32)
    (local $ret i32)
    (local $sum i64)

    i32.const 0x0001_0000
    i64.const 42
    i64.store

    i32.const 0x0001_0000
    i32.const 8
    call $buf2lsum
    local.set $ret
    local.set $sum

    local.get $ret
    i32.eqz
    if
      i32.const 1
      return
    end

    local.get $sum
    i64.const 42
    i64.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $t0d (export "t0d_buf2lsum_page") (result i32)
    (local $ret i32)
    (local $sum i64)

    (local $cnt i32)

    i32.const 0
    local.set $cnt

    loop
      i32.const 0x0001_0000
      local.get $cnt
      i32.const 3
      i32.shl
      i32.add
      local.get $cnt
      i64.extend_i32_u
      i64.store

      local.get $cnt
      i32.const 1
      i32.add
      local.tee $cnt
      i32.const 8192
      i32.lt_u
      br_if 0
    end

    i32.const 0x0001_0000
    i32.const 65536
    call $buf2lsum
    local.set $ret
    local.set $sum

    local.get $ret
    i32.eqz
    if
      i32.const 1
      return
    end

    local.get $sum
    i64.const 8191
    i64.const 8192
    i64.mul
    i64.const 2
    i64.div_u ;; sum(0,1,2, ..., 8191) = 0.5(8191*8192)
    i64.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $page2sum_simd_unroll0 (param $page i32) (result v128)
    (local $end_ptr i32)
    (local $cur_ptr i32)

    (local $sum v128)

    local.get $page
    local.tee $cur_ptr

    i32.const 65536
    i32.add
    local.set $end_ptr

    v128.const i64x2 0 0
    local.set $sum

    loop
      local.get $end_ptr
      local.get $cur_ptr
      i32.le_u
      if
        local.get $sum
        return
      end

      local.get $cur_ptr
      v128.load
      local.get $sum
      i64x2.add
      local.set $sum

      local.get $cur_ptr
      i32.const 16
      i32.add
      local.set $cur_ptr
      br 0
    end

    unreachable
  )

  (func $page2sum_simd_unroll8 (param $page i32) (result v128)
    (local $end_ptr i32)
    (local $cur_ptr i32)

    (local $sum v128)

    local.get $page
    local.tee $cur_ptr

    i32.const 65536
    i32.add
    local.set $end_ptr

    v128.const i64x2 0 0
    local.set $sum

    loop
      local.get $end_ptr
      local.get $cur_ptr
      i32.le_u
      if
        local.get $sum
        return
      end

      ;; sum vec 0, 1
      local.get $cur_ptr
      v128.load offset=0
      local.get $cur_ptr
      v128.load offset=16
      i64x2.add

      ;; sum vec 2, 3
      local.get $cur_ptr
      v128.load offset=32
      local.get $cur_ptr
      v128.load offset=48
      i64x2.add

      ;; sum vec 4, 5
      local.get $cur_ptr
      v128.load offset=64
      local.get $cur_ptr
      v128.load offset=80
      i64x2.add

      ;; sum vec 6, 7
      local.get $cur_ptr
      v128.load offset=96
      local.get $cur_ptr
      v128.load offset=112
      i64x2.add

      ;; sum vec (0,1), (2,3)
      i64x2.add
      ;; sum vec (4,5), (6,7)
      i64x2.add

      ;; sum vec (0,1,2,3), (4,5,6,7)
      i64x2.add

      local.get $sum
      i64x2.add
      local.set $sum

      local.get $cur_ptr
      i32.const 128
      i32.add
      local.set $cur_ptr
      br 0
    end

    unreachable
  )

  (func $page2sum_simd (param $page i32) (result v128)
    local.get $page
    ;;call $page2sum_simd_unroll0
    call $page2sum_simd_unroll8
  )

  (func $t10 (export "t10_page2sum_simd_zero") (result i32)
    i32.const 0x0001_0000
    i32.const 0
    i32.const 65536
    memory.fill

    i32.const 0x0001_0000
    call $page2sum_simd
    v128.const i64x2 0 0
    i64x2.eq
    i64x2.all_true
    i32.eqz
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $t11 (export "t11_page2sum_simd_8192") (result i32)
    (local $ret i32)
    (local $sum v128)

    (local $cnt i32)

    i32.const 0
    local.set $cnt

    loop
      i32.const 0x0001_0000
      local.get $cnt
      i32.const 3
      i32.shl
      i32.add
      local.get $cnt
      i64.extend_i32_u
      i64.store

      local.get $cnt
      i32.const 1
      i32.add
      local.tee $cnt
      i32.const 8192
      i32.lt_u
      br_if 0
    end

    i32.const 0x0001_0000
    call $page2sum_simd
    local.tee $sum
    i64x2.extract_lane 0
    local.get $sum
    i64x2.extract_lane 1
    i64.add
    i64.const 33550336
    i64.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  ;; Buf reader
  ;;   offset 0x00: fd
  ;;   offset 0x04: ptr to iovec
  ;;   offset 0x08: ptr to iobuf(at least 65536 bytes)
  ;;   offset 0x0c: ptr to bytes read(*ptr will be 0 on EOF)
  ;;   offset 0x10: num bytes copied
  ;;   offset 0x14: eof

  (func $bufrdr_init
    (param $this i32)
    (param $fd i32)
    (param $ptr2iovec i32)
    (param $ptr2iobuf i32)
    (param $ptr2bytes_read i32)

    local.get $this
    local.get $fd
    i32.store offset=0

    local.get $this
    local.get $ptr2iovec
    i32.store offset=4

    local.get $this
    local.get $ptr2iobuf
    i32.store offset=8

    local.get $this
    local.get $ptr2bytes_read
    i32.store offset=12

    local.get $this
    i32.const 0
    i32.store offset=16

    local.get $this
    i32.const 0
    i32.store offset=20
  )

  (func $bufrdr_reset_iovec_page
    (param $this i32)

    local.get $this
    call $bufrdr_get_iovec_ptr
    local.get $this
    call $bufrdr_get_iobuf_ptr
    i32.store

    local.get $this
    call $bufrdr_get_iovec_ptr
    i32.const 65536
    i32.store offset=4

    local.get $this
    i32.const 0
    call $bufrdr_set_num_bytes_read

    local.get $this
    i32.const 0
    i32.store offset=16
  )

  (func $bufrdr_get_fd (param $this i32) (result i32)
    local.get $this
    i32.load offset=0
  )

  (func $bufrdr_get_iovec_ptr (param $this i32) (result i32)
    local.get $this
    i32.load offset=4
  )

  (func $bufrdr_get_iobuf_ptr (param $this i32) (result i32)
    local.get $this
    i32.load offset=8
  )

  (func $bufrdr_get_bread_ptr (param $this i32) (result i32)
    local.get $this
    i32.load offset=12
  )

  (func $bufrdr_num_bytes_read (param $this i32) (result i32)
    local.get $this
    call $bufrdr_get_bread_ptr
    i32.load
  )

  (func $bufrdr_set_num_bytes_read (param $this i32) (param $i i32)
    local.get $this
    call $bufrdr_get_bread_ptr
    local.get $i
    i32.store
  )

  (func $bufrdr_num_bytes_copied (param $this i32) (result i32)
    local.get $this
    i32.load offset=16
  )

  (func $bufrdr_eof (param $this i32) (result i32)
    local.get $this
    i32.load offset=20
  )

  (func $bufrdr_remaining_bytes (param $this i32) (result i32)
    (local $bytes_read_last i32)
    (local $bytes_copied i32)

    local.get $this
    call $bufrdr_num_bytes_read
    local.set $bytes_read_last

    local.get $this
    call $bufrdr_num_bytes_copied
    local.set $bytes_copied

    local.get $bytes_read_last
    local.get $bytes_copied
    i32.sub
  )

  (func $bufrdr_head (param $this i32) (result i32)
    local.get $this
    call $bufrdr_get_iobuf_ptr

    local.get $this
    call $bufrdr_num_bytes_copied

    i32.add
  )

  (func $i32min (export "i32min") (param $x i32) (param $y i32) (result i32)
    local.get $x
    local.get $y
    local.get $x
    local.get $y
    i32.lt_s
    select
  )

  (func $bufrdr_try_copy2buf
    (param $bufrdr i32) ;; ptr to the buf reader
    (param $dst    i32)
    (param $len    i32)

    (result i32) ;; number of bytes copied

    (local $bytes_available i32)
    (local $src i32)

    (local $bytes2copy i32)

    (local $copied_bytes_old i32)
    (local $copied_bytes_new i32)

    local.get $bufrdr
    call $bufrdr_remaining_bytes
    local.tee $bytes_available
    i32.eqz
    ;; nothing to copy
    if
      i32.const 0
      return
    end

    local.get $bufrdr
    call $bufrdr_head
    local.set $src

    local.get $bytes_available
    local.get $len
    call $i32min
    local.set $bytes2copy

    local.get $dst
    local.get $src
    local.get $bytes2copy
    memory.copy

    local.get $bufrdr
    call $bufrdr_num_bytes_copied
    local.tee $copied_bytes_old
    local.get $bytes2copy
    i32.add
    local.set $copied_bytes_new

    local.get $bufrdr
    local.get $copied_bytes_new
    i32.store offset=16

    local.get $bytes2copy
  )

)

(assert_return (invoke "v2lsum" (v128.const i64x2  0  0)) (i64.const  0))
(assert_return (invoke "v2lsum" (v128.const i64x2  0  1)) (i64.const  1))
(assert_return (invoke "v2lsum" (v128.const i64x2  0  2)) (i64.const  2))
(assert_return (invoke "v2lsum" (v128.const i64x2  1  2)) (i64.const  3))
(assert_return (invoke "v2lsum" (v128.const i64x2  2  2)) (i64.const  4))
(assert_return (invoke "v2lsum" (v128.const i64x2  3  2)) (i64.const  5))
(assert_return (invoke "v2lsum" (v128.const i64x2 -3  2)) (i64.const -1))
(assert_return (invoke "v2lsum" (v128.const i64x2 -4  2)) (i64.const -2))
(assert_return (invoke "v2lsum" (v128.const i64x2 -5  2)) (i64.const -3))
(assert_return (invoke "v2lsum" (v128.const i64x2 -5  2)) (i64.const -3))
(assert_return (invoke "v2lsum" (v128.const i64x2 -5 -2)) (i64.const -7))
(assert_return (invoke "v2lsum" (v128.const i64x2 -5 -3)) (i64.const -8))
(assert_return (invoke "v2lsum" (v128.const i64x2 -5 -4)) (i64.const -9))

(assert_return (invoke "t0a_buf2lsum_empty") (i32.const 0))
(assert_return (invoke "t0b_buf2lsum_too_small") (i32.const 0))
(assert_return (invoke "t0c_buf2lsum_single") (i32.const 0))
(assert_return (invoke "t0d_buf2lsum_page") (i32.const 0))

(assert_return (invoke "t10_page2sum_simd_zero") (i32.const 0))
(assert_return (invoke "t11_page2sum_simd_8192") (i32.const 0))

(assert_return (invoke "i32min" (i32.const  0) (i32.const  0)) (i32.const  0))
(assert_return (invoke "i32min" (i32.const  0) (i32.const  1)) (i32.const  0))
(assert_return (invoke "i32min" (i32.const  0) (i32.const  2)) (i32.const  0))
(assert_return (invoke "i32min" (i32.const  0) (i32.const -2)) (i32.const -2))
(assert_return (invoke "i32min" (i32.const  0) (i32.const -1)) (i32.const -1))
(assert_return (invoke "i32min" (i32.const  0) (i32.const -0)) (i32.const -0))
(assert_return (invoke "i32min" (i32.const  1) (i32.const -0)) (i32.const -0))
(assert_return (invoke "i32min" (i32.const  2) (i32.const -0)) (i32.const -0))
(assert_return (invoke "i32min" (i32.const  3) (i32.const -0)) (i32.const -0))
(assert_return (invoke "i32min" (i32.const  3) (i32.const -1)) (i32.const -1))
(assert_return (invoke "i32min" (i32.const  3) (i32.const -2)) (i32.const -2))
(assert_return (invoke "i32min" (i32.const  3) (i32.const -3)) (i32.const -3))
