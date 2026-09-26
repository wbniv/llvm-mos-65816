; ModuleID = '<bc file>'
source_filename = "/home/will/llvm-mos-65816/vendor/llvm-mos/llvm/test/tools/llvm-reduce/parallel-workitem-kill.ll"

define void @foo(ptr %ptr) {
  store i32 0, ptr %ptr, align 4
  store i32 1, ptr %ptr, align 4
  store i32 2, ptr %ptr, align 4
  store i32 3, ptr %ptr, align 4
  store i32 4, ptr %ptr, align 4
  store i32 5, ptr %ptr, align 4
  ret void
}
