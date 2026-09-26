define <4 x i64> @out_vector() {
  %v = call <4 x i64> asm "", "=w"()
  ret <4 x i64> %v
}
