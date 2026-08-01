.text
.global video_bench_enter_fast
.extern video_bench_run
video_bench_enter_fast:
  .byte $5c /* JML $80:video_bench_run: execute the LoROM mirror at FastROM speed. */
  .word video_bench_run
  .byte $80
