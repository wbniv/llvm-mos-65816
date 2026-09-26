; Equal-width bitcasts and floating-point vectors can use scalar register parts.
define void @small(ptr %p) {
  %v = load <8 x i8>, ptr %p
  %r = call <8 x i8> asm sideeffect "", "=r,0"(<8 x i8> %v)
  store <8 x i8> %r, ptr %p
  ret void
}

define void @floating(ptr %p) {
  %v = load <4 x float>, ptr %p
  call void asm sideeffect "", "r"(<4 x float> %v)
  ret void
}

