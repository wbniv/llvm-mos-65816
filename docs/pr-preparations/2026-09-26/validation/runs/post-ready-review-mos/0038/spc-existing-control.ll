declare void @yes()
declare void @no()

define void @signed_argument_branch(i16 %a) {
  %c = icmp slt i16 %a, 0
  br i1 %c, label %then, label %else
then:
  call void @yes()
  ret void
else:
  call void @no()
  ret void
}
