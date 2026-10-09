// The rw and locality operands of __builtin_prefetch keep the type of the
// promoted C expression, but llvm.prefetch takes i32. The call must be emitted
// with i32 operands whether the expression is narrower (16-bit int) or wider
// (long, long long) than that.
// RUN: %clang_cc1 -triple msp430 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple x86_64-linux-gnu -emit-llvm -o - %s | FileCheck %s

void explicit_args(char *p) {
  // CHECK-LABEL: @explicit_args
  // CHECK: call void @llvm.prefetch.p0(ptr %{{.*}}, i32 1, i32 2, i32 1)
  __builtin_prefetch(p, 1, 2);
}

void default_args(char *p) {
  // CHECK-LABEL: @default_args
  // CHECK: call void @llvm.prefetch.p0(ptr %{{.*}}, i32 0, i32 3, i32 1)
  __builtin_prefetch(p);
}

void rw_only(char *p) {
  // CHECK-LABEL: @rw_only
  // CHECK: call void @llvm.prefetch.p0(ptr %{{.*}}, i32 1, i32 3, i32 1)
  __builtin_prefetch(p, 1);
}

void long_args(char *p) {
  // CHECK-LABEL: @long_args
  // CHECK: call void @llvm.prefetch.p0(ptr %{{.*}}, i32 1, i32 2, i32 1)
  __builtin_prefetch(p, 1L, 2L);
}

void long_long_args(char *p) {
  // CHECK-LABEL: @long_long_args
  // CHECK: call void @llvm.prefetch.p0(ptr %{{.*}}, i32 0, i32 1, i32 1)
  __builtin_prefetch(p, 0LL, 1LL);
}
