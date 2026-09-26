define void @extend_masked(ptr %out, i8 %value) {
  %scaled = mul i8 %value, 7
  %masked = and i8 %scaled, 63
  %extended = zext i8 %masked to i64
  store volatile i64 %extended, ptr %out, align 1
  ret void
}
