target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

define i16 @speed_first(ptr %p, i16 %n) {
entry:
  br label %loop
loop:
  %i = phi i16 [ 0, %entry ], [ %i1, %loop ]
  %s = phi i16 [ 0, %entry ], [ %s1, %loop ]
  %q = getelementptr i16, ptr %p, i16 %i
  %v = load i16, ptr %q
  %s1 = add i16 %s, %v
  %i1 = add i16 %i, 1
  %c = icmp ult i16 %i1, %n
  br i1 %c, label %loop, label %exit
exit:
  ret i16 %s1
}

define i16 @size_second(ptr %p, i16 %n) #0 {
entry:
  br label %loop
loop:
  %i = phi i16 [ 0, %entry ], [ %i1, %loop ]
  %s = phi i16 [ 0, %entry ], [ %s1, %loop ]
  %q = getelementptr i16, ptr %p, i16 %i
  %v = load i16, ptr %q
  %s1 = add i16 %s, %v
  %i1 = add i16 %i, 1
  %c = icmp ult i16 %i1, %n
  br i1 %c, label %loop, label %exit
exit:
  ret i16 %s1
}

attributes #0 = { optsize }
