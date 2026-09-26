; Every live aggregate result needs a definition after diagnostic recovery.
define { i64, i128 } @aggregate_output() {
  %r = call { i64, i128 } asm sideeffect "", "=r,={cc}"()
  ret { i64, i128 } %r
}

; An invalid input must leave an otherwise valid output defined.
define i64 @valid_output_bad_input(i128 %v) {
  %r = call i64 asm sideeffect "", "=r,{cc}"(i128 %v)
  ret i64 %r
}
