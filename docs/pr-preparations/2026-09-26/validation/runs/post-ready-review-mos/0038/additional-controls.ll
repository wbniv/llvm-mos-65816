declare ptr @llvm.returnaddress(i32 immarg)
declare ptr @llvm.frameaddress(i32 immarg)
declare void @sink(ptr)
declare void @yes()
declare void @no()

define ptr @dynamic_frame(i16 %n) {
  %a = alloca i8, i16 %n
  call void @sink(ptr %a)
  %f = call ptr @llvm.frameaddress(i32 0)
  ret ptr %f
}

define void @return_address_sign_branch() {
  %r = call ptr @llvm.returnaddress(i32 0)
  %a = ptrtoint ptr %r to i16
  %c = icmp slt i16 %a, 0
  br i1 %c, label %then, label %else
then:
  call void @yes()
  ret void
else:
  call void @no()
  ret void
}
