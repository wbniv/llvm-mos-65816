declare ptr @llvm.returnaddress(i32 immarg)
declare void @yes()
declare void @no()

define void @low_byte_branch() {
entry:
  %r = call ptr @llvm.returnaddress(i32 0)
  %a = ptrtoint ptr %r to i16
  %h = lshr i16 %a, 8
  %b = trunc i16 %h to i8
  %c = icmp eq i8 %b, 0
  br i1 %c, label %then, label %else
then:
  call void @yes()
  ret void
else:
  call void @no()
  ret void
}
