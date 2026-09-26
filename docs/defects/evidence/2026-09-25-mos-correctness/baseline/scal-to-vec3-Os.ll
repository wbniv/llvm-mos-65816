; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec3.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec3.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

; Function Attrs: nounwind optsize
define dso_local noundef i16 @main(i16 noundef %0, ptr noundef readnone captures(none) %1) local_unnamed_addr #0 {
  %3 = alloca <4 x float>, align 16
  %4 = alloca <4 x float>, align 16
  %5 = alloca <2 x double>, align 16
  %6 = alloca <2 x double>, align 16
  call void @llvm.lifetime.start.p0(ptr nonnull %3) #3
  call void @llvm.lifetime.start.p0(ptr nonnull %4) #3
  call void @llvm.lifetime.start.p0(ptr nonnull %5) #3
  call void @llvm.lifetime.start.p0(ptr nonnull %6) #3
  store <4 x float> <float 3.000000e+00, float 4.000000e+00, float 5.000000e+00, float 6.000000e+00>, ptr %3, align 16, !tbaa !6
  store <4 x float> <float 3.000000e+00, float 4.000000e+00, float 5.000000e+00, float 6.000000e+00>, ptr %4, align 16, !tbaa !6
  br label %11

7:                                                ; preds = %11
  %8 = add nuw nsw i16 %13, 1
  %9 = icmp eq i16 %8, 4
  %10 = add nuw nsw i8 %12, 4
  br i1 %9, label %21, label %11, !llvm.loop !7

11:                                               ; preds = %2, %7
  %12 = phi i8 [ 0, %2 ], [ %10, %7 ]
  %13 = phi i16 [ 0, %2 ], [ %8, %7 ]
  %14 = zext nneg i8 %12 to i16
  %15 = getelementptr i8, ptr %3, i16 %14
  %16 = load float, ptr %15, align 4, !tbaa !9
  %17 = getelementptr i8, ptr %4, i16 %14
  %18 = load float, ptr %17, align 4, !tbaa !9
  %19 = fcmp une float %16, %18
  br i1 %19, label %20, label %7

20:                                               ; preds = %11
  tail call void @abort() #4
  unreachable

21:                                               ; preds = %7
  store <4 x float> <float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float -2.000000e+00>, ptr %3, align 16, !tbaa !6
  store <4 x float> <float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float -2.000000e+00>, ptr %4, align 16, !tbaa !6
  br label %26

22:                                               ; preds = %26
  %23 = add nuw nsw i16 %28, 1
  %24 = icmp eq i16 %23, 4
  %25 = add nuw nsw i8 %27, 4
  br i1 %24, label %36, label %26, !llvm.loop !11

26:                                               ; preds = %21, %22
  %27 = phi i8 [ 0, %21 ], [ %25, %22 ]
  %28 = phi i16 [ 0, %21 ], [ %23, %22 ]
  %29 = zext nneg i8 %27 to i16
  %30 = getelementptr i8, ptr %3, i16 %29
  %31 = load float, ptr %30, align 4, !tbaa !9
  %32 = getelementptr i8, ptr %4, i16 %29
  %33 = load float, ptr %32, align 4, !tbaa !9
  %34 = fcmp une float %31, %33
  br i1 %34, label %35, label %22

35:                                               ; preds = %26
  tail call void @abort() #4
  unreachable

36:                                               ; preds = %22
  store <4 x float> <float 2.000000e+00, float 4.000000e+00, float 6.000000e+00, float 8.000000e+00>, ptr %3, align 16, !tbaa !6
  store <4 x float> <float 2.000000e+00, float 4.000000e+00, float 6.000000e+00, float 8.000000e+00>, ptr %4, align 16, !tbaa !6
  br label %41

37:                                               ; preds = %41
  %38 = add nuw nsw i16 %43, 1
  %39 = icmp eq i16 %38, 4
  %40 = add nuw nsw i8 %42, 4
  br i1 %39, label %51, label %41, !llvm.loop !12

41:                                               ; preds = %36, %37
  %42 = phi i8 [ 0, %36 ], [ %40, %37 ]
  %43 = phi i16 [ 0, %36 ], [ %38, %37 ]
  %44 = zext nneg i8 %42 to i16
  %45 = getelementptr i8, ptr %3, i16 %44
  %46 = load float, ptr %45, align 4, !tbaa !9
  %47 = getelementptr i8, ptr %4, i16 %44
  %48 = load float, ptr %47, align 4, !tbaa !9
  %49 = fcmp une float %46, %48
  br i1 %49, label %50, label %37

50:                                               ; preds = %41
  tail call void @abort() #4
  unreachable

51:                                               ; preds = %37
  store <4 x float> <float 2.000000e+00, float 1.000000e+00, float 0x3FE5555560000000, float 5.000000e-01>, ptr %3, align 16, !tbaa !6
  store <4 x float> <float 2.000000e+00, float 1.000000e+00, float 0x3FE5555560000000, float 5.000000e-01>, ptr %4, align 16, !tbaa !6
  br label %56

52:                                               ; preds = %56
  %53 = add nuw nsw i16 %58, 1
  %54 = icmp eq i16 %53, 4
  %55 = add nuw nsw i8 %57, 4
  br i1 %54, label %66, label %56, !llvm.loop !13

56:                                               ; preds = %51, %52
  %57 = phi i8 [ 0, %51 ], [ %55, %52 ]
  %58 = phi i16 [ 0, %51 ], [ %53, %52 ]
  %59 = zext nneg i8 %57 to i16
  %60 = getelementptr i8, ptr %3, i16 %59
  %61 = load float, ptr %60, align 4, !tbaa !9
  %62 = getelementptr i8, ptr %4, i16 %59
  %63 = load float, ptr %62, align 4, !tbaa !9
  %64 = fcmp une float %61, %63
  br i1 %64, label %65, label %52

65:                                               ; preds = %56
  tail call void @abort() #4
  unreachable

66:                                               ; preds = %52
  store <4 x float> <float 3.000000e+00, float 4.000000e+00, float 5.000000e+00, float 6.000000e+00>, ptr %3, align 16, !tbaa !6
  store <4 x float> <float 3.000000e+00, float 4.000000e+00, float 5.000000e+00, float 6.000000e+00>, ptr %4, align 16, !tbaa !6
  br label %71

67:                                               ; preds = %71
  %68 = add nuw nsw i16 %73, 1
  %69 = icmp eq i16 %68, 4
  %70 = add nuw nsw i8 %72, 4
  br i1 %69, label %81, label %71, !llvm.loop !14

71:                                               ; preds = %66, %67
  %72 = phi i8 [ 0, %66 ], [ %70, %67 ]
  %73 = phi i16 [ 0, %66 ], [ %68, %67 ]
  %74 = zext nneg i8 %72 to i16
  %75 = getelementptr i8, ptr %3, i16 %74
  %76 = load float, ptr %75, align 4, !tbaa !9
  %77 = getelementptr i8, ptr %4, i16 %74
  %78 = load float, ptr %77, align 4, !tbaa !9
  %79 = fcmp une float %76, %78
  br i1 %79, label %80, label %67

80:                                               ; preds = %71
  tail call void @abort() #4
  unreachable

81:                                               ; preds = %67
  store <4 x float> <float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 2.000000e+00>, ptr %3, align 16, !tbaa !6
  store <4 x float> <float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 2.000000e+00>, ptr %4, align 16, !tbaa !6
  br label %86

82:                                               ; preds = %86
  %83 = add nuw nsw i16 %88, 1
  %84 = icmp eq i16 %83, 4
  %85 = add nuw nsw i8 %87, 4
  br i1 %84, label %96, label %86, !llvm.loop !15

86:                                               ; preds = %81, %82
  %87 = phi i8 [ 0, %81 ], [ %85, %82 ]
  %88 = phi i16 [ 0, %81 ], [ %83, %82 ]
  %89 = zext nneg i8 %87 to i16
  %90 = getelementptr i8, ptr %3, i16 %89
  %91 = load float, ptr %90, align 4, !tbaa !9
  %92 = getelementptr i8, ptr %4, i16 %89
  %93 = load float, ptr %92, align 4, !tbaa !9
  %94 = fcmp une float %91, %93
  br i1 %94, label %95, label %82

95:                                               ; preds = %86
  tail call void @abort() #4
  unreachable

96:                                               ; preds = %82
  store <4 x float> <float 2.000000e+00, float 4.000000e+00, float 6.000000e+00, float 8.000000e+00>, ptr %3, align 16, !tbaa !6
  store <4 x float> <float 2.000000e+00, float 4.000000e+00, float 6.000000e+00, float 8.000000e+00>, ptr %4, align 16, !tbaa !6
  br label %101

97:                                               ; preds = %101
  %98 = add nuw nsw i16 %103, 1
  %99 = icmp eq i16 %98, 4
  %100 = add nuw nsw i8 %102, 4
  br i1 %99, label %111, label %101, !llvm.loop !16

101:                                              ; preds = %96, %97
  %102 = phi i8 [ 0, %96 ], [ %100, %97 ]
  %103 = phi i16 [ 0, %96 ], [ %98, %97 ]
  %104 = zext nneg i8 %102 to i16
  %105 = getelementptr i8, ptr %3, i16 %104
  %106 = load float, ptr %105, align 4, !tbaa !9
  %107 = getelementptr i8, ptr %4, i16 %104
  %108 = load float, ptr %107, align 4, !tbaa !9
  %109 = fcmp une float %106, %108
  br i1 %109, label %110, label %97

110:                                              ; preds = %101
  tail call void @abort() #4
  unreachable

111:                                              ; preds = %97
  store <4 x float> <float 5.000000e-01, float 1.000000e+00, float 1.500000e+00, float 2.000000e+00>, ptr %3, align 16, !tbaa !6
  store <4 x float> <float 5.000000e-01, float 1.000000e+00, float 1.500000e+00, float 2.000000e+00>, ptr %4, align 16, !tbaa !6
  br label %116

112:                                              ; preds = %116
  %113 = add nuw nsw i16 %118, 1
  %114 = icmp eq i16 %113, 4
  %115 = add nuw nsw i8 %117, 4
  br i1 %114, label %126, label %116, !llvm.loop !17

116:                                              ; preds = %111, %112
  %117 = phi i8 [ 0, %111 ], [ %115, %112 ]
  %118 = phi i16 [ 0, %111 ], [ %113, %112 ]
  %119 = zext nneg i8 %117 to i16
  %120 = getelementptr i8, ptr %3, i16 %119
  %121 = load float, ptr %120, align 4, !tbaa !9
  %122 = getelementptr i8, ptr %4, i16 %119
  %123 = load float, ptr %122, align 4, !tbaa !9
  %124 = fcmp une float %121, %123
  br i1 %124, label %125, label %112

125:                                              ; preds = %116
  tail call void @abort() #4
  unreachable

126:                                              ; preds = %112
  store <2 x double> <double 3.000000e+00, double 4.000000e+00>, ptr %5, align 16, !tbaa !6
  store <2 x double> <double 3.000000e+00, double 4.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %129

127:                                              ; preds = %129
  %128 = add nuw nsw i8 %130, 8
  br i1 %131, label %129, label %139, !llvm.loop !18

129:                                              ; preds = %126, %127
  %130 = phi i8 [ 0, %126 ], [ %128, %127 ]
  %131 = phi i1 [ true, %126 ], [ false, %127 ]
  %132 = zext nneg i8 %130 to i16
  %133 = getelementptr i8, ptr %5, i16 %132
  %134 = load double, ptr %133, align 8, !tbaa !19
  %135 = getelementptr i8, ptr %6, i16 %132
  %136 = load double, ptr %135, align 8, !tbaa !19
  %137 = fcmp une double %134, %136
  br i1 %137, label %138, label %127

138:                                              ; preds = %129
  tail call void @abort() #4
  unreachable

139:                                              ; preds = %127
  store <2 x double> <double 1.000000e+00, double 0.000000e+00>, ptr %5, align 16, !tbaa !6
  store <2 x double> <double 1.000000e+00, double 0.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %142

140:                                              ; preds = %142
  %141 = add nuw nsw i8 %143, 8
  br i1 %144, label %142, label %152, !llvm.loop !21

142:                                              ; preds = %139, %140
  %143 = phi i8 [ 0, %139 ], [ %141, %140 ]
  %144 = phi i1 [ true, %139 ], [ false, %140 ]
  %145 = zext nneg i8 %143 to i16
  %146 = getelementptr i8, ptr %5, i16 %145
  %147 = load double, ptr %146, align 8, !tbaa !19
  %148 = getelementptr i8, ptr %6, i16 %145
  %149 = load double, ptr %148, align 8, !tbaa !19
  %150 = fcmp une double %147, %149
  br i1 %150, label %151, label %140

151:                                              ; preds = %142
  tail call void @abort() #4
  unreachable

152:                                              ; preds = %140
  store <2 x double> <double 2.000000e+00, double 4.000000e+00>, ptr %5, align 16, !tbaa !6
  store <2 x double> <double 2.000000e+00, double 4.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %155

153:                                              ; preds = %155
  %154 = add nuw nsw i8 %156, 8
  br i1 %157, label %155, label %165, !llvm.loop !22

155:                                              ; preds = %152, %153
  %156 = phi i8 [ 0, %152 ], [ %154, %153 ]
  %157 = phi i1 [ true, %152 ], [ false, %153 ]
  %158 = zext nneg i8 %156 to i16
  %159 = getelementptr i8, ptr %5, i16 %158
  %160 = load double, ptr %159, align 8, !tbaa !19
  %161 = getelementptr i8, ptr %6, i16 %158
  %162 = load double, ptr %161, align 8, !tbaa !19
  %163 = fcmp une double %160, %162
  br i1 %163, label %164, label %153

164:                                              ; preds = %155
  tail call void @abort() #4
  unreachable

165:                                              ; preds = %153
  store <2 x double> <double 2.000000e+00, double 1.000000e+00>, ptr %5, align 16, !tbaa !6
  store <2 x double> <double 2.000000e+00, double 1.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %168

166:                                              ; preds = %168
  %167 = add nuw nsw i8 %169, 8
  br i1 %170, label %168, label %178, !llvm.loop !23

168:                                              ; preds = %165, %166
  %169 = phi i8 [ 0, %165 ], [ %167, %166 ]
  %170 = phi i1 [ true, %165 ], [ false, %166 ]
  %171 = zext nneg i8 %169 to i16
  %172 = getelementptr i8, ptr %5, i16 %171
  %173 = load double, ptr %172, align 8, !tbaa !19
  %174 = getelementptr i8, ptr %6, i16 %171
  %175 = load double, ptr %174, align 8, !tbaa !19
  %176 = fcmp une double %173, %175
  br i1 %176, label %177, label %166

177:                                              ; preds = %168
  tail call void @abort() #4
  unreachable

178:                                              ; preds = %166
  store <2 x double> <double 3.000000e+00, double 4.000000e+00>, ptr %5, align 16, !tbaa !6
  store <2 x double> <double 3.000000e+00, double 4.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %181

179:                                              ; preds = %181
  %180 = add nuw nsw i8 %182, 8
  br i1 %183, label %181, label %191, !llvm.loop !24

181:                                              ; preds = %178, %179
  %182 = phi i8 [ 0, %178 ], [ %180, %179 ]
  %183 = phi i1 [ true, %178 ], [ false, %179 ]
  %184 = zext nneg i8 %182 to i16
  %185 = getelementptr i8, ptr %5, i16 %184
  %186 = load double, ptr %185, align 8, !tbaa !19
  %187 = getelementptr i8, ptr %6, i16 %184
  %188 = load double, ptr %187, align 8, !tbaa !19
  %189 = fcmp une double %186, %188
  br i1 %189, label %190, label %179

190:                                              ; preds = %181
  tail call void @abort() #4
  unreachable

191:                                              ; preds = %179
  store <2 x double> <double -1.000000e+00, double 0.000000e+00>, ptr %5, align 16, !tbaa !6
  store <2 x double> <double -1.000000e+00, double 0.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %194

192:                                              ; preds = %194
  %193 = add nuw nsw i8 %195, 8
  br i1 %196, label %194, label %204, !llvm.loop !25

194:                                              ; preds = %191, %192
  %195 = phi i8 [ 0, %191 ], [ %193, %192 ]
  %196 = phi i1 [ true, %191 ], [ false, %192 ]
  %197 = zext nneg i8 %195 to i16
  %198 = getelementptr i8, ptr %5, i16 %197
  %199 = load double, ptr %198, align 8, !tbaa !19
  %200 = getelementptr i8, ptr %6, i16 %197
  %201 = load double, ptr %200, align 8, !tbaa !19
  %202 = fcmp une double %199, %201
  br i1 %202, label %203, label %192

203:                                              ; preds = %194
  tail call void @abort() #4
  unreachable

204:                                              ; preds = %192
  store <2 x double> <double 2.000000e+00, double 4.000000e+00>, ptr %5, align 16, !tbaa !6
  store <2 x double> <double 2.000000e+00, double 4.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %207

205:                                              ; preds = %207
  %206 = add nuw nsw i8 %208, 8
  br i1 %209, label %207, label %217, !llvm.loop !26

207:                                              ; preds = %204, %205
  %208 = phi i8 [ 0, %204 ], [ %206, %205 ]
  %209 = phi i1 [ true, %204 ], [ false, %205 ]
  %210 = zext nneg i8 %208 to i16
  %211 = getelementptr i8, ptr %5, i16 %210
  %212 = load double, ptr %211, align 8, !tbaa !19
  %213 = getelementptr i8, ptr %6, i16 %210
  %214 = load double, ptr %213, align 8, !tbaa !19
  %215 = fcmp une double %212, %214
  br i1 %215, label %216, label %205

216:                                              ; preds = %207
  tail call void @abort() #4
  unreachable

217:                                              ; preds = %205
  store <2 x double> <double 5.000000e-01, double 1.000000e+00>, ptr %5, align 16, !tbaa !6
  store <2 x double> <double 5.000000e-01, double 1.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %220

218:                                              ; preds = %220
  %219 = add nuw nsw i8 %221, 8
  br i1 %222, label %220, label %230, !llvm.loop !27

220:                                              ; preds = %217, %218
  %221 = phi i8 [ 0, %217 ], [ %219, %218 ]
  %222 = phi i1 [ true, %217 ], [ false, %218 ]
  %223 = zext nneg i8 %221 to i16
  %224 = getelementptr i8, ptr %5, i16 %223
  %225 = load double, ptr %224, align 8, !tbaa !19
  %226 = getelementptr i8, ptr %6, i16 %223
  %227 = load double, ptr %226, align 8, !tbaa !19
  %228 = fcmp une double %225, %227
  br i1 %228, label %229, label %218

229:                                              ; preds = %220
  tail call void @abort() #4
  unreachable

230:                                              ; preds = %218
  call void @llvm.lifetime.end.p0(ptr nonnull %6) #3
  call void @llvm.lifetime.end.p0(ptr nonnull %5) #3
  call void @llvm.lifetime.end.p0(ptr nonnull %4) #3
  call void @llvm.lifetime.end.p0(ptr nonnull %3) #3
  ret i16 0
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: noreturn nounwind optsize
declare dso_local void @abort() local_unnamed_addr #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #3 = { nounwind }
attributes #4 = { noreturn nounwind optsize }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!4, !4, i64 0}
!7 = distinct !{!7, !8}
!8 = !{!"llvm.loop.mustprogress"}
!9 = !{!10, !10, i64 0}
!10 = !{!"float", !4, i64 0}
!11 = distinct !{!11, !8}
!12 = distinct !{!12, !8}
!13 = distinct !{!13, !8}
!14 = distinct !{!14, !8}
!15 = distinct !{!15, !8}
!16 = distinct !{!16, !8}
!17 = distinct !{!17, !8}
!18 = distinct !{!18, !8}
!19 = !{!20, !20, i64 0}
!20 = !{!"double", !4, i64 0}
!21 = distinct !{!21, !8}
!22 = distinct !{!22, !8}
!23 = distinct !{!23, !8}
!24 = distinct !{!24, !8}
!25 = distinct !{!25, !8}
!26 = distinct !{!26, !8}
!27 = distinct !{!27, !8}
