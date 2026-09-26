; ModuleID = '/home/will/llvm-mos-65816/.scratch/carry-scheduling/examples/65816/farblit.c'
source_filename = "/home/will/llvm-mos-65816/.scratch/carry-scheduling/examples/65816/farblit.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@rbase8 = dso_local global i32 65504, align 1
@rbase16 = dso_local global i32 32768, align 1
@rbasew = dso_local global i32 32736, align 1
@wbase8 = dso_local global i32 8323040, align 1
@wbase16 = dso_local global i32 8273920, align 1
@wbasec = dso_local global i32 8355824, align 1
@rbasew16 = dso_local global i32 65536, align 1
@obase = dso_local global i16 -16, align 1
@k8 = dso_local global i8 -16, align 1
@corpus_result = dso_local global i32 0, align 1
@tbl = external dso_local local_unnamed_addr addrspace(2) constant [0 x i16], align 1
@offs16 = internal unnamed_addr constant [8 x i16] [i16 0, i16 255, i16 256, i16 4660, i16 32767, i16 -32768, i16 -16383, i16 -1], align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = load volatile i32, ptr @rbase8, align 1, !tbaa !6
  %2 = getelementptr inbounds nuw i8, ptr addrspace(2) @tbl, i32 %1
  br label %3

3:                                                ; preds = %3, %0
  %4 = phi i8 [ 0, %0 ], [ %12, %3 ]
  %5 = phi i32 [ 0, %0 ], [ %11, %3 ]
  %6 = zext nneg i8 %4 to i32
  %7 = getelementptr inbounds nuw i8, ptr addrspace(2) %2, i32 %6
  %8 = load i8, ptr addrspace(2) %7, align 1, !tbaa !8
  %9 = zext i8 %8 to i32
  %10 = tail call i32 @llvm.fshl.i32(i32 %5, i32 %5, i32 1)
  %11 = xor i32 %10, %9
  %12 = add nuw nsw i8 %4, 1
  %13 = icmp eq i8 %12, 64
  br i1 %13, label %14, label %3, !llvm.loop !9

14:                                               ; preds = %3, %14
  %15 = phi i8 [ %23, %14 ], [ 0, %3 ]
  %16 = phi i32 [ %22, %14 ], [ 0, %3 ]
  %17 = zext nneg i8 %15 to i32
  %18 = getelementptr inbounds nuw i8, ptr addrspace(2) @tbl, i32 %17
  %19 = load i8, ptr addrspace(2) %18, align 1, !tbaa !8
  %20 = zext i8 %19 to i32
  %21 = tail call i32 @llvm.fshl.i32(i32 %16, i32 %16, i32 1)
  %22 = xor i32 %21, %20
  %23 = add nuw nsw i8 %15, 1
  %24 = icmp eq i8 %23, 64
  br i1 %24, label %25, label %14, !llvm.loop !11

25:                                               ; preds = %14
  %26 = load volatile i32, ptr @rbase16, align 1, !tbaa !6
  %27 = getelementptr inbounds nuw i8, ptr addrspace(2) @tbl, i32 %26
  br label %28

28:                                               ; preds = %28, %25
  %29 = phi i8 [ 0, %25 ], [ %43, %28 ]
  %30 = phi i8 [ 0, %25 ], [ %41, %28 ]
  %31 = phi i32 [ 0, %25 ], [ %40, %28 ]
  %32 = zext nneg i8 %29 to i16
  %33 = getelementptr i8, ptr @offs16, i16 %32
  %34 = load i16, ptr %33, align 1, !tbaa !2
  %35 = zext i16 %34 to i32
  %36 = getelementptr inbounds nuw i8, ptr addrspace(2) %27, i32 %35
  %37 = load i8, ptr addrspace(2) %36, align 1, !tbaa !8
  %38 = zext i8 %37 to i32
  %39 = tail call i32 @llvm.fshl.i32(i32 %31, i32 %31, i32 1)
  %40 = xor i32 %39, %38
  %41 = add nuw nsw i8 %30, 1
  %42 = icmp eq i8 %41, 8
  %43 = add nuw nsw i8 %29, 2
  br i1 %42, label %44, label %28, !llvm.loop !12

44:                                               ; preds = %28
  %45 = load volatile i32, ptr @rbasew, align 1, !tbaa !6
  %46 = getelementptr inbounds nuw [2 x i8], ptr addrspace(2) @tbl, i32 %45
  br label %47

47:                                               ; preds = %47, %44
  %48 = phi i8 [ 0, %44 ], [ %56, %47 ]
  %49 = phi i32 [ 0, %44 ], [ %55, %47 ]
  %50 = zext nneg i8 %48 to i32
  %51 = getelementptr inbounds nuw [2 x i8], ptr addrspace(2) %46, i32 %50
  %52 = load i16, ptr addrspace(2) %51, align 1, !tbaa !2
  %53 = zext i16 %52 to i32
  %54 = tail call i32 @llvm.fshl.i32(i32 %49, i32 %49, i32 1)
  %55 = xor i32 %54, %53
  %56 = add nuw nsw i8 %48, 1
  %57 = icmp eq i8 %56, 64
  br i1 %57, label %58, label %47, !llvm.loop !13

58:                                               ; preds = %47
  %59 = load volatile i32, ptr @rbasew16, align 1, !tbaa !6
  %60 = getelementptr inbounds nuw i8, ptr addrspace(2) @tbl, i32 %59
  %61 = load volatile i16, ptr @obase, align 1, !tbaa !2
  br label %62

62:                                               ; preds = %62, %58
  %63 = phi i8 [ 0, %58 ], [ %73, %62 ]
  %64 = phi i32 [ 0, %58 ], [ %72, %62 ]
  %65 = zext nneg i8 %63 to i16
  %66 = add i16 %61, %65
  %67 = zext i16 %66 to i32
  %68 = getelementptr inbounds nuw i8, ptr addrspace(2) %60, i32 %67
  %69 = load i8, ptr addrspace(2) %68, align 1, !tbaa !8
  %70 = zext i8 %69 to i32
  %71 = tail call i32 @llvm.fshl.i32(i32 %64, i32 %64, i32 1)
  %72 = xor i32 %71, %70
  %73 = add nuw nsw i8 %63, 1
  %74 = icmp eq i8 %73, 32
  br i1 %74, label %75, label %62, !llvm.loop !14

75:                                               ; preds = %62
  %76 = load volatile i16, ptr @obase, align 1, !tbaa !2
  br label %77

77:                                               ; preds = %77, %75
  %78 = phi i8 [ 0, %75 ], [ %88, %77 ]
  %79 = phi i32 [ 0, %75 ], [ %87, %77 ]
  %80 = zext nneg i8 %78 to i16
  %81 = add i16 %76, %80
  %82 = zext i16 %81 to i32
  %83 = getelementptr inbounds nuw i8, ptr addrspace(2) @tbl, i32 %82
  %84 = load i8, ptr addrspace(2) %83, align 1, !tbaa !8
  %85 = zext i8 %84 to i32
  %86 = tail call i32 @llvm.fshl.i32(i32 %79, i32 %79, i32 1)
  %87 = xor i32 %86, %85
  %88 = add nuw nsw i8 %78, 1
  %89 = icmp eq i8 %88, 32
  br i1 %89, label %90, label %77, !llvm.loop !15

90:                                               ; preds = %77
  %91 = load volatile i32, ptr @rbase8, align 1, !tbaa !6
  %92 = getelementptr inbounds nuw i8, ptr addrspace(2) @tbl, i32 %91
  %93 = load volatile i8, ptr @k8, align 1, !tbaa !8
  br label %94

94:                                               ; preds = %94, %90
  %95 = phi i8 [ 0, %90 ], [ %104, %94 ]
  %96 = phi i32 [ 0, %90 ], [ %103, %94 ]
  %97 = add i8 %95, %93
  %98 = zext i8 %97 to i32
  %99 = getelementptr inbounds nuw i8, ptr addrspace(2) %92, i32 %98
  %100 = load i8, ptr addrspace(2) %99, align 1, !tbaa !8
  %101 = zext i8 %100 to i32
  %102 = tail call i32 @llvm.fshl.i32(i32 %96, i32 %96, i32 1)
  %103 = xor i32 %102, %101
  %104 = add nuw nsw i8 %95, 1
  %105 = icmp eq i8 %104, 32
  br i1 %105, label %106, label %94, !llvm.loop !16

106:                                              ; preds = %94
  %107 = load volatile i32, ptr @wbase8, align 1, !tbaa !6
  %108 = inttoptr i32 %107 to ptr addrspace(2)
  br label %109

109:                                              ; preds = %109, %106
  %110 = phi i8 [ 0, %106 ], [ %115, %109 ]
  %111 = mul i8 %110, 37
  %112 = add i8 %111, 11
  %113 = zext nneg i8 %110 to i32
  %114 = getelementptr inbounds nuw i8, ptr addrspace(2) %108, i32 %113
  store i8 %112, ptr addrspace(2) %114, align 1, !tbaa !8
  %115 = add nuw nsw i8 %110, 1
  %116 = icmp eq i8 %115, 64
  br i1 %116, label %117, label %109, !llvm.loop !17

117:                                              ; preds = %109
  %118 = load volatile i32, ptr @wbase16, align 1, !tbaa !6
  %119 = inttoptr i32 %118 to ptr addrspace(2)
  br label %120

120:                                              ; preds = %120, %117
  %121 = phi i8 [ 0, %117 ], [ %132, %120 ]
  %122 = phi i8 [ 0, %117 ], [ %130, %120 ]
  %123 = mul nuw i8 %122, 29
  %124 = xor i8 %123, -91
  %125 = zext nneg i8 %121 to i16
  %126 = getelementptr i8, ptr @offs16, i16 %125
  %127 = load i16, ptr %126, align 1, !tbaa !2
  %128 = zext i16 %127 to i32
  %129 = getelementptr inbounds nuw i8, ptr addrspace(2) %119, i32 %128
  store i8 %124, ptr addrspace(2) %129, align 1, !tbaa !8
  %130 = add nuw nsw i8 %122, 1
  %131 = icmp eq i8 %130, 8
  %132 = add nuw nsw i8 %121, 2
  br i1 %131, label %133, label %120, !llvm.loop !18

133:                                              ; preds = %120
  %134 = load volatile i32, ptr @wbasec, align 1, !tbaa !6
  %135 = inttoptr i32 %134 to ptr addrspace(2)
  %136 = load volatile i32, ptr @rbase8, align 1, !tbaa !6
  %137 = getelementptr inbounds nuw i8, ptr addrspace(2) @tbl, i32 %136
  %138 = getelementptr inbounds nuw i8, ptr addrspace(2) %137, i32 8
  br label %139

139:                                              ; preds = %139, %133
  %140 = phi i8 [ 0, %133 ], [ %145, %139 ]
  %141 = zext nneg i8 %140 to i32
  %142 = getelementptr inbounds nuw i8, ptr addrspace(2) %138, i32 %141
  %143 = load i8, ptr addrspace(2) %142, align 1, !tbaa !8
  %144 = getelementptr inbounds nuw i8, ptr addrspace(2) %135, i32 %141
  store i8 %143, ptr addrspace(2) %144, align 1, !tbaa !8
  %145 = add nuw nsw i8 %140, 1
  %146 = icmp eq i8 %145, 48
  br i1 %146, label %147, label %139, !llvm.loop !19

147:                                              ; preds = %139
  %148 = tail call i32 @llvm.fshl.i32(i32 %11, i32 %11, i32 1)
  %149 = xor i32 %22, %148
  %150 = tail call i32 @llvm.fshl.i32(i32 %149, i32 %149, i32 1)
  %151 = xor i32 %40, %150
  %152 = tail call i32 @llvm.fshl.i32(i32 %151, i32 %151, i32 1)
  %153 = xor i32 %55, %152
  %154 = tail call i32 @llvm.fshl.i32(i32 %153, i32 %153, i32 1)
  %155 = xor i32 %72, %154
  %156 = tail call i32 @llvm.fshl.i32(i32 %155, i32 %155, i32 1)
  %157 = xor i32 %87, %156
  %158 = tail call i32 @llvm.fshl.i32(i32 %157, i32 %157, i32 1)
  %159 = xor i32 %103, %158
  %160 = load volatile i8, ptr addrspace(2) inttoptr (i32 8323040 to ptr addrspace(2)), align 32, !tbaa !8
  %161 = zext i8 %160 to i32
  %162 = tail call i32 @llvm.fshl.i32(i32 %159, i32 %159, i32 1)
  %163 = xor i32 %162, %161
  %164 = load volatile i8, ptr addrspace(2) inttoptr (i32 8323071 to ptr addrspace(2)), align 1, !tbaa !8
  %165 = zext i8 %164 to i32
  %166 = tail call i32 @llvm.fshl.i32(i32 %163, i32 %163, i32 1)
  %167 = xor i32 %166, %165
  %168 = load volatile i8, ptr addrspace(2) inttoptr (i32 8323072 to ptr addrspace(2)), align 65536, !tbaa !8
  %169 = zext i8 %168 to i32
  %170 = tail call i32 @llvm.fshl.i32(i32 %167, i32 %167, i32 1)
  %171 = xor i32 %170, %169
  %172 = load volatile i8, ptr addrspace(2) inttoptr (i32 8323103 to ptr addrspace(2)), align 1, !tbaa !8
  %173 = zext i8 %172 to i32
  %174 = tail call i32 @llvm.fshl.i32(i32 %171, i32 %171, i32 1)
  %175 = xor i32 %174, %173
  %176 = load volatile i8, ptr addrspace(2) inttoptr (i32 8273920 to ptr addrspace(2)), align 16384, !tbaa !8
  %177 = zext i8 %176 to i32
  %178 = tail call i32 @llvm.fshl.i32(i32 %175, i32 %175, i32 1)
  %179 = xor i32 %178, %177
  %180 = load volatile i8, ptr addrspace(2) inttoptr (i32 8274175 to ptr addrspace(2)), align 1, !tbaa !8
  %181 = zext i8 %180 to i32
  %182 = tail call i32 @llvm.fshl.i32(i32 %179, i32 %179, i32 1)
  %183 = xor i32 %182, %181
  %184 = load volatile i8, ptr addrspace(2) inttoptr (i32 8274176 to ptr addrspace(2)), align 256, !tbaa !8
  %185 = zext i8 %184 to i32
  %186 = tail call i32 @llvm.fshl.i32(i32 %183, i32 %183, i32 1)
  %187 = xor i32 %186, %185
  %188 = load volatile i8, ptr addrspace(2) inttoptr (i32 8278580 to ptr addrspace(2)), align 4, !tbaa !8
  %189 = zext i8 %188 to i32
  %190 = tail call i32 @llvm.fshl.i32(i32 %187, i32 %187, i32 1)
  %191 = xor i32 %190, %189
  %192 = load volatile i8, ptr addrspace(2) inttoptr (i32 8306687 to ptr addrspace(2)), align 1, !tbaa !8
  %193 = zext i8 %192 to i32
  %194 = tail call i32 @llvm.fshl.i32(i32 %191, i32 %191, i32 1)
  %195 = xor i32 %194, %193
  %196 = load volatile i8, ptr addrspace(2) inttoptr (i32 8306688 to ptr addrspace(2)), align 16384, !tbaa !8
  %197 = zext i8 %196 to i32
  %198 = tail call i32 @llvm.fshl.i32(i32 %195, i32 %195, i32 1)
  %199 = xor i32 %198, %197
  %200 = load volatile i8, ptr addrspace(2) inttoptr (i32 8323073 to ptr addrspace(2)), align 1, !tbaa !8
  %201 = zext i8 %200 to i32
  %202 = tail call i32 @llvm.fshl.i32(i32 %199, i32 %199, i32 1)
  %203 = xor i32 %202, %201
  %204 = load volatile i8, ptr addrspace(2) inttoptr (i32 8339455 to ptr addrspace(2)), align 1, !tbaa !8
  %205 = zext i8 %204 to i32
  %206 = tail call i32 @llvm.fshl.i32(i32 %203, i32 %203, i32 1)
  %207 = xor i32 %206, %205
  %208 = load volatile i8, ptr addrspace(2) inttoptr (i32 8355824 to ptr addrspace(2)), align 16, !tbaa !8
  %209 = zext i8 %208 to i32
  %210 = tail call i32 @llvm.fshl.i32(i32 %207, i32 %207, i32 1)
  %211 = xor i32 %210, %209
  %212 = load volatile i8, ptr addrspace(2) inttoptr (i32 8355847 to ptr addrspace(2)), align 1, !tbaa !8
  %213 = zext i8 %212 to i32
  %214 = tail call i32 @llvm.fshl.i32(i32 %211, i32 %211, i32 1)
  %215 = xor i32 %214, %213
  %216 = load volatile i8, ptr addrspace(2) inttoptr (i32 8355848 to ptr addrspace(2)), align 8, !tbaa !8
  %217 = zext i8 %216 to i32
  %218 = tail call i32 @llvm.fshl.i32(i32 %215, i32 %215, i32 1)
  %219 = xor i32 %218, %217
  %220 = load volatile i8, ptr addrspace(2) inttoptr (i32 8355871 to ptr addrspace(2)), align 1, !tbaa !8
  %221 = zext i8 %220 to i32
  %222 = tail call i32 @llvm.fshl.i32(i32 %219, i32 %219, i32 1)
  %223 = xor i32 %222, %221
  store volatile i32 %223, ptr @corpus_result, align 1, !tbaa !6
  br label %224

224:                                              ; preds = %224, %147
  tail call void asm sideeffect "wai", ""() #2, !srcloc !20
  br label %224
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.fshl.i32(i32, i32, i32) #1

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (/upstream 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !7, i64 0}
!7 = !{!"long", !4, i64 0}
!8 = !{!4, !4, i64 0}
!9 = distinct !{!9, !10}
!10 = !{!"llvm.loop.mustprogress"}
!11 = distinct !{!11, !10}
!12 = distinct !{!12, !10}
!13 = distinct !{!13, !10}
!14 = distinct !{!14, !10}
!15 = distinct !{!15, !10}
!16 = distinct !{!16, !10}
!17 = distinct !{!17, !10}
!18 = distinct !{!18, !10}
!19 = distinct !{!19, !10}
!20 = !{i64 9157}
