; ModuleID = '/work/examples/snes/corpus/jt256_sim.c'
source_filename = "/work/examples/snes/corpus/jt256_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.JtVm = type { [4 x i16], i16, [256 x i8] }

@corpus_result = dso_local global i16 0, align 1
@jt_vm = internal unnamed_addr global %struct.JtVm zeroinitializer, align 1
@jt_seen = internal unnamed_addr global [32 x i8] zeroinitializer, align 1
@jt_prog = internal unnamed_addr global [512 x i8] zeroinitializer, align 1
@jt_tx = internal unnamed_addr global [512 x i8] zeroinitializer, align 1
@jt_ty = internal unnamed_addr global [512 x i8] zeroinitializer, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  store i16 311, ptr @jt_vm, align 1, !tbaa !2
  store i16 31521, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  store i16 19977, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  store i16 -16162, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  store i16 -23131, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  br label %1

1:                                                ; preds = %1, %0
  %2 = phi i16 [ 0, %0 ], [ %7, %1 ]
  %3 = trunc nuw i16 %2 to i8
  %4 = mul i8 %3, 13
  %5 = xor i8 %4, 60
  %6 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %2
  store i8 %5, ptr %6, align 1, !tbaa !8
  %7 = add nuw nsw i16 %2, 1
  %8 = icmp eq i16 %7, 256
  br i1 %8, label %9, label %1, !llvm.loop !9

9:                                                ; preds = %1
  tail call void @llvm.memset.p0.i16(ptr noundef nonnull align 1 dereferenceable(32) @jt_seen, i8 0, i16 32, i1 false), !tbaa !8
  br label %10

10:                                               ; preds = %20, %9
  %11 = phi i16 [ 0, %9 ], [ %25, %20 ]
  %12 = phi i8 [ 95, %9 ], [ %23, %20 ]
  %13 = phi i8 [ 0, %9 ], [ %22, %20 ]
  %14 = and i16 %11, 1
  %15 = icmp eq i16 %14, 0
  br i1 %15, label %16, label %18

16:                                               ; preds = %10
  %17 = add i8 %13, 1
  br label %20

18:                                               ; preds = %10
  %19 = add i8 %12, 7
  br label %20

20:                                               ; preds = %18, %16
  %21 = phi i8 [ %13, %16 ], [ %12, %18 ]
  %22 = phi i8 [ %17, %16 ], [ %13, %18 ]
  %23 = phi i8 [ %12, %16 ], [ %19, %18 ]
  %24 = getelementptr inbounds nuw i8, ptr @jt_prog, i16 %11
  store i8 %21, ptr %24, align 1, !tbaa !8
  %25 = add nuw nsw i16 %11, 1
  %26 = icmp eq i16 %25, 512
  br i1 %26, label %27, label %10, !llvm.loop !11

27:                                               ; preds = %20, %50
  %28 = phi i16 [ %52, %50 ], [ 0, %20 ]
  %29 = phi i16 [ %51, %50 ], [ 0, %20 ]
  %30 = getelementptr inbounds nuw i8, ptr @jt_prog, i16 %28
  %31 = load i8, ptr %30, align 1, !tbaa !8
  tail call fastcc void @jt_exec(i8 noundef zeroext %31) #4
  %32 = lshr i8 %31, 3
  %33 = zext nneg i8 %32 to i16
  %34 = getelementptr inbounds nuw i8, ptr @jt_seen, i16 %33
  %35 = load i8, ptr %34, align 1, !tbaa !8
  %36 = and i8 %31, 7
  %37 = shl nuw i8 1, %36
  %38 = or i8 %35, %37
  store i8 %38, ptr %34, align 1, !tbaa !8
  %39 = icmp ult i16 %29, 512
  br i1 %39, label %40, label %50

40:                                               ; preds = %27
  %41 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %42 = lshr i16 %41, 9
  %43 = trunc nuw nsw i16 %42 to i8
  %44 = getelementptr inbounds nuw i8, ptr @jt_tx, i16 %29
  store i8 %43, ptr %44, align 1, !tbaa !8
  %45 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %46 = lshr i16 %45, 9
  %47 = trunc nuw nsw i16 %46 to i8
  %48 = getelementptr inbounds nuw i8, ptr @jt_ty, i16 %29
  store i8 %47, ptr %48, align 1, !tbaa !8
  %49 = add nuw nsw i16 %29, 1
  br label %50

50:                                               ; preds = %40, %27
  %51 = phi i16 [ %49, %40 ], [ %29, %27 ]
  %52 = add nuw nsw i16 %28, 1
  %53 = icmp eq i16 %52, 512
  br i1 %53, label %60, label %27, !llvm.loop !12

54:                                               ; preds = %60
  %55 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %56 = xor i16 %55, %70
  %57 = tail call i16 @llvm.fshl.i16(i16 %56, i16 %56, i16 1)
  %58 = mul i16 %57, 25173
  %59 = add i16 %58, 13849
  br label %74

60:                                               ; preds = %50, %60
  %61 = phi i8 [ %73, %60 ], [ 0, %50 ]
  %62 = phi i8 [ %71, %60 ], [ 0, %50 ]
  %63 = phi i16 [ %70, %60 ], [ 4660, %50 ]
  %64 = zext nneg i8 %61 to i16
  %65 = getelementptr i8, ptr @jt_vm, i16 %64
  %66 = load i16, ptr %65, align 1, !tbaa !2
  %67 = xor i16 %66, %63
  %68 = tail call i16 @llvm.fshl.i16(i16 %67, i16 %67, i16 1)
  %69 = mul i16 %68, 25173
  %70 = add i16 %69, 13849
  %71 = add nuw nsw i8 %62, 1
  %72 = icmp eq i8 %71, 4
  %73 = add nuw nsw i8 %61, 2
  br i1 %72, label %54, label %60, !llvm.loop !13

74:                                               ; preds = %74, %54
  %75 = phi i16 [ %59, %54 ], [ %84, %74 ]
  %76 = phi i16 [ 0, %54 ], [ %82, %74 ]
  %77 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %76
  %78 = load i8, ptr %77, align 1, !tbaa !8
  %79 = zext i8 %78 to i16
  %80 = xor i16 %75, %79
  %81 = tail call i16 @llvm.fshl.i16(i16 %80, i16 %80, i16 1)
  %82 = add nuw nsw i16 %76, 1
  %83 = mul i16 %81, 25173
  %84 = add i16 %83, 13849
  %85 = icmp eq i16 %82, 256
  br i1 %85, label %86, label %74, !llvm.loop !14

86:                                               ; preds = %74, %86
  %87 = phi i8 [ %97, %86 ], [ 0, %74 ]
  %88 = phi i16 [ %96, %86 ], [ %84, %74 ]
  %89 = zext nneg i8 %87 to i16
  %90 = getelementptr i8, ptr @jt_seen, i16 %89
  %91 = load i8, ptr %90, align 1, !tbaa !8
  %92 = zext i8 %91 to i16
  %93 = xor i16 %88, %92
  %94 = tail call i16 @llvm.fshl.i16(i16 %93, i16 %93, i16 1)
  %95 = mul i16 %94, 25173
  %96 = add i16 %95, 13849
  %97 = add nuw nsw i8 %87, 1
  %98 = icmp eq i8 %97, 32
  br i1 %98, label %99, label %86, !llvm.loop !15

99:                                               ; preds = %86, %99
  %100 = phi i16 [ %114, %99 ], [ 0, %86 ]
  %101 = phi i16 [ %113, %99 ], [ %96, %86 ]
  %102 = getelementptr inbounds nuw i8, ptr @jt_tx, i16 %100
  %103 = load i8, ptr %102, align 1, !tbaa !8
  %104 = zext i8 %103 to i16
  %105 = getelementptr inbounds nuw i8, ptr @jt_ty, i16 %100
  %106 = load i8, ptr %105, align 1, !tbaa !8
  %107 = zext i8 %106 to i16
  %108 = shl nuw i16 %107, 8
  %109 = or disjoint i16 %108, %104
  %110 = xor i16 %109, %101
  %111 = tail call i16 @llvm.fshl.i16(i16 %110, i16 %110, i16 1)
  %112 = mul i16 %111, 25173
  %113 = add i16 %112, 13849
  %114 = add nuw i16 %100, 1
  %115 = icmp eq i16 %114, %51
  br i1 %115, label %116, label %99, !llvm.loop !16

116:                                              ; preds = %99
  store volatile i16 %113, ptr @corpus_result, align 1, !tbaa !2
  br label %117

117:                                              ; preds = %117, %116
  tail call void asm sideeffect "wai", ""() #5, !srcloc !17
  br label %117
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc void @jt_exec(i8 noundef zeroext %0) unnamed_addr #1 {
  switch i8 %0, label %1418 [
    i8 0, label %2
    i8 1, label %5
    i8 2, label %10
    i8 3, label %15
    i8 4, label %20
    i8 5, label %25
    i8 6, label %29
    i8 7, label %34
    i8 8, label %39
    i8 9, label %44
    i8 10, label %49
    i8 11, label %53
    i8 12, label %58
    i8 13, label %63
    i8 14, label %68
    i8 15, label %73
    i8 16, label %77
    i8 17, label %78
    i8 18, label %83
    i8 19, label %88
    i8 20, label %93
    i8 21, label %98
    i8 22, label %99
    i8 23, label %104
    i8 24, label %109
    i8 25, label %114
    i8 26, label %119
    i8 27, label %120
    i8 28, label %125
    i8 29, label %130
    i8 30, label %135
    i8 31, label %140
    i8 32, label %141
    i8 33, label %145
    i8 34, label %150
    i8 35, label %155
    i8 36, label %160
    i8 37, label %165
    i8 38, label %169
    i8 39, label %174
    i8 40, label %179
    i8 41, label %184
    i8 42, label %189
    i8 43, label %193
    i8 44, label %198
    i8 45, label %203
    i8 46, label %208
    i8 47, label %213
    i8 48, label %217
    i8 49, label %220
    i8 50, label %225
    i8 51, label %230
    i8 52, label %235
    i8 53, label %240
    i8 54, label %243
    i8 55, label %248
    i8 56, label %253
    i8 57, label %258
    i8 58, label %263
    i8 59, label %266
    i8 60, label %271
    i8 61, label %276
    i8 62, label %281
    i8 63, label %286
    i8 64, label %289
    i8 65, label %290
    i8 66, label %295
    i8 67, label %300
    i8 68, label %305
    i8 69, label %310
    i8 70, label %314
    i8 71, label %319
    i8 72, label %324
    i8 73, label %329
    i8 74, label %334
    i8 75, label %338
    i8 76, label %343
    i8 77, label %348
    i8 78, label %353
    i8 79, label %358
    i8 80, label %362
    i8 81, label %366
    i8 82, label %371
    i8 83, label %376
    i8 84, label %381
    i8 85, label %386
    i8 86, label %390
    i8 87, label %395
    i8 88, label %400
    i8 89, label %405
    i8 90, label %410
    i8 91, label %414
    i8 92, label %419
    i8 93, label %424
    i8 94, label %429
    i8 95, label %434
    i8 96, label %438
    i8 97, label %452
    i8 98, label %466
    i8 99, label %480
    i8 100, label %494
    i8 101, label %508
    i8 102, label %522
    i8 103, label %536
    i8 104, label %550
    i8 105, label %564
    i8 106, label %578
    i8 107, label %592
    i8 108, label %606
    i8 109, label %620
    i8 110, label %634
    i8 111, label %648
    i8 112, label %662
    i8 113, label %669
    i8 114, label %677
    i8 115, label %685
    i8 116, label %693
    i8 117, label %701
    i8 118, label %708
    i8 119, label %716
    i8 120, label %724
    i8 121, label %732
    i8 122, label %740
    i8 123, label %747
    i8 124, label %755
    i8 125, label %763
    i8 126, label %771
    i8 127, label %779
    i8 -128, label %786
    i8 -127, label %791
    i8 -126, label %797
    i8 -125, label %803
    i8 -124, label %809
    i8 -123, label %815
    i8 -122, label %820
    i8 -121, label %826
    i8 -120, label %832
    i8 -119, label %838
    i8 -118, label %844
    i8 -117, label %849
    i8 -116, label %855
    i8 -115, label %861
    i8 -114, label %867
    i8 -113, label %873
    i8 -112, label %878
    i8 -111, label %883
    i8 -110, label %889
    i8 -109, label %895
    i8 -108, label %901
    i8 -107, label %907
    i8 -106, label %912
    i8 -105, label %918
    i8 -104, label %924
    i8 -103, label %930
    i8 -102, label %936
    i8 -101, label %941
    i8 -100, label %947
    i8 -99, label %953
    i8 -98, label %959
    i8 -97, label %965
    i8 -96, label %970
    i8 -95, label %976
    i8 -94, label %983
    i8 -93, label %990
    i8 -92, label %997
    i8 -91, label %1004
    i8 -90, label %1010
    i8 -89, label %1017
    i8 -88, label %1024
    i8 -87, label %1031
    i8 -86, label %1038
    i8 -85, label %1044
    i8 -84, label %1051
    i8 -83, label %1058
    i8 -82, label %1065
    i8 -81, label %1072
    i8 -80, label %1419
    i8 -79, label %1078
    i8 -78, label %1082
    i8 -77, label %1086
    i8 -76, label %1090
    i8 -75, label %1419
    i8 -74, label %1094
    i8 -73, label %1098
    i8 -72, label %1102
    i8 -71, label %1106
    i8 -70, label %1419
    i8 -69, label %1110
    i8 -68, label %1114
    i8 -67, label %1118
    i8 -66, label %1122
    i8 -65, label %1419
    i8 -64, label %1419
    i8 -63, label %1126
    i8 -62, label %1131
    i8 -61, label %1136
    i8 -60, label %1141
    i8 -59, label %1419
    i8 -58, label %1146
    i8 -57, label %1151
    i8 -56, label %1156
    i8 -55, label %1161
    i8 -54, label %1419
    i8 -53, label %1166
    i8 -52, label %1171
    i8 -51, label %1176
    i8 -50, label %1181
    i8 -49, label %1419
    i8 -48, label %1186
    i8 -47, label %1190
    i8 -46, label %1195
    i8 -45, label %1200
    i8 -44, label %1205
    i8 -43, label %1210
    i8 -42, label %1214
    i8 -41, label %1219
    i8 -40, label %1224
    i8 -39, label %1229
    i8 -38, label %1234
    i8 -37, label %1238
    i8 -36, label %1243
    i8 -35, label %1248
    i8 -34, label %1253
    i8 -33, label %1258
    i8 -32, label %1262
    i8 -31, label %1265
    i8 -30, label %1268
    i8 -29, label %1271
    i8 -28, label %1274
    i8 -27, label %1277
    i8 -26, label %1280
    i8 -25, label %1283
    i8 -24, label %1286
    i8 -23, label %1289
    i8 -22, label %1292
    i8 -21, label %1295
    i8 -20, label %1298
    i8 -19, label %1301
    i8 -18, label %1304
    i8 -17, label %1307
    i8 -16, label %1310
    i8 -15, label %1316
    i8 -14, label %1323
    i8 -13, label %1330
    i8 -12, label %1337
    i8 -11, label %1344
    i8 -10, label %1350
    i8 -9, label %1357
    i8 -8, label %1364
    i8 -7, label %1371
    i8 -6, label %1378
    i8 -5, label %1384
    i8 -4, label %1391
    i8 -3, label %1398
    i8 -2, label %1405
    i8 -1, label %1412
  ]

2:                                                ; preds = %1
  %3 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %4 = shl i16 %3, 1
  store i16 %4, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

5:                                                ; preds = %1
  %6 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %7 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %8 = add i16 %6, 1
  %9 = add i16 %8, %7
  store i16 %9, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

10:                                               ; preds = %1
  %11 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %12 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %13 = add i16 %11, 2
  %14 = add i16 %13, %12
  store i16 %14, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

15:                                               ; preds = %1
  %16 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %17 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %18 = add i16 %16, 3
  %19 = add i16 %18, %17
  store i16 %19, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

20:                                               ; preds = %1
  %21 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %22 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %23 = add i16 %21, 4
  %24 = add i16 %23, %22
  store i16 %24, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

25:                                               ; preds = %1
  %26 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %27 = shl i16 %26, 1
  %28 = add i16 %27, 5
  store i16 %28, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

29:                                               ; preds = %1
  %30 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %31 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %32 = add i16 %30, 6
  %33 = add i16 %32, %31
  store i16 %33, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

34:                                               ; preds = %1
  %35 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %36 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %37 = add i16 %35, 7
  %38 = add i16 %37, %36
  store i16 %38, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

39:                                               ; preds = %1
  %40 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %41 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %42 = add i16 %40, 8
  %43 = add i16 %42, %41
  store i16 %43, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

44:                                               ; preds = %1
  %45 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %46 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %47 = add i16 %45, 9
  %48 = add i16 %47, %46
  store i16 %48, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

49:                                               ; preds = %1
  %50 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %51 = shl i16 %50, 1
  %52 = add i16 %51, 10
  store i16 %52, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

53:                                               ; preds = %1
  %54 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %55 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %56 = add i16 %54, 11
  %57 = add i16 %56, %55
  store i16 %57, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

58:                                               ; preds = %1
  %59 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %60 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %61 = add i16 %59, 12
  %62 = add i16 %61, %60
  store i16 %62, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

63:                                               ; preds = %1
  %64 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %65 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %66 = add i16 %64, 13
  %67 = add i16 %66, %65
  store i16 %67, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

68:                                               ; preds = %1
  %69 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %70 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %71 = add i16 %69, 14
  %72 = add i16 %71, %70
  store i16 %72, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

73:                                               ; preds = %1
  %74 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %75 = shl i16 %74, 1
  %76 = add i16 %75, 15
  store i16 %76, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

77:                                               ; preds = %1
  store i16 -16, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

78:                                               ; preds = %1
  %79 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %80 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %81 = add i16 %79, -17
  %82 = sub i16 %81, %80
  store i16 %82, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

83:                                               ; preds = %1
  %84 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %85 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %86 = add i16 %84, -18
  %87 = sub i16 %86, %85
  store i16 %87, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

88:                                               ; preds = %1
  %89 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %90 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %91 = add i16 %89, -19
  %92 = sub i16 %91, %90
  store i16 %92, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

93:                                               ; preds = %1
  %94 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %95 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %96 = add i16 %94, -20
  %97 = sub i16 %96, %95
  store i16 %97, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

98:                                               ; preds = %1
  store i16 -21, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

99:                                               ; preds = %1
  %100 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %101 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %102 = add i16 %100, -22
  %103 = sub i16 %102, %101
  store i16 %103, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

104:                                              ; preds = %1
  %105 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %106 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %107 = add i16 %105, -23
  %108 = sub i16 %107, %106
  store i16 %108, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

109:                                              ; preds = %1
  %110 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %111 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %112 = add i16 %110, -24
  %113 = sub i16 %112, %111
  store i16 %113, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

114:                                              ; preds = %1
  %115 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %116 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %117 = add i16 %115, -25
  %118 = sub i16 %117, %116
  store i16 %118, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

119:                                              ; preds = %1
  store i16 -26, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

120:                                              ; preds = %1
  %121 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %122 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %123 = add i16 %121, -27
  %124 = sub i16 %123, %122
  store i16 %124, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

125:                                              ; preds = %1
  %126 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %127 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %128 = add i16 %126, -28
  %129 = sub i16 %128, %127
  store i16 %129, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

130:                                              ; preds = %1
  %131 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %132 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %133 = add i16 %131, -29
  %134 = sub i16 %133, %132
  store i16 %134, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

135:                                              ; preds = %1
  %136 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %137 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %138 = add i16 %136, -30
  %139 = sub i16 %138, %137
  store i16 %139, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

140:                                              ; preds = %1
  store i16 -31, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

141:                                              ; preds = %1
  %142 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %143 = add i16 %142, 32
  %144 = xor i16 %143, %142
  store i16 %144, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

145:                                              ; preds = %1
  %146 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %147 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %148 = add i16 %147, 33
  %149 = xor i16 %148, %146
  store i16 %149, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

150:                                              ; preds = %1
  %151 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %152 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %153 = add i16 %152, 34
  %154 = xor i16 %153, %151
  store i16 %154, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

155:                                              ; preds = %1
  %156 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %157 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %158 = add i16 %157, 35
  %159 = xor i16 %158, %156
  store i16 %159, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

160:                                              ; preds = %1
  %161 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %162 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %163 = add i16 %162, 36
  %164 = xor i16 %163, %161
  store i16 %164, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

165:                                              ; preds = %1
  %166 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %167 = add i16 %166, 37
  %168 = xor i16 %167, %166
  store i16 %168, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

169:                                              ; preds = %1
  %170 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %171 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %172 = add i16 %171, 38
  %173 = xor i16 %172, %170
  store i16 %173, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

174:                                              ; preds = %1
  %175 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %176 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %177 = add i16 %176, 39
  %178 = xor i16 %177, %175
  store i16 %178, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

179:                                              ; preds = %1
  %180 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %181 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %182 = add i16 %181, 40
  %183 = xor i16 %182, %180
  store i16 %183, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

184:                                              ; preds = %1
  %185 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %186 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %187 = add i16 %186, 41
  %188 = xor i16 %187, %185
  store i16 %188, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

189:                                              ; preds = %1
  %190 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %191 = add i16 %190, 42
  %192 = xor i16 %191, %190
  store i16 %192, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

193:                                              ; preds = %1
  %194 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %195 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %196 = add i16 %195, 43
  %197 = xor i16 %196, %194
  store i16 %197, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

198:                                              ; preds = %1
  %199 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %200 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %201 = add i16 %200, 44
  %202 = xor i16 %201, %199
  store i16 %202, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

203:                                              ; preds = %1
  %204 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %205 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %206 = add i16 %205, 45
  %207 = xor i16 %206, %204
  store i16 %207, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

208:                                              ; preds = %1
  %209 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %210 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %211 = add i16 %210, 46
  %212 = xor i16 %211, %209
  store i16 %212, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

213:                                              ; preds = %1
  %214 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %215 = add i16 %214, 47
  %216 = xor i16 %215, %214
  store i16 %216, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

217:                                              ; preds = %1
  %218 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %219 = mul i16 %218, 98
  store i16 %219, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

220:                                              ; preds = %1
  %221 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %222 = mul i16 %221, 99
  %223 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %224 = add i16 %222, %223
  store i16 %224, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

225:                                              ; preds = %1
  %226 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %227 = mul i16 %226, 101
  %228 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %229 = add i16 %227, %228
  store i16 %229, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

230:                                              ; preds = %1
  %231 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %232 = mul i16 %231, 103
  %233 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %234 = add i16 %232, %233
  store i16 %234, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

235:                                              ; preds = %1
  %236 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %237 = mul i16 %236, 105
  %238 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %239 = add i16 %237, %238
  store i16 %239, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

240:                                              ; preds = %1
  %241 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %242 = mul i16 %241, 108
  store i16 %242, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

243:                                              ; preds = %1
  %244 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %245 = mul i16 %244, 109
  %246 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %247 = add i16 %245, %246
  store i16 %247, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

248:                                              ; preds = %1
  %249 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %250 = mul i16 %249, 111
  %251 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %252 = add i16 %250, %251
  store i16 %252, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

253:                                              ; preds = %1
  %254 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %255 = mul i16 %254, 113
  %256 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %257 = add i16 %255, %256
  store i16 %257, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

258:                                              ; preds = %1
  %259 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %260 = mul i16 %259, 115
  %261 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %262 = add i16 %260, %261
  store i16 %262, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

263:                                              ; preds = %1
  %264 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %265 = mul i16 %264, 118
  store i16 %265, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

266:                                              ; preds = %1
  %267 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %268 = mul i16 %267, 119
  %269 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %270 = add i16 %268, %269
  store i16 %270, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

271:                                              ; preds = %1
  %272 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %273 = mul i16 %272, 121
  %274 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %275 = add i16 %273, %274
  store i16 %275, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

276:                                              ; preds = %1
  %277 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %278 = mul i16 %277, 123
  %279 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %280 = add i16 %278, %279
  store i16 %280, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

281:                                              ; preds = %1
  %282 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %283 = mul i16 %282, 125
  %284 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %285 = add i16 %283, %284
  store i16 %285, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

286:                                              ; preds = %1
  %287 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %288 = shl i16 %287, 7
  store i16 %288, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

289:                                              ; preds = %1
  store i16 0, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

290:                                              ; preds = %1
  %291 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %292 = tail call i16 @llvm.fshl.i16(i16 %291, i16 %291, i16 1)
  %293 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %294 = xor i16 %293, %292
  store i16 %294, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

295:                                              ; preds = %1
  %296 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %297 = tail call i16 @llvm.fshl.i16(i16 %296, i16 %296, i16 2)
  %298 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %299 = xor i16 %298, %297
  store i16 %299, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

300:                                              ; preds = %1
  %301 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %302 = tail call i16 @llvm.fshl.i16(i16 %301, i16 %301, i16 3)
  %303 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %304 = xor i16 %303, %302
  store i16 %304, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

305:                                              ; preds = %1
  %306 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %307 = tail call i16 @llvm.fshl.i16(i16 %306, i16 %306, i16 4)
  %308 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %309 = xor i16 %308, %307
  store i16 %309, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

310:                                              ; preds = %1
  %311 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %312 = tail call i16 @llvm.fshl.i16(i16 %311, i16 %311, i16 5)
  %313 = xor i16 %312, %311
  store i16 %313, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

314:                                              ; preds = %1
  %315 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %316 = tail call i16 @llvm.fshl.i16(i16 %315, i16 %315, i16 6)
  %317 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %318 = xor i16 %317, %316
  store i16 %318, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

319:                                              ; preds = %1
  %320 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %321 = tail call i16 @llvm.fshl.i16(i16 %320, i16 %320, i16 7)
  %322 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %323 = xor i16 %322, %321
  store i16 %323, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

324:                                              ; preds = %1
  %325 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %326 = tail call i16 @llvm.bswap.i16(i16 %325)
  %327 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %328 = xor i16 %327, %326
  store i16 %328, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

329:                                              ; preds = %1
  %330 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %331 = tail call i16 @llvm.fshl.i16(i16 %330, i16 %330, i16 9)
  %332 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %333 = xor i16 %332, %331
  store i16 %333, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

334:                                              ; preds = %1
  %335 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %336 = tail call i16 @llvm.fshl.i16(i16 %335, i16 %335, i16 10)
  %337 = xor i16 %336, %335
  store i16 %337, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

338:                                              ; preds = %1
  %339 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %340 = tail call i16 @llvm.fshl.i16(i16 %339, i16 %339, i16 11)
  %341 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %342 = xor i16 %341, %340
  store i16 %342, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

343:                                              ; preds = %1
  %344 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %345 = tail call i16 @llvm.fshl.i16(i16 %344, i16 %344, i16 12)
  %346 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %347 = xor i16 %346, %345
  store i16 %347, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

348:                                              ; preds = %1
  %349 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %350 = tail call i16 @llvm.fshl.i16(i16 %349, i16 %349, i16 13)
  %351 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %352 = xor i16 %351, %350
  store i16 %352, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

353:                                              ; preds = %1
  %354 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %355 = tail call i16 @llvm.fshl.i16(i16 %354, i16 %354, i16 14)
  %356 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %357 = xor i16 %356, %355
  store i16 %357, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

358:                                              ; preds = %1
  %359 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %360 = tail call i16 @llvm.fshl.i16(i16 %359, i16 %359, i16 15)
  %361 = xor i16 %360, %359
  store i16 %361, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

362:                                              ; preds = %1
  %363 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %364 = lshr i16 %363, 1
  %365 = add i16 %364, %363
  store i16 %365, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

366:                                              ; preds = %1
  %367 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %368 = lshr i16 %367, 2
  %369 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %370 = add i16 %368, %369
  store i16 %370, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

371:                                              ; preds = %1
  %372 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %373 = lshr i16 %372, 3
  %374 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %375 = add i16 %373, %374
  store i16 %375, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

376:                                              ; preds = %1
  %377 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %378 = lshr i16 %377, 4
  %379 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %380 = add i16 %378, %379
  store i16 %380, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

381:                                              ; preds = %1
  %382 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %383 = lshr i16 %382, 5
  %384 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %385 = add i16 %383, %384
  store i16 %385, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

386:                                              ; preds = %1
  %387 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %388 = lshr i16 %387, 6
  %389 = add i16 %388, %387
  store i16 %389, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

390:                                              ; preds = %1
  %391 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %392 = lshr i16 %391, 7
  %393 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %394 = add i16 %392, %393
  store i16 %394, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

395:                                              ; preds = %1
  %396 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %397 = lshr i16 %396, 8
  %398 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %399 = add i16 %397, %398
  store i16 %399, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

400:                                              ; preds = %1
  %401 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %402 = lshr i16 %401, 1
  %403 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %404 = add i16 %402, %403
  store i16 %404, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

405:                                              ; preds = %1
  %406 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %407 = lshr i16 %406, 2
  %408 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %409 = add i16 %407, %408
  store i16 %409, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

410:                                              ; preds = %1
  %411 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %412 = lshr i16 %411, 3
  %413 = add i16 %412, %411
  store i16 %413, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

414:                                              ; preds = %1
  %415 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %416 = lshr i16 %415, 4
  %417 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %418 = add i16 %416, %417
  store i16 %418, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

419:                                              ; preds = %1
  %420 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %421 = lshr i16 %420, 5
  %422 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %423 = add i16 %421, %422
  store i16 %423, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

424:                                              ; preds = %1
  %425 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %426 = lshr i16 %425, 6
  %427 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %428 = add i16 %426, %427
  store i16 %428, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

429:                                              ; preds = %1
  %430 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %431 = lshr i16 %430, 7
  %432 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %433 = add i16 %431, %432
  store i16 %433, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

434:                                              ; preds = %1
  %435 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %436 = lshr i16 %435, 8
  %437 = add i16 %436, %435
  store i16 %437, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

438:                                              ; preds = %1
  %439 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %440 = add i16 %439, 96
  %441 = and i16 %440, 255
  %442 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %441
  %443 = load i8, ptr %442, align 1, !tbaa !8
  %444 = zext i8 %443 to i16
  %445 = add i16 %439, 97
  %446 = and i16 %445, 255
  %447 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %446
  %448 = load i8, ptr %447, align 1, !tbaa !8
  %449 = zext i8 %448 to i16
  %450 = shl nuw i16 %449, 8
  %451 = or disjoint i16 %450, %444
  store i16 %451, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

452:                                              ; preds = %1
  %453 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %454 = add i16 %453, 97
  %455 = and i16 %454, 255
  %456 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %455
  %457 = load i8, ptr %456, align 1, !tbaa !8
  %458 = zext i8 %457 to i16
  %459 = add i16 %453, 98
  %460 = and i16 %459, 255
  %461 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %460
  %462 = load i8, ptr %461, align 1, !tbaa !8
  %463 = zext i8 %462 to i16
  %464 = shl nuw i16 %463, 8
  %465 = or disjoint i16 %464, %458
  store i16 %465, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

466:                                              ; preds = %1
  %467 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %468 = add i16 %467, 98
  %469 = and i16 %468, 255
  %470 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %469
  %471 = load i8, ptr %470, align 1, !tbaa !8
  %472 = zext i8 %471 to i16
  %473 = add i16 %467, 99
  %474 = and i16 %473, 255
  %475 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %474
  %476 = load i8, ptr %475, align 1, !tbaa !8
  %477 = zext i8 %476 to i16
  %478 = shl nuw i16 %477, 8
  %479 = or disjoint i16 %478, %472
  store i16 %479, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

480:                                              ; preds = %1
  %481 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %482 = add i16 %481, 99
  %483 = and i16 %482, 255
  %484 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %483
  %485 = load i8, ptr %484, align 1, !tbaa !8
  %486 = zext i8 %485 to i16
  %487 = add i16 %481, 100
  %488 = and i16 %487, 255
  %489 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %488
  %490 = load i8, ptr %489, align 1, !tbaa !8
  %491 = zext i8 %490 to i16
  %492 = shl nuw i16 %491, 8
  %493 = or disjoint i16 %492, %486
  store i16 %493, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

494:                                              ; preds = %1
  %495 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %496 = add i16 %495, 100
  %497 = and i16 %496, 255
  %498 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %497
  %499 = load i8, ptr %498, align 1, !tbaa !8
  %500 = zext i8 %499 to i16
  %501 = add i16 %495, 101
  %502 = and i16 %501, 255
  %503 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %502
  %504 = load i8, ptr %503, align 1, !tbaa !8
  %505 = zext i8 %504 to i16
  %506 = shl nuw i16 %505, 8
  %507 = or disjoint i16 %506, %500
  store i16 %507, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

508:                                              ; preds = %1
  %509 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %510 = add i16 %509, 101
  %511 = and i16 %510, 255
  %512 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %511
  %513 = load i8, ptr %512, align 1, !tbaa !8
  %514 = zext i8 %513 to i16
  %515 = add i16 %509, 102
  %516 = and i16 %515, 255
  %517 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %516
  %518 = load i8, ptr %517, align 1, !tbaa !8
  %519 = zext i8 %518 to i16
  %520 = shl nuw i16 %519, 8
  %521 = or disjoint i16 %520, %514
  store i16 %521, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

522:                                              ; preds = %1
  %523 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %524 = add i16 %523, 102
  %525 = and i16 %524, 255
  %526 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %525
  %527 = load i8, ptr %526, align 1, !tbaa !8
  %528 = zext i8 %527 to i16
  %529 = add i16 %523, 103
  %530 = and i16 %529, 255
  %531 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %530
  %532 = load i8, ptr %531, align 1, !tbaa !8
  %533 = zext i8 %532 to i16
  %534 = shl nuw i16 %533, 8
  %535 = or disjoint i16 %534, %528
  store i16 %535, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

536:                                              ; preds = %1
  %537 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %538 = add i16 %537, 103
  %539 = and i16 %538, 255
  %540 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %539
  %541 = load i8, ptr %540, align 1, !tbaa !8
  %542 = zext i8 %541 to i16
  %543 = add i16 %537, 104
  %544 = and i16 %543, 255
  %545 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %544
  %546 = load i8, ptr %545, align 1, !tbaa !8
  %547 = zext i8 %546 to i16
  %548 = shl nuw i16 %547, 8
  %549 = or disjoint i16 %548, %542
  store i16 %549, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

550:                                              ; preds = %1
  %551 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %552 = add i16 %551, 104
  %553 = and i16 %552, 255
  %554 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %553
  %555 = load i8, ptr %554, align 1, !tbaa !8
  %556 = zext i8 %555 to i16
  %557 = add i16 %551, 105
  %558 = and i16 %557, 255
  %559 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %558
  %560 = load i8, ptr %559, align 1, !tbaa !8
  %561 = zext i8 %560 to i16
  %562 = shl nuw i16 %561, 8
  %563 = or disjoint i16 %562, %556
  store i16 %563, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

564:                                              ; preds = %1
  %565 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %566 = add i16 %565, 105
  %567 = and i16 %566, 255
  %568 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %567
  %569 = load i8, ptr %568, align 1, !tbaa !8
  %570 = zext i8 %569 to i16
  %571 = add i16 %565, 106
  %572 = and i16 %571, 255
  %573 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %572
  %574 = load i8, ptr %573, align 1, !tbaa !8
  %575 = zext i8 %574 to i16
  %576 = shl nuw i16 %575, 8
  %577 = or disjoint i16 %576, %570
  store i16 %577, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

578:                                              ; preds = %1
  %579 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %580 = add i16 %579, 106
  %581 = and i16 %580, 255
  %582 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %581
  %583 = load i8, ptr %582, align 1, !tbaa !8
  %584 = zext i8 %583 to i16
  %585 = add i16 %579, 107
  %586 = and i16 %585, 255
  %587 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %586
  %588 = load i8, ptr %587, align 1, !tbaa !8
  %589 = zext i8 %588 to i16
  %590 = shl nuw i16 %589, 8
  %591 = or disjoint i16 %590, %584
  store i16 %591, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

592:                                              ; preds = %1
  %593 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %594 = add i16 %593, 107
  %595 = and i16 %594, 255
  %596 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %595
  %597 = load i8, ptr %596, align 1, !tbaa !8
  %598 = zext i8 %597 to i16
  %599 = add i16 %593, 108
  %600 = and i16 %599, 255
  %601 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %600
  %602 = load i8, ptr %601, align 1, !tbaa !8
  %603 = zext i8 %602 to i16
  %604 = shl nuw i16 %603, 8
  %605 = or disjoint i16 %604, %598
  store i16 %605, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

606:                                              ; preds = %1
  %607 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %608 = add i16 %607, 108
  %609 = and i16 %608, 255
  %610 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %609
  %611 = load i8, ptr %610, align 1, !tbaa !8
  %612 = zext i8 %611 to i16
  %613 = add i16 %607, 109
  %614 = and i16 %613, 255
  %615 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %614
  %616 = load i8, ptr %615, align 1, !tbaa !8
  %617 = zext i8 %616 to i16
  %618 = shl nuw i16 %617, 8
  %619 = or disjoint i16 %618, %612
  store i16 %619, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

620:                                              ; preds = %1
  %621 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %622 = add i16 %621, 109
  %623 = and i16 %622, 255
  %624 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %623
  %625 = load i8, ptr %624, align 1, !tbaa !8
  %626 = zext i8 %625 to i16
  %627 = add i16 %621, 110
  %628 = and i16 %627, 255
  %629 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %628
  %630 = load i8, ptr %629, align 1, !tbaa !8
  %631 = zext i8 %630 to i16
  %632 = shl nuw i16 %631, 8
  %633 = or disjoint i16 %632, %626
  store i16 %633, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

634:                                              ; preds = %1
  %635 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %636 = add i16 %635, 110
  %637 = and i16 %636, 255
  %638 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %637
  %639 = load i8, ptr %638, align 1, !tbaa !8
  %640 = zext i8 %639 to i16
  %641 = add i16 %635, 111
  %642 = and i16 %641, 255
  %643 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %642
  %644 = load i8, ptr %643, align 1, !tbaa !8
  %645 = zext i8 %644 to i16
  %646 = shl nuw i16 %645, 8
  %647 = or disjoint i16 %646, %640
  store i16 %647, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

648:                                              ; preds = %1
  %649 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %650 = add i16 %649, 111
  %651 = and i16 %650, 255
  %652 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %651
  %653 = load i8, ptr %652, align 1, !tbaa !8
  %654 = zext i8 %653 to i16
  %655 = add i16 %649, 112
  %656 = and i16 %655, 255
  %657 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %656
  %658 = load i8, ptr %657, align 1, !tbaa !8
  %659 = zext i8 %658 to i16
  %660 = shl nuw i16 %659, 8
  %661 = or disjoint i16 %660, %654
  store i16 %661, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

662:                                              ; preds = %1
  %663 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %664 = add i16 %663, 112
  %665 = trunc i16 %663 to i8
  %666 = xor i8 %665, 112
  %667 = and i16 %664, 255
  %668 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %667
  store i8 %666, ptr %668, align 1, !tbaa !8
  br label %1419

669:                                              ; preds = %1
  %670 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %671 = add i16 %670, 113
  %672 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %673 = trunc i16 %672 to i8
  %674 = xor i8 %673, 113
  %675 = and i16 %671, 255
  %676 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %675
  store i8 %674, ptr %676, align 1, !tbaa !8
  br label %1419

677:                                              ; preds = %1
  %678 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %679 = add i16 %678, 114
  %680 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %681 = trunc i16 %680 to i8
  %682 = xor i8 %681, 114
  %683 = and i16 %679, 255
  %684 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %683
  store i8 %682, ptr %684, align 1, !tbaa !8
  br label %1419

685:                                              ; preds = %1
  %686 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %687 = add i16 %686, 115
  %688 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %689 = trunc i16 %688 to i8
  %690 = xor i8 %689, 115
  %691 = and i16 %687, 255
  %692 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %691
  store i8 %690, ptr %692, align 1, !tbaa !8
  br label %1419

693:                                              ; preds = %1
  %694 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %695 = add i16 %694, 116
  %696 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %697 = trunc i16 %696 to i8
  %698 = xor i8 %697, 116
  %699 = and i16 %695, 255
  %700 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %699
  store i8 %698, ptr %700, align 1, !tbaa !8
  br label %1419

701:                                              ; preds = %1
  %702 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %703 = add i16 %702, 117
  %704 = trunc i16 %702 to i8
  %705 = xor i8 %704, 117
  %706 = and i16 %703, 255
  %707 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %706
  store i8 %705, ptr %707, align 1, !tbaa !8
  br label %1419

708:                                              ; preds = %1
  %709 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %710 = add i16 %709, 118
  %711 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %712 = trunc i16 %711 to i8
  %713 = xor i8 %712, 118
  %714 = and i16 %710, 255
  %715 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %714
  store i8 %713, ptr %715, align 1, !tbaa !8
  br label %1419

716:                                              ; preds = %1
  %717 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %718 = add i16 %717, 119
  %719 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %720 = trunc i16 %719 to i8
  %721 = xor i8 %720, 119
  %722 = and i16 %718, 255
  %723 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %722
  store i8 %721, ptr %723, align 1, !tbaa !8
  br label %1419

724:                                              ; preds = %1
  %725 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %726 = add i16 %725, 120
  %727 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %728 = trunc i16 %727 to i8
  %729 = xor i8 %728, 120
  %730 = and i16 %726, 255
  %731 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %730
  store i8 %729, ptr %731, align 1, !tbaa !8
  br label %1419

732:                                              ; preds = %1
  %733 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %734 = add i16 %733, 121
  %735 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %736 = trunc i16 %735 to i8
  %737 = xor i8 %736, 121
  %738 = and i16 %734, 255
  %739 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %738
  store i8 %737, ptr %739, align 1, !tbaa !8
  br label %1419

740:                                              ; preds = %1
  %741 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %742 = add i16 %741, 122
  %743 = trunc i16 %741 to i8
  %744 = xor i8 %743, 122
  %745 = and i16 %742, 255
  %746 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %745
  store i8 %744, ptr %746, align 1, !tbaa !8
  br label %1419

747:                                              ; preds = %1
  %748 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %749 = add i16 %748, 123
  %750 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %751 = trunc i16 %750 to i8
  %752 = xor i8 %751, 123
  %753 = and i16 %749, 255
  %754 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %753
  store i8 %752, ptr %754, align 1, !tbaa !8
  br label %1419

755:                                              ; preds = %1
  %756 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %757 = add i16 %756, 124
  %758 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %759 = trunc i16 %758 to i8
  %760 = xor i8 %759, 124
  %761 = and i16 %757, 255
  %762 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %761
  store i8 %760, ptr %762, align 1, !tbaa !8
  br label %1419

763:                                              ; preds = %1
  %764 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %765 = add i16 %764, 125
  %766 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %767 = trunc i16 %766 to i8
  %768 = xor i8 %767, 125
  %769 = and i16 %765, 255
  %770 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %769
  store i8 %768, ptr %770, align 1, !tbaa !8
  br label %1419

771:                                              ; preds = %1
  %772 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %773 = add i16 %772, 126
  %774 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %775 = trunc i16 %774 to i8
  %776 = xor i8 %775, 126
  %777 = and i16 %773, 255
  %778 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %777
  store i8 %776, ptr %778, align 1, !tbaa !8
  br label %1419

779:                                              ; preds = %1
  %780 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %781 = add i16 %780, 127
  %782 = trunc i16 %780 to i8
  %783 = xor i8 %782, 127
  %784 = and i16 %781, 255
  %785 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %784
  store i8 %783, ptr %785, align 1, !tbaa !8
  br label %1419

786:                                              ; preds = %1
  %787 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %788 = icmp ugt i16 %787, -129
  br i1 %788, label %789, label %1419

789:                                              ; preds = %786
  %790 = add nsw i16 %787, 128
  store i16 %790, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

791:                                              ; preds = %1
  %792 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %793 = add i16 %792, 129
  %794 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %795 = icmp ult i16 %793, %794
  br i1 %795, label %796, label %1419

796:                                              ; preds = %791
  store i16 %793, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

797:                                              ; preds = %1
  %798 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %799 = add i16 %798, 130
  %800 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %801 = icmp ult i16 %799, %800
  br i1 %801, label %802, label %1419

802:                                              ; preds = %797
  store i16 %799, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

803:                                              ; preds = %1
  %804 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %805 = add i16 %804, 131
  %806 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %807 = icmp ult i16 %805, %806
  br i1 %807, label %808, label %1419

808:                                              ; preds = %803
  store i16 %805, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

809:                                              ; preds = %1
  %810 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %811 = add i16 %810, 132
  %812 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %813 = icmp ult i16 %811, %812
  br i1 %813, label %814, label %1419

814:                                              ; preds = %809
  store i16 %811, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

815:                                              ; preds = %1
  %816 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %817 = icmp ugt i16 %816, -134
  br i1 %817, label %818, label %1419

818:                                              ; preds = %815
  %819 = add nsw i16 %816, 133
  store i16 %819, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

820:                                              ; preds = %1
  %821 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %822 = add i16 %821, 134
  %823 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %824 = icmp ult i16 %822, %823
  br i1 %824, label %825, label %1419

825:                                              ; preds = %820
  store i16 %822, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

826:                                              ; preds = %1
  %827 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %828 = add i16 %827, 135
  %829 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %830 = icmp ult i16 %828, %829
  br i1 %830, label %831, label %1419

831:                                              ; preds = %826
  store i16 %828, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

832:                                              ; preds = %1
  %833 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %834 = add i16 %833, 136
  %835 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %836 = icmp ult i16 %834, %835
  br i1 %836, label %837, label %1419

837:                                              ; preds = %832
  store i16 %834, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

838:                                              ; preds = %1
  %839 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %840 = add i16 %839, 137
  %841 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %842 = icmp ult i16 %840, %841
  br i1 %842, label %843, label %1419

843:                                              ; preds = %838
  store i16 %840, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

844:                                              ; preds = %1
  %845 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %846 = icmp ugt i16 %845, -139
  br i1 %846, label %847, label %1419

847:                                              ; preds = %844
  %848 = add nsw i16 %845, 138
  store i16 %848, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

849:                                              ; preds = %1
  %850 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %851 = add i16 %850, 139
  %852 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %853 = icmp ult i16 %851, %852
  br i1 %853, label %854, label %1419

854:                                              ; preds = %849
  store i16 %851, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

855:                                              ; preds = %1
  %856 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %857 = add i16 %856, 140
  %858 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %859 = icmp ult i16 %857, %858
  br i1 %859, label %860, label %1419

860:                                              ; preds = %855
  store i16 %857, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

861:                                              ; preds = %1
  %862 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %863 = add i16 %862, 141
  %864 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %865 = icmp ult i16 %863, %864
  br i1 %865, label %866, label %1419

866:                                              ; preds = %861
  store i16 %863, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

867:                                              ; preds = %1
  %868 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %869 = add i16 %868, 142
  %870 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %871 = icmp ult i16 %869, %870
  br i1 %871, label %872, label %1419

872:                                              ; preds = %867
  store i16 %869, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

873:                                              ; preds = %1
  %874 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %875 = icmp ugt i16 %874, -144
  br i1 %875, label %876, label %1419

876:                                              ; preds = %873
  %877 = add nsw i16 %874, 143
  store i16 %877, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

878:                                              ; preds = %1
  %879 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %880 = icmp ult i16 %879, -144
  br i1 %880, label %881, label %1419

881:                                              ; preds = %878
  %882 = add nuw i16 %879, 144
  store i16 %882, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

883:                                              ; preds = %1
  %884 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %885 = add i16 %884, 145
  %886 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %887 = icmp ugt i16 %885, %886
  br i1 %887, label %888, label %1419

888:                                              ; preds = %883
  store i16 %885, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

889:                                              ; preds = %1
  %890 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %891 = add i16 %890, 146
  %892 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %893 = icmp ugt i16 %891, %892
  br i1 %893, label %894, label %1419

894:                                              ; preds = %889
  store i16 %891, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

895:                                              ; preds = %1
  %896 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %897 = add i16 %896, 147
  %898 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %899 = icmp ugt i16 %897, %898
  br i1 %899, label %900, label %1419

900:                                              ; preds = %895
  store i16 %897, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

901:                                              ; preds = %1
  %902 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %903 = add i16 %902, 148
  %904 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %905 = icmp ugt i16 %903, %904
  br i1 %905, label %906, label %1419

906:                                              ; preds = %901
  store i16 %903, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

907:                                              ; preds = %1
  %908 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %909 = icmp ult i16 %908, -149
  br i1 %909, label %910, label %1419

910:                                              ; preds = %907
  %911 = add nuw i16 %908, 149
  store i16 %911, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

912:                                              ; preds = %1
  %913 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %914 = add i16 %913, 150
  %915 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %916 = icmp ugt i16 %914, %915
  br i1 %916, label %917, label %1419

917:                                              ; preds = %912
  store i16 %914, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

918:                                              ; preds = %1
  %919 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %920 = add i16 %919, 151
  %921 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %922 = icmp ugt i16 %920, %921
  br i1 %922, label %923, label %1419

923:                                              ; preds = %918
  store i16 %920, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

924:                                              ; preds = %1
  %925 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %926 = add i16 %925, 152
  %927 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %928 = icmp ugt i16 %926, %927
  br i1 %928, label %929, label %1419

929:                                              ; preds = %924
  store i16 %926, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

930:                                              ; preds = %1
  %931 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %932 = add i16 %931, 153
  %933 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %934 = icmp ugt i16 %932, %933
  br i1 %934, label %935, label %1419

935:                                              ; preds = %930
  store i16 %932, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

936:                                              ; preds = %1
  %937 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %938 = icmp ult i16 %937, -154
  br i1 %938, label %939, label %1419

939:                                              ; preds = %936
  %940 = add nuw i16 %937, 154
  store i16 %940, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

941:                                              ; preds = %1
  %942 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %943 = add i16 %942, 155
  %944 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %945 = icmp ugt i16 %943, %944
  br i1 %945, label %946, label %1419

946:                                              ; preds = %941
  store i16 %943, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

947:                                              ; preds = %1
  %948 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %949 = add i16 %948, 156
  %950 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %951 = icmp ugt i16 %949, %950
  br i1 %951, label %952, label %1419

952:                                              ; preds = %947
  store i16 %949, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

953:                                              ; preds = %1
  %954 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %955 = add i16 %954, 157
  %956 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %957 = icmp ugt i16 %955, %956
  br i1 %957, label %958, label %1419

958:                                              ; preds = %953
  store i16 %955, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

959:                                              ; preds = %1
  %960 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %961 = add i16 %960, 158
  %962 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %963 = icmp ugt i16 %961, %962
  br i1 %963, label %964, label %1419

964:                                              ; preds = %959
  store i16 %961, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

965:                                              ; preds = %1
  %966 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %967 = icmp ult i16 %966, -159
  br i1 %967, label %968, label %1419

968:                                              ; preds = %965
  %969 = add nuw i16 %966, 159
  store i16 %969, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

970:                                              ; preds = %1
  %971 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %972 = mul i16 %971, 321
  %973 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %974 = add i16 %972, %973
  store i16 %974, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %975 = xor i16 %974, %973
  store i16 %975, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

976:                                              ; preds = %1
  %977 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %978 = mul i16 %977, 323
  %979 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %980 = add i16 %978, %979
  store i16 %980, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %981 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %982 = xor i16 %981, %980
  store i16 %982, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

983:                                              ; preds = %1
  %984 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %985 = mul i16 %984, 325
  %986 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %987 = add i16 %985, %986
  store i16 %987, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %988 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %989 = xor i16 %988, %987
  store i16 %989, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

990:                                              ; preds = %1
  %991 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %992 = mul i16 %991, 327
  %993 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %994 = add i16 %992, %993
  store i16 %994, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %995 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %996 = xor i16 %995, %994
  store i16 %996, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

997:                                              ; preds = %1
  %998 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %999 = mul i16 %998, 329
  %1000 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1001 = add i16 %999, %1000
  store i16 %1001, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1002 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1003 = xor i16 %1002, %1001
  store i16 %1003, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1004:                                             ; preds = %1
  %1005 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1006 = mul i16 %1005, 331
  %1007 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1008 = add i16 %1006, %1007
  store i16 %1008, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1009 = xor i16 %1008, %1007
  store i16 %1009, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1010:                                             ; preds = %1
  %1011 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1012 = mul i16 %1011, 333
  %1013 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1014 = add i16 %1012, %1013
  store i16 %1014, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1015 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1016 = xor i16 %1015, %1014
  store i16 %1016, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1017:                                             ; preds = %1
  %1018 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1019 = mul i16 %1018, 335
  %1020 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1021 = add i16 %1019, %1020
  store i16 %1021, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1022 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1023 = xor i16 %1022, %1021
  store i16 %1023, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1024:                                             ; preds = %1
  %1025 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1026 = mul i16 %1025, 337
  %1027 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1028 = add i16 %1026, %1027
  store i16 %1028, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1029 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1030 = xor i16 %1029, %1028
  store i16 %1030, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1031:                                             ; preds = %1
  %1032 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1033 = mul i16 %1032, 339
  %1034 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1035 = add i16 %1033, %1034
  store i16 %1035, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1036 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1037 = xor i16 %1036, %1035
  store i16 %1037, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1038:                                             ; preds = %1
  %1039 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1040 = mul i16 %1039, 341
  %1041 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1042 = add i16 %1040, %1041
  store i16 %1042, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1043 = xor i16 %1042, %1041
  store i16 %1043, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1044:                                             ; preds = %1
  %1045 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1046 = mul i16 %1045, 343
  %1047 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1048 = add i16 %1046, %1047
  store i16 %1048, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1049 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1050 = xor i16 %1049, %1048
  store i16 %1050, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1051:                                             ; preds = %1
  %1052 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1053 = mul i16 %1052, 345
  %1054 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1055 = add i16 %1053, %1054
  store i16 %1055, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1056 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1057 = xor i16 %1056, %1055
  store i16 %1057, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1058:                                             ; preds = %1
  %1059 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1060 = mul i16 %1059, 347
  %1061 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1062 = add i16 %1060, %1061
  store i16 %1062, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1063 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1064 = xor i16 %1063, %1062
  store i16 %1064, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1065:                                             ; preds = %1
  %1066 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1067 = mul i16 %1066, 349
  %1068 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1069 = add i16 %1067, %1068
  store i16 %1069, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1070 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1071 = xor i16 %1070, %1069
  store i16 %1071, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1072:                                             ; preds = %1
  %1073 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1074 = mul i16 %1073, 351
  %1075 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1076 = add i16 %1074, %1075
  store i16 %1076, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1077 = xor i16 %1076, %1075
  store i16 %1077, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1078:                                             ; preds = %1
  %1079 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1080 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1081 = add i16 %1080, 177
  store i16 %1081, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  store i16 %1079, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1082:                                             ; preds = %1
  %1083 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1084 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1085 = add i16 %1084, 178
  store i16 %1085, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  store i16 %1083, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1086:                                             ; preds = %1
  %1087 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1088 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1089 = add i16 %1088, 179
  store i16 %1089, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  store i16 %1087, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1090:                                             ; preds = %1
  %1091 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1092 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1093 = add i16 %1092, 180
  store i16 %1093, ptr @jt_vm, align 1, !tbaa !2
  store i16 %1091, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1094:                                             ; preds = %1
  %1095 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1096 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1097 = add i16 %1096, 182
  store i16 %1097, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  store i16 %1095, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1098:                                             ; preds = %1
  %1099 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1100 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1101 = add i16 %1100, 183
  store i16 %1101, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  store i16 %1099, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1102:                                             ; preds = %1
  %1103 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1104 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1105 = add i16 %1104, 184
  store i16 %1105, ptr @jt_vm, align 1, !tbaa !2
  store i16 %1103, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1106:                                             ; preds = %1
  %1107 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1108 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1109 = add i16 %1108, 185
  store i16 %1109, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  store i16 %1107, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1110:                                             ; preds = %1
  %1111 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1112 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1113 = add i16 %1112, 187
  store i16 %1113, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  store i16 %1111, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1114:                                             ; preds = %1
  %1115 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1116 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1117 = add i16 %1116, 188
  store i16 %1117, ptr @jt_vm, align 1, !tbaa !2
  store i16 %1115, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1118:                                             ; preds = %1
  %1119 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1120 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1121 = add i16 %1120, 189
  store i16 %1121, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  store i16 %1119, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1122:                                             ; preds = %1
  %1123 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1124 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1125 = add i16 %1124, 190
  store i16 %1125, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  store i16 %1123, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1126:                                             ; preds = %1
  %1127 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1128 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1129 = or i16 %1128, 193
  %1130 = and i16 %1129, %1127
  store i16 %1130, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1131:                                             ; preds = %1
  %1132 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1133 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1134 = or i16 %1133, 195
  %1135 = and i16 %1134, %1132
  store i16 %1135, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1136:                                             ; preds = %1
  %1137 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1138 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1139 = or i16 %1138, 195
  %1140 = and i16 %1139, %1137
  store i16 %1140, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1141:                                             ; preds = %1
  %1142 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1143 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1144 = or i16 %1143, 197
  %1145 = and i16 %1144, %1142
  store i16 %1145, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1146:                                             ; preds = %1
  %1147 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1148 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1149 = or i16 %1148, 199
  %1150 = and i16 %1149, %1147
  store i16 %1150, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1151:                                             ; preds = %1
  %1152 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1153 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1154 = or i16 %1153, 199
  %1155 = and i16 %1154, %1152
  store i16 %1155, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1156:                                             ; preds = %1
  %1157 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1158 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1159 = or i16 %1158, 201
  %1160 = and i16 %1159, %1157
  store i16 %1160, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1161:                                             ; preds = %1
  %1162 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1163 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1164 = or i16 %1163, 201
  %1165 = and i16 %1164, %1162
  store i16 %1165, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1166:                                             ; preds = %1
  %1167 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1168 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1169 = or i16 %1168, 203
  %1170 = and i16 %1169, %1167
  store i16 %1170, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1171:                                             ; preds = %1
  %1172 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1173 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1174 = or i16 %1173, 205
  %1175 = and i16 %1174, %1172
  store i16 %1175, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1176:                                             ; preds = %1
  %1177 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1178 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1179 = or i16 %1178, 205
  %1180 = and i16 %1179, %1177
  store i16 %1180, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1181:                                             ; preds = %1
  %1182 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1183 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1184 = or i16 %1183, 207
  %1185 = and i16 %1184, %1182
  store i16 %1185, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1186:                                             ; preds = %1
  %1187 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1188 = add i16 %1187, 208
  %1189 = or i16 %1188, %1187
  store i16 %1189, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1190:                                             ; preds = %1
  %1191 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1192 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1193 = add i16 %1192, 209
  %1194 = or i16 %1193, %1191
  store i16 %1194, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1195:                                             ; preds = %1
  %1196 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1197 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1198 = add i16 %1197, 210
  %1199 = or i16 %1198, %1196
  store i16 %1199, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1200:                                             ; preds = %1
  %1201 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1202 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1203 = add i16 %1202, 211
  %1204 = or i16 %1203, %1201
  store i16 %1204, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1205:                                             ; preds = %1
  %1206 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1207 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1208 = add i16 %1207, 212
  %1209 = or i16 %1208, %1206
  store i16 %1209, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1210:                                             ; preds = %1
  %1211 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1212 = add i16 %1211, 213
  %1213 = or i16 %1212, %1211
  store i16 %1213, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1214:                                             ; preds = %1
  %1215 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1216 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1217 = add i16 %1216, 214
  %1218 = or i16 %1217, %1215
  store i16 %1218, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1219:                                             ; preds = %1
  %1220 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1221 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1222 = add i16 %1221, 215
  %1223 = or i16 %1222, %1220
  store i16 %1223, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1224:                                             ; preds = %1
  %1225 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1226 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1227 = add i16 %1226, 216
  %1228 = or i16 %1227, %1225
  store i16 %1228, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1229:                                             ; preds = %1
  %1230 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1231 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1232 = add i16 %1231, 217
  %1233 = or i16 %1232, %1230
  store i16 %1233, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1234:                                             ; preds = %1
  %1235 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1236 = add i16 %1235, 218
  %1237 = or i16 %1236, %1235
  store i16 %1237, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1238:                                             ; preds = %1
  %1239 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1240 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1241 = add i16 %1240, 219
  %1242 = or i16 %1241, %1239
  store i16 %1242, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1243:                                             ; preds = %1
  %1244 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1245 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1246 = add i16 %1245, 220
  %1247 = or i16 %1246, %1244
  store i16 %1247, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1248:                                             ; preds = %1
  %1249 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1250 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1251 = add i16 %1250, 221
  %1252 = or i16 %1251, %1249
  store i16 %1252, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1253:                                             ; preds = %1
  %1254 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1255 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1256 = add i16 %1255, 222
  %1257 = or i16 %1256, %1254
  store i16 %1257, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1258:                                             ; preds = %1
  %1259 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1260 = add i16 %1259, 223
  %1261 = or i16 %1260, %1259
  store i16 %1261, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1262:                                             ; preds = %1
  %1263 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1264 = sub i16 1792, %1263
  store i16 %1264, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1265:                                             ; preds = %1
  %1266 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1267 = sub i16 1800, %1266
  store i16 %1267, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1268:                                             ; preds = %1
  %1269 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1270 = sub i16 1808, %1269
  store i16 %1270, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1271:                                             ; preds = %1
  %1272 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1273 = sub i16 1816, %1272
  store i16 %1273, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1274:                                             ; preds = %1
  %1275 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1276 = sub i16 1824, %1275
  store i16 %1276, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1277:                                             ; preds = %1
  %1278 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1279 = sub i16 1832, %1278
  store i16 %1279, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1280:                                             ; preds = %1
  %1281 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1282 = sub i16 1840, %1281
  store i16 %1282, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1283:                                             ; preds = %1
  %1284 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1285 = sub i16 1848, %1284
  store i16 %1285, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1286:                                             ; preds = %1
  %1287 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1288 = sub i16 1856, %1287
  store i16 %1288, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1289:                                             ; preds = %1
  %1290 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1291 = sub i16 1864, %1290
  store i16 %1291, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1292:                                             ; preds = %1
  %1293 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1294 = sub i16 1872, %1293
  store i16 %1294, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1295:                                             ; preds = %1
  %1296 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1297 = sub i16 1880, %1296
  store i16 %1297, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1298:                                             ; preds = %1
  %1299 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1300 = sub i16 1888, %1299
  store i16 %1300, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1301:                                             ; preds = %1
  %1302 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1303 = sub i16 1896, %1302
  store i16 %1303, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1304:                                             ; preds = %1
  %1305 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1306 = sub i16 1904, %1305
  store i16 %1306, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1307:                                             ; preds = %1
  %1308 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1309 = sub i16 1912, %1308
  store i16 %1309, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1310:                                             ; preds = %1
  %1311 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1312 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1313 = xor i16 %1312, 240
  %1314 = add i16 %1313, %1311
  store i16 %1314, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1315 = add i16 %1314, %1312
  store i16 %1315, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1316:                                             ; preds = %1
  %1317 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1318 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1319 = xor i16 %1318, 241
  %1320 = add i16 %1319, %1317
  store i16 %1320, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1321 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1322 = add i16 %1321, %1320
  store i16 %1322, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1323:                                             ; preds = %1
  %1324 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1325 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1326 = xor i16 %1325, 242
  %1327 = add i16 %1326, %1324
  store i16 %1327, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1328 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1329 = add i16 %1328, %1327
  store i16 %1329, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1330:                                             ; preds = %1
  %1331 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1332 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1333 = xor i16 %1332, 243
  %1334 = add i16 %1333, %1331
  store i16 %1334, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1335 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1336 = add i16 %1335, %1334
  store i16 %1336, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1337:                                             ; preds = %1
  %1338 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1339 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1340 = xor i16 %1339, 244
  %1341 = add i16 %1340, %1338
  store i16 %1341, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1342 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1343 = add i16 %1342, %1341
  store i16 %1343, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1344:                                             ; preds = %1
  %1345 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1346 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1347 = xor i16 %1346, 245
  %1348 = add i16 %1347, %1345
  store i16 %1348, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1349 = add i16 %1348, %1346
  store i16 %1349, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1350:                                             ; preds = %1
  %1351 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1352 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1353 = xor i16 %1352, 246
  %1354 = add i16 %1353, %1351
  store i16 %1354, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1355 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1356 = add i16 %1355, %1354
  store i16 %1356, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1357:                                             ; preds = %1
  %1358 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1359 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1360 = xor i16 %1359, 247
  %1361 = add i16 %1360, %1358
  store i16 %1361, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1362 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1363 = add i16 %1362, %1361
  store i16 %1363, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1364:                                             ; preds = %1
  %1365 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1366 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1367 = xor i16 %1366, 248
  %1368 = add i16 %1367, %1365
  store i16 %1368, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1369 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1370 = add i16 %1369, %1368
  store i16 %1370, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1371:                                             ; preds = %1
  %1372 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1373 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1374 = xor i16 %1373, 249
  %1375 = add i16 %1374, %1372
  store i16 %1375, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1376 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1377 = add i16 %1376, %1375
  store i16 %1377, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1378:                                             ; preds = %1
  %1379 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1380 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1381 = xor i16 %1380, 250
  %1382 = add i16 %1381, %1379
  store i16 %1382, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1383 = add i16 %1382, %1380
  store i16 %1383, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1384:                                             ; preds = %1
  %1385 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1386 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1387 = xor i16 %1386, 251
  %1388 = add i16 %1387, %1385
  store i16 %1388, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1389 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1390 = add i16 %1389, %1388
  store i16 %1390, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1391:                                             ; preds = %1
  %1392 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1393 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1394 = xor i16 %1393, 252
  %1395 = add i16 %1394, %1392
  store i16 %1395, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1396 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1397 = add i16 %1396, %1395
  store i16 %1397, ptr @jt_vm, align 1, !tbaa !2
  br label %1419

1398:                                             ; preds = %1
  %1399 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1400 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1401 = xor i16 %1400, 253
  %1402 = add i16 %1401, %1399
  store i16 %1402, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1403 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1404 = add i16 %1403, %1402
  store i16 %1404, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1419

1405:                                             ; preds = %1
  %1406 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1407 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1408 = xor i16 %1407, 254
  %1409 = add i16 %1408, %1406
  store i16 %1409, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1410 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1411 = add i16 %1410, %1409
  store i16 %1411, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1419

1412:                                             ; preds = %1
  %1413 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1414 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1415 = xor i16 %1414, 255
  %1416 = add i16 %1415, %1413
  store i16 %1416, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1417 = add i16 %1416, %1414
  store i16 %1417, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1419

1418:                                             ; preds = %1
  unreachable

1419:                                             ; preds = %1, %1, %1, %1, %1, %1, %1, %1, %968, %965, %964, %959, %958, %953, %952, %947, %946, %941, %939, %936, %935, %930, %929, %924, %923, %918, %917, %912, %910, %907, %906, %901, %900, %895, %894, %889, %888, %883, %881, %878, %876, %873, %872, %867, %866, %861, %860, %855, %854, %849, %847, %844, %843, %838, %837, %832, %831, %826, %825, %820, %818, %815, %814, %809, %808, %803, %802, %797, %796, %791, %789, %786, %1412, %1405, %1398, %1391, %1384, %1378, %1371, %1364, %1357, %1350, %1344, %1337, %1330, %1323, %1316, %1310, %1307, %1304, %1301, %1298, %1295, %1292, %1289, %1286, %1283, %1280, %1277, %1274, %1271, %1268, %1265, %1262, %1258, %1253, %1248, %1243, %1238, %1234, %1229, %1224, %1219, %1214, %1210, %1205, %1200, %1195, %1190, %1186, %1181, %1176, %1171, %1166, %1161, %1156, %1151, %1146, %1141, %1136, %1131, %1126, %1122, %1118, %1114, %1110, %1106, %1102, %1098, %1094, %1090, %1086, %1082, %1078, %1072, %1065, %1058, %1051, %1044, %1038, %1031, %1024, %1017, %1010, %1004, %997, %990, %983, %976, %970, %779, %771, %763, %755, %747, %740, %732, %724, %716, %708, %701, %693, %685, %677, %669, %662, %648, %634, %620, %606, %592, %578, %564, %550, %536, %522, %508, %494, %480, %466, %452, %438, %434, %429, %424, %419, %414, %410, %405, %400, %395, %390, %386, %381, %376, %371, %366, %362, %358, %353, %348, %343, %338, %334, %329, %324, %319, %314, %310, %305, %300, %295, %290, %289, %286, %281, %276, %271, %266, %263, %258, %253, %248, %243, %240, %235, %230, %225, %220, %217, %213, %208, %203, %198, %193, %189, %184, %179, %174, %169, %165, %160, %155, %150, %145, %141, %140, %135, %130, %125, %120, %119, %114, %109, %104, %99, %98, %93, %88, %83, %78, %77, %73, %68, %63, %58, %53, %49, %44, %39, %34, %29, %25, %20, %15, %10, %5, %2
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.bswap.i16(i16) #2

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i16(ptr writeonly captures(none), i8, i16, i1 immarg) #3

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #4 = { optsize }
attributes #5 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !3, i64 8}
!7 = !{!"", !4, i64 0, !3, i64 8, !4, i64 10}
!8 = !{!4, !4, i64 0}
!9 = distinct !{!9, !10}
!10 = !{!"llvm.loop.mustprogress"}
!11 = distinct !{!11, !10}
!12 = distinct !{!12, !10}
!13 = distinct !{!13, !10}
!14 = distinct !{!14, !10}
!15 = distinct !{!15, !10}
!16 = distinct !{!16, !10}
!17 = !{i64 848}
