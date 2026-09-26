define void @many_virtual(ptr %p) {
  %v = load <128 x i64>, ptr %p
  call void asm sideeffect "", "w"(<128 x i64> %v)
  ret void
}
