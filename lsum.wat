(module

  (import "wasi_snapshot_preview1" "proc_exit" (func $proc_exit (param i32)))

  (import "wasi_snapshot_preview1" "fd_read"
    (func $fd_read (param i32 i32 i32 i32) (result i32)))

  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))

  (global $STDIN i32 (i32.const 0))
  (global $STDOUT i32 (i32.const 1))
  (global $STDERR i32 (i32.const 2))

  (global $FD_READ_IOVEC_PTR i32 (i32.const 0x0001_0000))
  (global $FD_READ_IOBUF_PTR i32 (i32.const 0x0002_0000))
  (global $FD_READ_BREAD_PTR i32 (i32.const 0x0003_0000))

  (global $FD_WRIT_IOVEC_PTR i32 (i32.const 0x0004_0000))
  (global $FD_WRIT_IOBUF_PTR i32 (i32.const 0x0005_0000))
  (global $FD_WRIT_BWRIT_PTR i32 (i32.const 0x0006_0000))

  (global $BUFRDR i32 (i32.const 0x0007_0000))

  (global $LONGS_PTR i32 (i32.const 0x0008_0000))
  (global $LONGS_SIZ i32 (i32.const 65536))

  (memory (export "memory") 9)

  (func $io_fd2buf
    (param $ptr2buf i32)
    (param $fd i32)
    (param $iovec_ptr i32)
    (param $bread_ptr i32)
    (param $len i32)

    (result i32) ;; num bytes read

    ;; setup the iovec
    local.get $iovec_ptr
    local.get $ptr2buf
    i32.store
    local.get $iovec_ptr
    local.get $len
    i32.store offset=4

    local.get $fd
    local.get $iovec_ptr
    i32.const 1 ;; single buffer
    local.get $bread_ptr
    call $fd_read
    i32.const 0
    i32.ne
    if
      i32.const 1
      call $proc_exit
    end

    local.get $bread_ptr
    i32.load
  )

  (func $i32min (export "i32min") (param $x i32) (param $y i32) (result i32)
    local.get $x
    local.get $y
    local.get $x
    local.get $y
    i32.lt_s
    select
  )

  ;; Buf reader
  ;;   offset 0x00: fd
  ;;   offset 0x04: ptr to iovec
  ;;   offset 0x08: ptr to iobuf
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

  (func $bufrdr_init_default
    global.get $BUFRDR
    global.get $STDIN
    global.get $FD_READ_IOVEC_PTR
    global.get $FD_READ_IOBUF_PTR
    global.get $FD_READ_BREAD_PTR
    call $bufrdr_init
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

  (func $io_sum2stdout (param $sum i64)
    ;; setup the iovec
    global.get $FD_WRIT_IOVEC_PTR
    global.get $FD_WRIT_IOBUF_PTR
    i32.store
    global.get $FD_WRIT_IOVEC_PTR
    i32.const 8 ;; 64-bit int = 8 bytes
    i32.store offset=4

    ;; set the sum
    global.get $FD_WRIT_IOBUF_PTR
    local.get $sum
    i64.store

    global.get $STDOUT
    global.get $FD_WRIT_IOVEC_PTR
    i32.const 1 ;; single buffer
    global.get $FD_WRIT_BWRIT_PTR
    call $fd_write
    i32.const 0
    i32.ne
    if
      i32.const 1
      call $proc_exit
      unreachable
    end
  )

  (func $io_bufrdr_try_refill_page (param $this i32) (result i32)
    ;; result: num bytes read

    (local $numbytes_read i32)
    (local $ret i32)

    local.get $this
    call $bufrdr_reset_iovec_page

    local.get $this
    call $bufrdr_get_fd
    local.get $this
    call $bufrdr_get_iovec_ptr
    i32.const 1
    local.get $this
    call $bufrdr_get_bread_ptr
    call $fd_read
    local.tee $ret
    i32.const 0
    i32.ne
    if
      i32.const 1
      call $proc_exit
      unreachable
    end

    local.get $this
    call $bufrdr_num_bytes_read
    local.set $numbytes_read

    local.get $this
    local.get $numbytes_read
    call $bufrdr_set_num_bytes_read

    local.get $numbytes_read
  )

  (func $io_bufrdr_copy2buf
    (param $this i32)
    (param $dst i32)
    (param $len i32)

    (result i32) ;; num bytes copied

    (local $bytes_copied i32)
    (local $dst_head i32)

    (local $bytes_copied_current i32)

    i32.const 0
    local.set $bytes_copied

    loop
      local.get $bytes_copied
      local.get $len
      i32.eq
      ;; no need to copy more
      if
        local.get $len
        return
      end

      ;; set the dst head
      local.get $dst
      local.get $bytes_copied
      i32.add
      local.set $dst_head

      local.get $this
      local.get $dst_head
      ;; compute the bytes to copy
      local.get $len
      local.get $bytes_copied
      i32.sub
      call $bufrdr_try_copy2buf
      local.tee $bytes_copied_current
      i32.eqz
      ;; nothing to copy from buf
      if
        local.get $this
        call $io_bufrdr_try_refill_page
        i32.eqz
        ;; EOF
        if
          local.get $bytes_copied
          return
        end

        br 1
      end

      local.get $bytes_copied
      local.get $bytes_copied_current
      i32.add
      local.set $bytes_copied

      br 0
    end

    unreachable
  )

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

  (func $io_stdin2sum (result i64 i32)
    (local $bufrdr i32)
    (local $copied_siz i32)

    (local $sum i64)
    (local $valid i32)

    (local $vsum v128)
    (local $current_sum i64)

    (local $ret i32)

    call $bufrdr_init_default

    global.get $BUFRDR
    local.set $bufrdr

    i64.const 0
    local.set $sum

    i32.const 0
    local.set $valid

    loop
      local.get $bufrdr
      global.get $LONGS_PTR
      global.get $LONGS_SIZ
      call $io_bufrdr_copy2buf
      local.tee $copied_siz
      i32.eqz
      ;; EOF
      if
        local.get $sum
        local.get $valid
        return
      end

      local.get $copied_siz
      i32.const 65536
      i32.eq
      ;; full page read
      if
        global.get $LONGS_PTR
        call $page2sum_simd
        local.tee $vsum
        call $v2lsum
        local.get $sum
        i64.add
        local.set $sum
        i32.const 1
        local.set $valid
        br 1
      end

      ;; partial page read
      global.get $LONGS_PTR
      local.get $copied_siz
      call $buf2lsum
      local.set $ret
      local.set $current_sum

      local.get $ret
      i32.eqz
      ;; no long to sum
      if
        br 1
      end

      local.get $current_sum
      local.get $sum
      i64.add
      local.set $sum

      i32.const 1
      local.set $valid

      br 0
    end

    unreachable
  )

  (func $io_stdin2sum2stdout
    (local $sum i64)
    (local $ret i32)
    call $io_stdin2sum
    local.set $ret
    local.set $sum

    local.get $ret
    i32.eqz
    ;; exit if the sum is invalid(e.g., no input)
    if
      i32.const 2
      call $proc_exit
      unreachable
    end

    local.get $sum
    call $io_sum2stdout
  )

  (func $main (export "_start")
    call $io_stdin2sum2stdout
  )

)
