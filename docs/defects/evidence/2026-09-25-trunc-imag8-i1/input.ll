target triple = "mos"

define i8 @trunc_imag8_i1(i8 %a, i8 %x) {
entry:
  %bit = trunc i8 %x to i1
  br i1 %bit, label %subtract, label %done

subtract:
  %difference = sub i8 %a, %x
  br label %done

done:
  %result = phi i8 [ %difference, %subtract ], [ %a, %entry ]
  ret i8 %result
}
