define void @in_vector(<4 x i64> %x) {
  call void asm sideeffect "", "w"(<4 x i64> %x)
  ret void
}
