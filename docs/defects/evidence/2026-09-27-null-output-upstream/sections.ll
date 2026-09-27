; Null output must accept globals and constructor/destructor lists without
; emitting section contents or CRT references.
@data = global i8 1
@bss = global i8 0
@zp_data = addrspace(1) global i8 1
@zp_bss = addrspace(1) global i8 0
@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @ctor, ptr null }]
@llvm.global_dtors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @dtor, ptr null }]
define void @ctor() { ret void }
define void @dtor() { ret void }
