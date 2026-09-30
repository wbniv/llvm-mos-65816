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

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  store i16 311, ptr @jt_vm, align 1, !tbaa !2
  store i16 31521, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  store i16 19977, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  store i16 -16162, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  store i16 -23131, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  br label %1

1:                                                ; preds = %4, %0
  %2 = phi i16 [ 0, %0 ], [ %9, %4 ]
  %3 = icmp eq i16 %2, 256
  br i1 %3, label %10, label %4

4:                                                ; preds = %1
  %5 = trunc nuw i16 %2 to i8
  %6 = mul i8 %5, 13
  %7 = xor i8 %6, 60
  %8 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %2
  store i8 %7, ptr %8, align 1, !tbaa !8
  %9 = add nuw nsw i16 %2, 1
  br label %1, !llvm.loop !9

10:                                               ; preds = %1, %31
  %11 = phi i8 [ %34, %31 ], [ 0, %1 ]
  %12 = icmp eq i8 %11, 32
  br i1 %12, label %13, label %31

13:                                               ; preds = %10, %25
  %14 = phi i8 [ %27, %25 ], [ 0, %10 ]
  %15 = phi i8 [ %28, %25 ], [ 95, %10 ]
  %16 = phi i16 [ %30, %25 ], [ 0, %10 ]
  %17 = icmp eq i16 %16, 512
  br i1 %17, label %35, label %18

18:                                               ; preds = %13
  %19 = and i16 %16, 1
  %20 = icmp eq i16 %19, 0
  br i1 %20, label %21, label %23

21:                                               ; preds = %18
  %22 = add i8 %14, 1
  br label %25

23:                                               ; preds = %18
  %24 = add i8 %15, 7
  br label %25

25:                                               ; preds = %23, %21
  %26 = phi i8 [ %14, %21 ], [ %15, %23 ]
  %27 = phi i8 [ %22, %21 ], [ %14, %23 ]
  %28 = phi i8 [ %15, %21 ], [ %24, %23 ]
  %29 = getelementptr inbounds nuw i8, ptr @jt_prog, i16 %16
  store i8 %26, ptr %29, align 1, !tbaa !8
  %30 = add nuw nsw i16 %16, 1
  br label %13, !llvm.loop !11

31:                                               ; preds = %10
  %32 = zext nneg i8 %11 to i16
  %33 = getelementptr i8, ptr @jt_seen, i16 %32
  store i8 0, ptr %33, align 1, !tbaa !8
  %34 = add nuw nsw i8 %11, 1
  br label %10, !llvm.loop !12

35:                                               ; preds = %13, %60
  %36 = phi i16 [ %61, %60 ], [ 0, %13 ]
  %37 = phi i16 [ %62, %60 ], [ 0, %13 ]
  %38 = icmp eq i16 %37, 512
  br i1 %38, label %63, label %39

39:                                               ; preds = %35
  %40 = getelementptr inbounds nuw i8, ptr @jt_prog, i16 %37
  %41 = load i8, ptr %40, align 1, !tbaa !8
  tail call fastcc void @jt_exec(i8 noundef zeroext %41) #4
  %42 = lshr i8 %41, 3
  %43 = zext nneg i8 %42 to i16
  %44 = getelementptr inbounds nuw i8, ptr @jt_seen, i16 %43
  %45 = load i8, ptr %44, align 1, !tbaa !8
  %46 = and i8 %41, 7
  %47 = shl nuw i8 1, %46
  %48 = or i8 %45, %47
  store i8 %48, ptr %44, align 1, !tbaa !8
  %49 = icmp ult i16 %36, 512
  br i1 %49, label %50, label %60

50:                                               ; preds = %39
  %51 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %52 = lshr i16 %51, 9
  %53 = trunc nuw nsw i16 %52 to i8
  %54 = getelementptr inbounds nuw i8, ptr @jt_tx, i16 %36
  store i8 %53, ptr %54, align 1, !tbaa !8
  %55 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %56 = lshr i16 %55, 9
  %57 = trunc nuw nsw i16 %56 to i8
  %58 = getelementptr inbounds nuw i8, ptr @jt_ty, i16 %36
  store i8 %57, ptr %58, align 1, !tbaa !8
  %59 = add nuw nsw i16 %36, 1
  br label %60

60:                                               ; preds = %50, %39
  %61 = phi i16 [ %59, %50 ], [ %36, %39 ]
  %62 = add nuw nsw i16 %37, 1
  br label %35, !llvm.loop !13

63:                                               ; preds = %35, %72
  %64 = phi i8 [ %81, %72 ], [ 0, %35 ]
  %65 = phi i16 [ %79, %72 ], [ 4660, %35 ]
  %66 = phi i8 [ %80, %72 ], [ 0, %35 ]
  %67 = icmp eq i8 %66, 4
  br i1 %67, label %68, label %72

68:                                               ; preds = %63
  %69 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %70 = xor i16 %69, %65
  %71 = tail call i16 @llvm.fshl.i16(i16 %70, i16 %70, i16 1)
  br label %82

72:                                               ; preds = %63
  %73 = zext nneg i8 %64 to i16
  %74 = getelementptr i8, ptr @jt_vm, i16 %73
  %75 = load i16, ptr %74, align 1, !tbaa !2
  %76 = xor i16 %75, %65
  %77 = tail call i16 @llvm.fshl.i16(i16 %76, i16 %76, i16 1)
  %78 = mul i16 %77, 25173
  %79 = add i16 %78, 13849
  %80 = add nuw nsw i8 %66, 1
  %81 = add nuw nsw i8 %64, 2
  br label %63, !llvm.loop !14

82:                                               ; preds = %88, %68
  %83 = phi i16 [ %71, %68 ], [ %93, %88 ]
  %84 = phi i16 [ 0, %68 ], [ %94, %88 ]
  %85 = mul i16 %83, 25173
  %86 = add i16 %85, 13849
  %87 = icmp eq i16 %84, 256
  br i1 %87, label %95, label %88

88:                                               ; preds = %82
  %89 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %84
  %90 = load i8, ptr %89, align 1, !tbaa !8
  %91 = zext i8 %90 to i16
  %92 = xor i16 %86, %91
  %93 = tail call i16 @llvm.fshl.i16(i16 %92, i16 %92, i16 1)
  %94 = add nuw nsw i16 %84, 1
  br label %82, !llvm.loop !15

95:                                               ; preds = %82, %99
  %96 = phi i16 [ %107, %99 ], [ %86, %82 ]
  %97 = phi i8 [ %108, %99 ], [ 0, %82 ]
  %98 = icmp eq i8 %97, 32
  br i1 %98, label %109, label %99

99:                                               ; preds = %95
  %100 = zext nneg i8 %97 to i16
  %101 = getelementptr i8, ptr @jt_seen, i16 %100
  %102 = load i8, ptr %101, align 1, !tbaa !8
  %103 = zext i8 %102 to i16
  %104 = xor i16 %96, %103
  %105 = tail call i16 @llvm.fshl.i16(i16 %104, i16 %104, i16 1)
  %106 = mul i16 %105, 25173
  %107 = add i16 %106, 13849
  %108 = add nuw nsw i8 %97, 1
  br label %95, !llvm.loop !16

109:                                              ; preds = %95, %113
  %110 = phi i16 [ %125, %113 ], [ %96, %95 ]
  %111 = phi i16 [ %126, %113 ], [ 0, %95 ]
  %112 = icmp eq i16 %111, %36
  br i1 %112, label %127, label %113

113:                                              ; preds = %109
  %114 = getelementptr inbounds nuw i8, ptr @jt_tx, i16 %111
  %115 = load i8, ptr %114, align 1, !tbaa !8
  %116 = zext i8 %115 to i16
  %117 = getelementptr inbounds nuw i8, ptr @jt_ty, i16 %111
  %118 = load i8, ptr %117, align 1, !tbaa !8
  %119 = zext i8 %118 to i16
  %120 = shl nuw i16 %119, 8
  %121 = or disjoint i16 %120, %116
  %122 = xor i16 %121, %110
  %123 = tail call i16 @llvm.fshl.i16(i16 %122, i16 %122, i16 1)
  %124 = mul i16 %123, 25173
  %125 = add i16 %124, 13849
  %126 = add i16 %111, 1
  br label %109, !llvm.loop !17

127:                                              ; preds = %109
  store volatile i16 %110, ptr @corpus_result, align 1, !tbaa !2
  br label %128

128:                                              ; preds = %128, %127
  tail call void asm sideeffect "wai", ""() #5, !srcloc !18
  br label %128
}

; Function Attrs: minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @jt_exec(i8 noundef zeroext %0) unnamed_addr #1 {
  switch i8 %0, label %1210 [
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
    i8 97, label %439
    i8 98, label %440
    i8 99, label %441
    i8 100, label %442
    i8 101, label %443
    i8 102, label %444
    i8 103, label %445
    i8 104, label %446
    i8 105, label %447
    i8 106, label %448
    i8 107, label %449
    i8 108, label %450
    i8 109, label %451
    i8 110, label %452
    i8 111, label %453
    i8 112, label %454
    i8 113, label %461
    i8 114, label %469
    i8 115, label %477
    i8 116, label %485
    i8 117, label %493
    i8 118, label %500
    i8 119, label %508
    i8 120, label %516
    i8 121, label %524
    i8 122, label %532
    i8 123, label %539
    i8 124, label %547
    i8 125, label %555
    i8 126, label %563
    i8 127, label %571
    i8 -128, label %578
    i8 -127, label %583
    i8 -126, label %589
    i8 -125, label %595
    i8 -124, label %601
    i8 -123, label %607
    i8 -122, label %612
    i8 -121, label %618
    i8 -120, label %624
    i8 -119, label %630
    i8 -118, label %636
    i8 -117, label %641
    i8 -116, label %647
    i8 -115, label %653
    i8 -114, label %659
    i8 -113, label %665
    i8 -112, label %670
    i8 -111, label %675
    i8 -110, label %681
    i8 -109, label %687
    i8 -108, label %693
    i8 -107, label %699
    i8 -106, label %704
    i8 -105, label %710
    i8 -104, label %716
    i8 -103, label %722
    i8 -102, label %728
    i8 -101, label %733
    i8 -100, label %739
    i8 -99, label %745
    i8 -98, label %751
    i8 -97, label %757
    i8 -96, label %762
    i8 -95, label %768
    i8 -94, label %775
    i8 -93, label %782
    i8 -92, label %789
    i8 -91, label %796
    i8 -90, label %802
    i8 -89, label %809
    i8 -88, label %816
    i8 -87, label %823
    i8 -86, label %830
    i8 -85, label %836
    i8 -84, label %843
    i8 -83, label %850
    i8 -82, label %857
    i8 -81, label %864
    i8 -80, label %1211
    i8 -79, label %870
    i8 -78, label %874
    i8 -77, label %878
    i8 -76, label %882
    i8 -75, label %1211
    i8 -74, label %886
    i8 -73, label %890
    i8 -72, label %894
    i8 -71, label %898
    i8 -70, label %1211
    i8 -69, label %902
    i8 -68, label %906
    i8 -67, label %910
    i8 -66, label %914
    i8 -65, label %1211
    i8 -64, label %1211
    i8 -63, label %918
    i8 -62, label %923
    i8 -61, label %928
    i8 -60, label %933
    i8 -59, label %1211
    i8 -58, label %938
    i8 -57, label %943
    i8 -56, label %948
    i8 -55, label %953
    i8 -54, label %1211
    i8 -53, label %958
    i8 -52, label %963
    i8 -51, label %968
    i8 -50, label %973
    i8 -49, label %1211
    i8 -48, label %978
    i8 -47, label %982
    i8 -46, label %987
    i8 -45, label %992
    i8 -44, label %997
    i8 -43, label %1002
    i8 -42, label %1006
    i8 -41, label %1011
    i8 -40, label %1016
    i8 -39, label %1021
    i8 -38, label %1026
    i8 -37, label %1030
    i8 -36, label %1035
    i8 -35, label %1040
    i8 -34, label %1045
    i8 -33, label %1050
    i8 -32, label %1054
    i8 -31, label %1057
    i8 -30, label %1060
    i8 -29, label %1063
    i8 -28, label %1066
    i8 -27, label %1069
    i8 -26, label %1072
    i8 -25, label %1075
    i8 -24, label %1078
    i8 -23, label %1081
    i8 -22, label %1084
    i8 -21, label %1087
    i8 -20, label %1090
    i8 -19, label %1093
    i8 -18, label %1096
    i8 -17, label %1099
    i8 -16, label %1102
    i8 -15, label %1108
    i8 -14, label %1115
    i8 -13, label %1122
    i8 -12, label %1129
    i8 -11, label %1136
    i8 -10, label %1142
    i8 -9, label %1149
    i8 -8, label %1156
    i8 -7, label %1163
    i8 -6, label %1170
    i8 -5, label %1176
    i8 -4, label %1183
    i8 -3, label %1190
    i8 -2, label %1197
    i8 -1, label %1204
  ]

2:                                                ; preds = %1
  %3 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %4 = shl i16 %3, 1
  store i16 %4, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

5:                                                ; preds = %1
  %6 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %7 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %8 = add i16 %6, 1
  %9 = add i16 %8, %7
  store i16 %9, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

10:                                               ; preds = %1
  %11 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %12 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %13 = add i16 %11, 2
  %14 = add i16 %13, %12
  store i16 %14, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

15:                                               ; preds = %1
  %16 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %17 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %18 = add i16 %16, 3
  %19 = add i16 %18, %17
  store i16 %19, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

20:                                               ; preds = %1
  %21 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %22 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %23 = add i16 %21, 4
  %24 = add i16 %23, %22
  store i16 %24, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

25:                                               ; preds = %1
  %26 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %27 = shl i16 %26, 1
  %28 = add i16 %27, 5
  store i16 %28, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

29:                                               ; preds = %1
  %30 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %31 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %32 = add i16 %30, 6
  %33 = add i16 %32, %31
  store i16 %33, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

34:                                               ; preds = %1
  %35 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %36 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %37 = add i16 %35, 7
  %38 = add i16 %37, %36
  store i16 %38, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

39:                                               ; preds = %1
  %40 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %41 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %42 = add i16 %40, 8
  %43 = add i16 %42, %41
  store i16 %43, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

44:                                               ; preds = %1
  %45 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %46 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %47 = add i16 %45, 9
  %48 = add i16 %47, %46
  store i16 %48, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

49:                                               ; preds = %1
  %50 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %51 = shl i16 %50, 1
  %52 = add i16 %51, 10
  store i16 %52, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

53:                                               ; preds = %1
  %54 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %55 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %56 = add i16 %54, 11
  %57 = add i16 %56, %55
  store i16 %57, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

58:                                               ; preds = %1
  %59 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %60 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %61 = add i16 %59, 12
  %62 = add i16 %61, %60
  store i16 %62, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

63:                                               ; preds = %1
  %64 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %65 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %66 = add i16 %64, 13
  %67 = add i16 %66, %65
  store i16 %67, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

68:                                               ; preds = %1
  %69 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %70 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %71 = add i16 %69, 14
  %72 = add i16 %71, %70
  store i16 %72, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

73:                                               ; preds = %1
  %74 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %75 = shl i16 %74, 1
  %76 = add i16 %75, 15
  store i16 %76, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

77:                                               ; preds = %1
  store i16 -16, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

78:                                               ; preds = %1
  %79 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %80 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %81 = add i16 %79, -17
  %82 = sub i16 %81, %80
  store i16 %82, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

83:                                               ; preds = %1
  %84 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %85 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %86 = add i16 %84, -18
  %87 = sub i16 %86, %85
  store i16 %87, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

88:                                               ; preds = %1
  %89 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %90 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %91 = add i16 %89, -19
  %92 = sub i16 %91, %90
  store i16 %92, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

93:                                               ; preds = %1
  %94 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %95 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %96 = add i16 %94, -20
  %97 = sub i16 %96, %95
  store i16 %97, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

98:                                               ; preds = %1
  store i16 -21, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

99:                                               ; preds = %1
  %100 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %101 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %102 = add i16 %100, -22
  %103 = sub i16 %102, %101
  store i16 %103, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

104:                                              ; preds = %1
  %105 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %106 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %107 = add i16 %105, -23
  %108 = sub i16 %107, %106
  store i16 %108, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

109:                                              ; preds = %1
  %110 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %111 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %112 = add i16 %110, -24
  %113 = sub i16 %112, %111
  store i16 %113, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

114:                                              ; preds = %1
  %115 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %116 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %117 = add i16 %115, -25
  %118 = sub i16 %117, %116
  store i16 %118, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

119:                                              ; preds = %1
  store i16 -26, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

120:                                              ; preds = %1
  %121 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %122 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %123 = add i16 %121, -27
  %124 = sub i16 %123, %122
  store i16 %124, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

125:                                              ; preds = %1
  %126 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %127 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %128 = add i16 %126, -28
  %129 = sub i16 %128, %127
  store i16 %129, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

130:                                              ; preds = %1
  %131 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %132 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %133 = add i16 %131, -29
  %134 = sub i16 %133, %132
  store i16 %134, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

135:                                              ; preds = %1
  %136 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %137 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %138 = add i16 %136, -30
  %139 = sub i16 %138, %137
  store i16 %139, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

140:                                              ; preds = %1
  store i16 -31, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

141:                                              ; preds = %1
  %142 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %143 = add i16 %142, 32
  %144 = xor i16 %143, %142
  store i16 %144, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

145:                                              ; preds = %1
  %146 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %147 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %148 = add i16 %147, 33
  %149 = xor i16 %148, %146
  store i16 %149, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

150:                                              ; preds = %1
  %151 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %152 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %153 = add i16 %152, 34
  %154 = xor i16 %153, %151
  store i16 %154, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

155:                                              ; preds = %1
  %156 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %157 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %158 = add i16 %157, 35
  %159 = xor i16 %158, %156
  store i16 %159, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

160:                                              ; preds = %1
  %161 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %162 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %163 = add i16 %162, 36
  %164 = xor i16 %163, %161
  store i16 %164, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

165:                                              ; preds = %1
  %166 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %167 = add i16 %166, 37
  %168 = xor i16 %167, %166
  store i16 %168, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

169:                                              ; preds = %1
  %170 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %171 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %172 = add i16 %171, 38
  %173 = xor i16 %172, %170
  store i16 %173, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

174:                                              ; preds = %1
  %175 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %176 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %177 = add i16 %176, 39
  %178 = xor i16 %177, %175
  store i16 %178, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

179:                                              ; preds = %1
  %180 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %181 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %182 = add i16 %181, 40
  %183 = xor i16 %182, %180
  store i16 %183, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

184:                                              ; preds = %1
  %185 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %186 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %187 = add i16 %186, 41
  %188 = xor i16 %187, %185
  store i16 %188, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

189:                                              ; preds = %1
  %190 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %191 = add i16 %190, 42
  %192 = xor i16 %191, %190
  store i16 %192, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

193:                                              ; preds = %1
  %194 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %195 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %196 = add i16 %195, 43
  %197 = xor i16 %196, %194
  store i16 %197, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

198:                                              ; preds = %1
  %199 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %200 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %201 = add i16 %200, 44
  %202 = xor i16 %201, %199
  store i16 %202, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

203:                                              ; preds = %1
  %204 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %205 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %206 = add i16 %205, 45
  %207 = xor i16 %206, %204
  store i16 %207, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

208:                                              ; preds = %1
  %209 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %210 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %211 = add i16 %210, 46
  %212 = xor i16 %211, %209
  store i16 %212, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

213:                                              ; preds = %1
  %214 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %215 = add i16 %214, 47
  %216 = xor i16 %215, %214
  store i16 %216, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

217:                                              ; preds = %1
  %218 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %219 = mul i16 %218, 98
  store i16 %219, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

220:                                              ; preds = %1
  %221 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %222 = mul i16 %221, 99
  %223 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %224 = add i16 %222, %223
  store i16 %224, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

225:                                              ; preds = %1
  %226 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %227 = mul i16 %226, 101
  %228 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %229 = add i16 %227, %228
  store i16 %229, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

230:                                              ; preds = %1
  %231 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %232 = mul i16 %231, 103
  %233 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %234 = add i16 %232, %233
  store i16 %234, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

235:                                              ; preds = %1
  %236 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %237 = mul i16 %236, 105
  %238 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %239 = add i16 %237, %238
  store i16 %239, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

240:                                              ; preds = %1
  %241 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %242 = mul i16 %241, 108
  store i16 %242, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

243:                                              ; preds = %1
  %244 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %245 = mul i16 %244, 109
  %246 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %247 = add i16 %245, %246
  store i16 %247, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

248:                                              ; preds = %1
  %249 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %250 = mul i16 %249, 111
  %251 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %252 = add i16 %250, %251
  store i16 %252, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

253:                                              ; preds = %1
  %254 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %255 = mul i16 %254, 113
  %256 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %257 = add i16 %255, %256
  store i16 %257, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

258:                                              ; preds = %1
  %259 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %260 = mul i16 %259, 115
  %261 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %262 = add i16 %260, %261
  store i16 %262, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

263:                                              ; preds = %1
  %264 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %265 = mul i16 %264, 118
  store i16 %265, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

266:                                              ; preds = %1
  %267 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %268 = mul i16 %267, 119
  %269 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %270 = add i16 %268, %269
  store i16 %270, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

271:                                              ; preds = %1
  %272 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %273 = mul i16 %272, 121
  %274 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %275 = add i16 %273, %274
  store i16 %275, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

276:                                              ; preds = %1
  %277 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %278 = mul i16 %277, 123
  %279 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %280 = add i16 %278, %279
  store i16 %280, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

281:                                              ; preds = %1
  %282 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %283 = mul i16 %282, 125
  %284 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %285 = add i16 %283, %284
  store i16 %285, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

286:                                              ; preds = %1
  %287 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %288 = shl i16 %287, 7
  store i16 %288, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

289:                                              ; preds = %1
  store i16 0, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

290:                                              ; preds = %1
  %291 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %292 = tail call i16 @llvm.fshl.i16(i16 %291, i16 %291, i16 1)
  %293 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %294 = xor i16 %293, %292
  store i16 %294, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

295:                                              ; preds = %1
  %296 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %297 = tail call i16 @llvm.fshl.i16(i16 %296, i16 %296, i16 2)
  %298 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %299 = xor i16 %298, %297
  store i16 %299, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

300:                                              ; preds = %1
  %301 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %302 = tail call i16 @llvm.fshl.i16(i16 %301, i16 %301, i16 3)
  %303 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %304 = xor i16 %303, %302
  store i16 %304, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

305:                                              ; preds = %1
  %306 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %307 = tail call i16 @llvm.fshl.i16(i16 %306, i16 %306, i16 4)
  %308 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %309 = xor i16 %308, %307
  store i16 %309, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

310:                                              ; preds = %1
  %311 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %312 = tail call i16 @llvm.fshl.i16(i16 %311, i16 %311, i16 5)
  %313 = xor i16 %312, %311
  store i16 %313, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

314:                                              ; preds = %1
  %315 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %316 = tail call i16 @llvm.fshl.i16(i16 %315, i16 %315, i16 6)
  %317 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %318 = xor i16 %317, %316
  store i16 %318, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

319:                                              ; preds = %1
  %320 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %321 = tail call i16 @llvm.fshl.i16(i16 %320, i16 %320, i16 7)
  %322 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %323 = xor i16 %322, %321
  store i16 %323, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

324:                                              ; preds = %1
  %325 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %326 = tail call i16 @llvm.bswap.i16(i16 %325)
  %327 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %328 = xor i16 %327, %326
  store i16 %328, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

329:                                              ; preds = %1
  %330 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %331 = tail call i16 @llvm.fshl.i16(i16 %330, i16 %330, i16 9)
  %332 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %333 = xor i16 %332, %331
  store i16 %333, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

334:                                              ; preds = %1
  %335 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %336 = tail call i16 @llvm.fshl.i16(i16 %335, i16 %335, i16 10)
  %337 = xor i16 %336, %335
  store i16 %337, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

338:                                              ; preds = %1
  %339 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %340 = tail call i16 @llvm.fshl.i16(i16 %339, i16 %339, i16 11)
  %341 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %342 = xor i16 %341, %340
  store i16 %342, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

343:                                              ; preds = %1
  %344 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %345 = tail call i16 @llvm.fshl.i16(i16 %344, i16 %344, i16 12)
  %346 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %347 = xor i16 %346, %345
  store i16 %347, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

348:                                              ; preds = %1
  %349 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %350 = tail call i16 @llvm.fshl.i16(i16 %349, i16 %349, i16 13)
  %351 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %352 = xor i16 %351, %350
  store i16 %352, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

353:                                              ; preds = %1
  %354 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %355 = tail call i16 @llvm.fshl.i16(i16 %354, i16 %354, i16 14)
  %356 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %357 = xor i16 %356, %355
  store i16 %357, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

358:                                              ; preds = %1
  %359 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %360 = tail call i16 @llvm.fshl.i16(i16 %359, i16 %359, i16 15)
  %361 = xor i16 %360, %359
  store i16 %361, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

362:                                              ; preds = %1
  %363 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %364 = lshr i16 %363, 1
  %365 = add i16 %364, %363
  store i16 %365, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

366:                                              ; preds = %1
  %367 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %368 = lshr i16 %367, 2
  %369 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %370 = add i16 %368, %369
  store i16 %370, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

371:                                              ; preds = %1
  %372 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %373 = lshr i16 %372, 3
  %374 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %375 = add i16 %373, %374
  store i16 %375, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

376:                                              ; preds = %1
  %377 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %378 = lshr i16 %377, 4
  %379 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %380 = add i16 %378, %379
  store i16 %380, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

381:                                              ; preds = %1
  %382 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %383 = lshr i16 %382, 5
  %384 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %385 = add i16 %383, %384
  store i16 %385, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

386:                                              ; preds = %1
  %387 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %388 = lshr i16 %387, 6
  %389 = add i16 %388, %387
  store i16 %389, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

390:                                              ; preds = %1
  %391 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %392 = lshr i16 %391, 7
  %393 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %394 = add i16 %392, %393
  store i16 %394, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

395:                                              ; preds = %1
  %396 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %397 = lshr i16 %396, 8
  %398 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %399 = add i16 %397, %398
  store i16 %399, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

400:                                              ; preds = %1
  %401 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %402 = lshr i16 %401, 1
  %403 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %404 = add i16 %402, %403
  store i16 %404, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

405:                                              ; preds = %1
  %406 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %407 = lshr i16 %406, 2
  %408 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %409 = add i16 %407, %408
  store i16 %409, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

410:                                              ; preds = %1
  %411 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %412 = lshr i16 %411, 3
  %413 = add i16 %412, %411
  store i16 %413, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

414:                                              ; preds = %1
  %415 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %416 = lshr i16 %415, 4
  %417 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %418 = add i16 %416, %417
  store i16 %418, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

419:                                              ; preds = %1
  %420 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %421 = lshr i16 %420, 5
  %422 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %423 = add i16 %421, %422
  store i16 %423, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

424:                                              ; preds = %1
  %425 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %426 = lshr i16 %425, 6
  %427 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %428 = add i16 %426, %427
  store i16 %428, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

429:                                              ; preds = %1
  %430 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %431 = lshr i16 %430, 7
  %432 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %433 = add i16 %431, %432
  store i16 %433, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

434:                                              ; preds = %1
  %435 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %436 = lshr i16 %435, 8
  %437 = add i16 %436, %435
  store i16 %437, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

438:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 0, i8 noundef zeroext 0, i16 noundef 96) #4
  br label %1211

439:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 1, i8 noundef zeroext 0, i16 noundef 97) #4
  br label %1211

440:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 2, i8 noundef zeroext 0, i16 noundef 98) #4
  br label %1211

441:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 3, i8 noundef zeroext 0, i16 noundef 99) #4
  br label %1211

442:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 0, i8 noundef zeroext 1, i16 noundef 100) #4
  br label %1211

443:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 1, i8 noundef zeroext 1, i16 noundef 101) #4
  br label %1211

444:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 2, i8 noundef zeroext 1, i16 noundef 102) #4
  br label %1211

445:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 3, i8 noundef zeroext 1, i16 noundef 103) #4
  br label %1211

446:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 0, i8 noundef zeroext 2, i16 noundef 104) #4
  br label %1211

447:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 1, i8 noundef zeroext 2, i16 noundef 105) #4
  br label %1211

448:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 2, i8 noundef zeroext 2, i16 noundef 106) #4
  br label %1211

449:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 3, i8 noundef zeroext 2, i16 noundef 107) #4
  br label %1211

450:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 0, i8 noundef zeroext 3, i16 noundef 108) #4
  br label %1211

451:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 1, i8 noundef zeroext 3, i16 noundef 109) #4
  br label %1211

452:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 2, i8 noundef zeroext 3, i16 noundef 110) #4
  br label %1211

453:                                              ; preds = %1
  tail call fastcc void @jt_f6(i8 noundef zeroext 3, i8 noundef zeroext 3, i16 noundef 111) #4
  br label %1211

454:                                              ; preds = %1
  %455 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %456 = add i16 %455, 112
  %457 = trunc i16 %455 to i8
  %458 = xor i8 %457, 112
  %459 = and i16 %456, 255
  %460 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %459
  store i8 %458, ptr %460, align 1, !tbaa !8
  br label %1211

461:                                              ; preds = %1
  %462 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %463 = add i16 %462, 113
  %464 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %465 = trunc i16 %464 to i8
  %466 = xor i8 %465, 113
  %467 = and i16 %463, 255
  %468 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %467
  store i8 %466, ptr %468, align 1, !tbaa !8
  br label %1211

469:                                              ; preds = %1
  %470 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %471 = add i16 %470, 114
  %472 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %473 = trunc i16 %472 to i8
  %474 = xor i8 %473, 114
  %475 = and i16 %471, 255
  %476 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %475
  store i8 %474, ptr %476, align 1, !tbaa !8
  br label %1211

477:                                              ; preds = %1
  %478 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %479 = add i16 %478, 115
  %480 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %481 = trunc i16 %480 to i8
  %482 = xor i8 %481, 115
  %483 = and i16 %479, 255
  %484 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %483
  store i8 %482, ptr %484, align 1, !tbaa !8
  br label %1211

485:                                              ; preds = %1
  %486 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %487 = add i16 %486, 116
  %488 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %489 = trunc i16 %488 to i8
  %490 = xor i8 %489, 116
  %491 = and i16 %487, 255
  %492 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %491
  store i8 %490, ptr %492, align 1, !tbaa !8
  br label %1211

493:                                              ; preds = %1
  %494 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %495 = add i16 %494, 117
  %496 = trunc i16 %494 to i8
  %497 = xor i8 %496, 117
  %498 = and i16 %495, 255
  %499 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %498
  store i8 %497, ptr %499, align 1, !tbaa !8
  br label %1211

500:                                              ; preds = %1
  %501 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %502 = add i16 %501, 118
  %503 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %504 = trunc i16 %503 to i8
  %505 = xor i8 %504, 118
  %506 = and i16 %502, 255
  %507 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %506
  store i8 %505, ptr %507, align 1, !tbaa !8
  br label %1211

508:                                              ; preds = %1
  %509 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %510 = add i16 %509, 119
  %511 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %512 = trunc i16 %511 to i8
  %513 = xor i8 %512, 119
  %514 = and i16 %510, 255
  %515 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %514
  store i8 %513, ptr %515, align 1, !tbaa !8
  br label %1211

516:                                              ; preds = %1
  %517 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %518 = add i16 %517, 120
  %519 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %520 = trunc i16 %519 to i8
  %521 = xor i8 %520, 120
  %522 = and i16 %518, 255
  %523 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %522
  store i8 %521, ptr %523, align 1, !tbaa !8
  br label %1211

524:                                              ; preds = %1
  %525 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %526 = add i16 %525, 121
  %527 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %528 = trunc i16 %527 to i8
  %529 = xor i8 %528, 121
  %530 = and i16 %526, 255
  %531 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %530
  store i8 %529, ptr %531, align 1, !tbaa !8
  br label %1211

532:                                              ; preds = %1
  %533 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %534 = add i16 %533, 122
  %535 = trunc i16 %533 to i8
  %536 = xor i8 %535, 122
  %537 = and i16 %534, 255
  %538 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %537
  store i8 %536, ptr %538, align 1, !tbaa !8
  br label %1211

539:                                              ; preds = %1
  %540 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %541 = add i16 %540, 123
  %542 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %543 = trunc i16 %542 to i8
  %544 = xor i8 %543, 123
  %545 = and i16 %541, 255
  %546 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %545
  store i8 %544, ptr %546, align 1, !tbaa !8
  br label %1211

547:                                              ; preds = %1
  %548 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %549 = add i16 %548, 124
  %550 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %551 = trunc i16 %550 to i8
  %552 = xor i8 %551, 124
  %553 = and i16 %549, 255
  %554 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %553
  store i8 %552, ptr %554, align 1, !tbaa !8
  br label %1211

555:                                              ; preds = %1
  %556 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %557 = add i16 %556, 125
  %558 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %559 = trunc i16 %558 to i8
  %560 = xor i8 %559, 125
  %561 = and i16 %557, 255
  %562 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %561
  store i8 %560, ptr %562, align 1, !tbaa !8
  br label %1211

563:                                              ; preds = %1
  %564 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %565 = add i16 %564, 126
  %566 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %567 = trunc i16 %566 to i8
  %568 = xor i8 %567, 126
  %569 = and i16 %565, 255
  %570 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %569
  store i8 %568, ptr %570, align 1, !tbaa !8
  br label %1211

571:                                              ; preds = %1
  %572 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %573 = add i16 %572, 127
  %574 = trunc i16 %572 to i8
  %575 = xor i8 %574, 127
  %576 = and i16 %573, 255
  %577 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %576
  store i8 %575, ptr %577, align 1, !tbaa !8
  br label %1211

578:                                              ; preds = %1
  %579 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %580 = icmp ugt i16 %579, -129
  br i1 %580, label %581, label %1211

581:                                              ; preds = %578
  %582 = add nsw i16 %579, 128
  store i16 %582, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

583:                                              ; preds = %1
  %584 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %585 = add i16 %584, 129
  %586 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %587 = icmp ult i16 %585, %586
  br i1 %587, label %588, label %1211

588:                                              ; preds = %583
  store i16 %585, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

589:                                              ; preds = %1
  %590 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %591 = add i16 %590, 130
  %592 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %593 = icmp ult i16 %591, %592
  br i1 %593, label %594, label %1211

594:                                              ; preds = %589
  store i16 %591, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

595:                                              ; preds = %1
  %596 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %597 = add i16 %596, 131
  %598 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %599 = icmp ult i16 %597, %598
  br i1 %599, label %600, label %1211

600:                                              ; preds = %595
  store i16 %597, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

601:                                              ; preds = %1
  %602 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %603 = add i16 %602, 132
  %604 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %605 = icmp ult i16 %603, %604
  br i1 %605, label %606, label %1211

606:                                              ; preds = %601
  store i16 %603, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

607:                                              ; preds = %1
  %608 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %609 = icmp ugt i16 %608, -134
  br i1 %609, label %610, label %1211

610:                                              ; preds = %607
  %611 = add nsw i16 %608, 133
  store i16 %611, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

612:                                              ; preds = %1
  %613 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %614 = add i16 %613, 134
  %615 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %616 = icmp ult i16 %614, %615
  br i1 %616, label %617, label %1211

617:                                              ; preds = %612
  store i16 %614, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

618:                                              ; preds = %1
  %619 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %620 = add i16 %619, 135
  %621 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %622 = icmp ult i16 %620, %621
  br i1 %622, label %623, label %1211

623:                                              ; preds = %618
  store i16 %620, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

624:                                              ; preds = %1
  %625 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %626 = add i16 %625, 136
  %627 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %628 = icmp ult i16 %626, %627
  br i1 %628, label %629, label %1211

629:                                              ; preds = %624
  store i16 %626, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

630:                                              ; preds = %1
  %631 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %632 = add i16 %631, 137
  %633 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %634 = icmp ult i16 %632, %633
  br i1 %634, label %635, label %1211

635:                                              ; preds = %630
  store i16 %632, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

636:                                              ; preds = %1
  %637 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %638 = icmp ugt i16 %637, -139
  br i1 %638, label %639, label %1211

639:                                              ; preds = %636
  %640 = add nsw i16 %637, 138
  store i16 %640, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

641:                                              ; preds = %1
  %642 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %643 = add i16 %642, 139
  %644 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %645 = icmp ult i16 %643, %644
  br i1 %645, label %646, label %1211

646:                                              ; preds = %641
  store i16 %643, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

647:                                              ; preds = %1
  %648 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %649 = add i16 %648, 140
  %650 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %651 = icmp ult i16 %649, %650
  br i1 %651, label %652, label %1211

652:                                              ; preds = %647
  store i16 %649, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

653:                                              ; preds = %1
  %654 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %655 = add i16 %654, 141
  %656 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %657 = icmp ult i16 %655, %656
  br i1 %657, label %658, label %1211

658:                                              ; preds = %653
  store i16 %655, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

659:                                              ; preds = %1
  %660 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %661 = add i16 %660, 142
  %662 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %663 = icmp ult i16 %661, %662
  br i1 %663, label %664, label %1211

664:                                              ; preds = %659
  store i16 %661, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

665:                                              ; preds = %1
  %666 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %667 = icmp ugt i16 %666, -144
  br i1 %667, label %668, label %1211

668:                                              ; preds = %665
  %669 = add nsw i16 %666, 143
  store i16 %669, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

670:                                              ; preds = %1
  %671 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %672 = icmp ult i16 %671, -144
  br i1 %672, label %673, label %1211

673:                                              ; preds = %670
  %674 = add nuw i16 %671, 144
  store i16 %674, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

675:                                              ; preds = %1
  %676 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %677 = add i16 %676, 145
  %678 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %679 = icmp ugt i16 %677, %678
  br i1 %679, label %680, label %1211

680:                                              ; preds = %675
  store i16 %677, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

681:                                              ; preds = %1
  %682 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %683 = add i16 %682, 146
  %684 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %685 = icmp ugt i16 %683, %684
  br i1 %685, label %686, label %1211

686:                                              ; preds = %681
  store i16 %683, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

687:                                              ; preds = %1
  %688 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %689 = add i16 %688, 147
  %690 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %691 = icmp ugt i16 %689, %690
  br i1 %691, label %692, label %1211

692:                                              ; preds = %687
  store i16 %689, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

693:                                              ; preds = %1
  %694 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %695 = add i16 %694, 148
  %696 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %697 = icmp ugt i16 %695, %696
  br i1 %697, label %698, label %1211

698:                                              ; preds = %693
  store i16 %695, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

699:                                              ; preds = %1
  %700 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %701 = icmp ult i16 %700, -149
  br i1 %701, label %702, label %1211

702:                                              ; preds = %699
  %703 = add nuw i16 %700, 149
  store i16 %703, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

704:                                              ; preds = %1
  %705 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %706 = add i16 %705, 150
  %707 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %708 = icmp ugt i16 %706, %707
  br i1 %708, label %709, label %1211

709:                                              ; preds = %704
  store i16 %706, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

710:                                              ; preds = %1
  %711 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %712 = add i16 %711, 151
  %713 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %714 = icmp ugt i16 %712, %713
  br i1 %714, label %715, label %1211

715:                                              ; preds = %710
  store i16 %712, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

716:                                              ; preds = %1
  %717 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %718 = add i16 %717, 152
  %719 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %720 = icmp ugt i16 %718, %719
  br i1 %720, label %721, label %1211

721:                                              ; preds = %716
  store i16 %718, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

722:                                              ; preds = %1
  %723 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %724 = add i16 %723, 153
  %725 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %726 = icmp ugt i16 %724, %725
  br i1 %726, label %727, label %1211

727:                                              ; preds = %722
  store i16 %724, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

728:                                              ; preds = %1
  %729 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %730 = icmp ult i16 %729, -154
  br i1 %730, label %731, label %1211

731:                                              ; preds = %728
  %732 = add nuw i16 %729, 154
  store i16 %732, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

733:                                              ; preds = %1
  %734 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %735 = add i16 %734, 155
  %736 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %737 = icmp ugt i16 %735, %736
  br i1 %737, label %738, label %1211

738:                                              ; preds = %733
  store i16 %735, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

739:                                              ; preds = %1
  %740 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %741 = add i16 %740, 156
  %742 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %743 = icmp ugt i16 %741, %742
  br i1 %743, label %744, label %1211

744:                                              ; preds = %739
  store i16 %741, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

745:                                              ; preds = %1
  %746 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %747 = add i16 %746, 157
  %748 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %749 = icmp ugt i16 %747, %748
  br i1 %749, label %750, label %1211

750:                                              ; preds = %745
  store i16 %747, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

751:                                              ; preds = %1
  %752 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %753 = add i16 %752, 158
  %754 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %755 = icmp ugt i16 %753, %754
  br i1 %755, label %756, label %1211

756:                                              ; preds = %751
  store i16 %753, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

757:                                              ; preds = %1
  %758 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %759 = icmp ult i16 %758, -159
  br i1 %759, label %760, label %1211

760:                                              ; preds = %757
  %761 = add nuw i16 %758, 159
  store i16 %761, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

762:                                              ; preds = %1
  %763 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %764 = mul i16 %763, 321
  %765 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %766 = add i16 %764, %765
  store i16 %766, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %767 = xor i16 %766, %765
  store i16 %767, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

768:                                              ; preds = %1
  %769 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %770 = mul i16 %769, 323
  %771 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %772 = add i16 %770, %771
  store i16 %772, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %773 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %774 = xor i16 %773, %772
  store i16 %774, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

775:                                              ; preds = %1
  %776 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %777 = mul i16 %776, 325
  %778 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %779 = add i16 %777, %778
  store i16 %779, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %780 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %781 = xor i16 %780, %779
  store i16 %781, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

782:                                              ; preds = %1
  %783 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %784 = mul i16 %783, 327
  %785 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %786 = add i16 %784, %785
  store i16 %786, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %787 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %788 = xor i16 %787, %786
  store i16 %788, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

789:                                              ; preds = %1
  %790 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %791 = mul i16 %790, 329
  %792 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %793 = add i16 %791, %792
  store i16 %793, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %794 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %795 = xor i16 %794, %793
  store i16 %795, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

796:                                              ; preds = %1
  %797 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %798 = mul i16 %797, 331
  %799 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %800 = add i16 %798, %799
  store i16 %800, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %801 = xor i16 %800, %799
  store i16 %801, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

802:                                              ; preds = %1
  %803 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %804 = mul i16 %803, 333
  %805 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %806 = add i16 %804, %805
  store i16 %806, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %807 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %808 = xor i16 %807, %806
  store i16 %808, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

809:                                              ; preds = %1
  %810 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %811 = mul i16 %810, 335
  %812 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %813 = add i16 %811, %812
  store i16 %813, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %814 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %815 = xor i16 %814, %813
  store i16 %815, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

816:                                              ; preds = %1
  %817 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %818 = mul i16 %817, 337
  %819 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %820 = add i16 %818, %819
  store i16 %820, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %821 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %822 = xor i16 %821, %820
  store i16 %822, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

823:                                              ; preds = %1
  %824 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %825 = mul i16 %824, 339
  %826 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %827 = add i16 %825, %826
  store i16 %827, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %828 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %829 = xor i16 %828, %827
  store i16 %829, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

830:                                              ; preds = %1
  %831 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %832 = mul i16 %831, 341
  %833 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %834 = add i16 %832, %833
  store i16 %834, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %835 = xor i16 %834, %833
  store i16 %835, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

836:                                              ; preds = %1
  %837 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %838 = mul i16 %837, 343
  %839 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %840 = add i16 %838, %839
  store i16 %840, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %841 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %842 = xor i16 %841, %840
  store i16 %842, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

843:                                              ; preds = %1
  %844 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %845 = mul i16 %844, 345
  %846 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %847 = add i16 %845, %846
  store i16 %847, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %848 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %849 = xor i16 %848, %847
  store i16 %849, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

850:                                              ; preds = %1
  %851 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %852 = mul i16 %851, 347
  %853 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %854 = add i16 %852, %853
  store i16 %854, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %855 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %856 = xor i16 %855, %854
  store i16 %856, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

857:                                              ; preds = %1
  %858 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %859 = mul i16 %858, 349
  %860 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %861 = add i16 %859, %860
  store i16 %861, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %862 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %863 = xor i16 %862, %861
  store i16 %863, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

864:                                              ; preds = %1
  %865 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %866 = mul i16 %865, 351
  %867 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %868 = add i16 %866, %867
  store i16 %868, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %869 = xor i16 %868, %867
  store i16 %869, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

870:                                              ; preds = %1
  %871 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %872 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %873 = add i16 %872, 177
  store i16 %873, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  store i16 %871, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

874:                                              ; preds = %1
  %875 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %876 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %877 = add i16 %876, 178
  store i16 %877, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  store i16 %875, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

878:                                              ; preds = %1
  %879 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %880 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %881 = add i16 %880, 179
  store i16 %881, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  store i16 %879, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

882:                                              ; preds = %1
  %883 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %884 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %885 = add i16 %884, 180
  store i16 %885, ptr @jt_vm, align 1, !tbaa !2
  store i16 %883, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

886:                                              ; preds = %1
  %887 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %888 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %889 = add i16 %888, 182
  store i16 %889, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  store i16 %887, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

890:                                              ; preds = %1
  %891 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %892 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %893 = add i16 %892, 183
  store i16 %893, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  store i16 %891, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

894:                                              ; preds = %1
  %895 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %896 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %897 = add i16 %896, 184
  store i16 %897, ptr @jt_vm, align 1, !tbaa !2
  store i16 %895, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

898:                                              ; preds = %1
  %899 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %900 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %901 = add i16 %900, 185
  store i16 %901, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  store i16 %899, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

902:                                              ; preds = %1
  %903 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %904 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %905 = add i16 %904, 187
  store i16 %905, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  store i16 %903, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

906:                                              ; preds = %1
  %907 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %908 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %909 = add i16 %908, 188
  store i16 %909, ptr @jt_vm, align 1, !tbaa !2
  store i16 %907, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

910:                                              ; preds = %1
  %911 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %912 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %913 = add i16 %912, 189
  store i16 %913, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  store i16 %911, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

914:                                              ; preds = %1
  %915 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %916 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %917 = add i16 %916, 190
  store i16 %917, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  store i16 %915, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

918:                                              ; preds = %1
  %919 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %920 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %921 = or i16 %920, 193
  %922 = and i16 %921, %919
  store i16 %922, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

923:                                              ; preds = %1
  %924 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %925 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %926 = or i16 %925, 195
  %927 = and i16 %926, %924
  store i16 %927, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

928:                                              ; preds = %1
  %929 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %930 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %931 = or i16 %930, 195
  %932 = and i16 %931, %929
  store i16 %932, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

933:                                              ; preds = %1
  %934 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %935 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %936 = or i16 %935, 197
  %937 = and i16 %936, %934
  store i16 %937, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

938:                                              ; preds = %1
  %939 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %940 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %941 = or i16 %940, 199
  %942 = and i16 %941, %939
  store i16 %942, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

943:                                              ; preds = %1
  %944 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %945 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %946 = or i16 %945, 199
  %947 = and i16 %946, %944
  store i16 %947, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

948:                                              ; preds = %1
  %949 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %950 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %951 = or i16 %950, 201
  %952 = and i16 %951, %949
  store i16 %952, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

953:                                              ; preds = %1
  %954 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %955 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %956 = or i16 %955, 201
  %957 = and i16 %956, %954
  store i16 %957, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

958:                                              ; preds = %1
  %959 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %960 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %961 = or i16 %960, 203
  %962 = and i16 %961, %959
  store i16 %962, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

963:                                              ; preds = %1
  %964 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %965 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %966 = or i16 %965, 205
  %967 = and i16 %966, %964
  store i16 %967, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

968:                                              ; preds = %1
  %969 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %970 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %971 = or i16 %970, 205
  %972 = and i16 %971, %969
  store i16 %972, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

973:                                              ; preds = %1
  %974 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %975 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %976 = or i16 %975, 207
  %977 = and i16 %976, %974
  store i16 %977, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

978:                                              ; preds = %1
  %979 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %980 = add i16 %979, 208
  %981 = or i16 %980, %979
  store i16 %981, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

982:                                              ; preds = %1
  %983 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %984 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %985 = add i16 %984, 209
  %986 = or i16 %985, %983
  store i16 %986, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

987:                                              ; preds = %1
  %988 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %989 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %990 = add i16 %989, 210
  %991 = or i16 %990, %988
  store i16 %991, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

992:                                              ; preds = %1
  %993 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %994 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %995 = add i16 %994, 211
  %996 = or i16 %995, %993
  store i16 %996, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

997:                                              ; preds = %1
  %998 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %999 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1000 = add i16 %999, 212
  %1001 = or i16 %1000, %998
  store i16 %1001, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1002:                                             ; preds = %1
  %1003 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1004 = add i16 %1003, 213
  %1005 = or i16 %1004, %1003
  store i16 %1005, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1006:                                             ; preds = %1
  %1007 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1008 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1009 = add i16 %1008, 214
  %1010 = or i16 %1009, %1007
  store i16 %1010, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1011:                                             ; preds = %1
  %1012 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1013 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1014 = add i16 %1013, 215
  %1015 = or i16 %1014, %1012
  store i16 %1015, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1016:                                             ; preds = %1
  %1017 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1018 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1019 = add i16 %1018, 216
  %1020 = or i16 %1019, %1017
  store i16 %1020, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1021:                                             ; preds = %1
  %1022 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1023 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1024 = add i16 %1023, 217
  %1025 = or i16 %1024, %1022
  store i16 %1025, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1026:                                             ; preds = %1
  %1027 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1028 = add i16 %1027, 218
  %1029 = or i16 %1028, %1027
  store i16 %1029, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1030:                                             ; preds = %1
  %1031 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1032 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1033 = add i16 %1032, 219
  %1034 = or i16 %1033, %1031
  store i16 %1034, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1035:                                             ; preds = %1
  %1036 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1037 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1038 = add i16 %1037, 220
  %1039 = or i16 %1038, %1036
  store i16 %1039, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1040:                                             ; preds = %1
  %1041 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1042 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1043 = add i16 %1042, 221
  %1044 = or i16 %1043, %1041
  store i16 %1044, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1045:                                             ; preds = %1
  %1046 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1047 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1048 = add i16 %1047, 222
  %1049 = or i16 %1048, %1046
  store i16 %1049, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1050:                                             ; preds = %1
  %1051 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1052 = add i16 %1051, 223
  %1053 = or i16 %1052, %1051
  store i16 %1053, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1054:                                             ; preds = %1
  %1055 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1056 = sub i16 1792, %1055
  store i16 %1056, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1057:                                             ; preds = %1
  %1058 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1059 = sub i16 1800, %1058
  store i16 %1059, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1060:                                             ; preds = %1
  %1061 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1062 = sub i16 1808, %1061
  store i16 %1062, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1063:                                             ; preds = %1
  %1064 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1065 = sub i16 1816, %1064
  store i16 %1065, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1066:                                             ; preds = %1
  %1067 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1068 = sub i16 1824, %1067
  store i16 %1068, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1069:                                             ; preds = %1
  %1070 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1071 = sub i16 1832, %1070
  store i16 %1071, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1072:                                             ; preds = %1
  %1073 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1074 = sub i16 1840, %1073
  store i16 %1074, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1075:                                             ; preds = %1
  %1076 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1077 = sub i16 1848, %1076
  store i16 %1077, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1078:                                             ; preds = %1
  %1079 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1080 = sub i16 1856, %1079
  store i16 %1080, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1081:                                             ; preds = %1
  %1082 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1083 = sub i16 1864, %1082
  store i16 %1083, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1084:                                             ; preds = %1
  %1085 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1086 = sub i16 1872, %1085
  store i16 %1086, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1087:                                             ; preds = %1
  %1088 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1089 = sub i16 1880, %1088
  store i16 %1089, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1090:                                             ; preds = %1
  %1091 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1092 = sub i16 1888, %1091
  store i16 %1092, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1093:                                             ; preds = %1
  %1094 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1095 = sub i16 1896, %1094
  store i16 %1095, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1096:                                             ; preds = %1
  %1097 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1098 = sub i16 1904, %1097
  store i16 %1098, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1099:                                             ; preds = %1
  %1100 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1101 = sub i16 1912, %1100
  store i16 %1101, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1102:                                             ; preds = %1
  %1103 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1104 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1105 = xor i16 %1104, 240
  %1106 = add i16 %1105, %1103
  store i16 %1106, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1107 = add i16 %1106, %1104
  store i16 %1107, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1108:                                             ; preds = %1
  %1109 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1110 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1111 = xor i16 %1110, 241
  %1112 = add i16 %1111, %1109
  store i16 %1112, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1113 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1114 = add i16 %1113, %1112
  store i16 %1114, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1115:                                             ; preds = %1
  %1116 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1117 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1118 = xor i16 %1117, 242
  %1119 = add i16 %1118, %1116
  store i16 %1119, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1120 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1121 = add i16 %1120, %1119
  store i16 %1121, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1122:                                             ; preds = %1
  %1123 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1124 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1125 = xor i16 %1124, 243
  %1126 = add i16 %1125, %1123
  store i16 %1126, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1127 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1128 = add i16 %1127, %1126
  store i16 %1128, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1129:                                             ; preds = %1
  %1130 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1131 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1132 = xor i16 %1131, 244
  %1133 = add i16 %1132, %1130
  store i16 %1133, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1134 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1135 = add i16 %1134, %1133
  store i16 %1135, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1136:                                             ; preds = %1
  %1137 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1138 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1139 = xor i16 %1138, 245
  %1140 = add i16 %1139, %1137
  store i16 %1140, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1141 = add i16 %1140, %1138
  store i16 %1141, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1142:                                             ; preds = %1
  %1143 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1144 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1145 = xor i16 %1144, 246
  %1146 = add i16 %1145, %1143
  store i16 %1146, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1147 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1148 = add i16 %1147, %1146
  store i16 %1148, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1149:                                             ; preds = %1
  %1150 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1151 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1152 = xor i16 %1151, 247
  %1153 = add i16 %1152, %1150
  store i16 %1153, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1154 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1155 = add i16 %1154, %1153
  store i16 %1155, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1156:                                             ; preds = %1
  %1157 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1158 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1159 = xor i16 %1158, 248
  %1160 = add i16 %1159, %1157
  store i16 %1160, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1161 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1162 = add i16 %1161, %1160
  store i16 %1162, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1163:                                             ; preds = %1
  %1164 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1165 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1166 = xor i16 %1165, 249
  %1167 = add i16 %1166, %1164
  store i16 %1167, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1168 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1169 = add i16 %1168, %1167
  store i16 %1169, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1170:                                             ; preds = %1
  %1171 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1172 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1173 = xor i16 %1172, 250
  %1174 = add i16 %1173, %1171
  store i16 %1174, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1175 = add i16 %1174, %1172
  store i16 %1175, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1176:                                             ; preds = %1
  %1177 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1178 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1179 = xor i16 %1178, 251
  %1180 = add i16 %1179, %1177
  store i16 %1180, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1181 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1182 = add i16 %1181, %1180
  store i16 %1182, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1183:                                             ; preds = %1
  %1184 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1185 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1186 = xor i16 %1185, 252
  %1187 = add i16 %1186, %1184
  store i16 %1187, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1188 = load i16, ptr @jt_vm, align 1, !tbaa !2
  %1189 = add i16 %1188, %1187
  store i16 %1189, ptr @jt_vm, align 1, !tbaa !2
  br label %1211

1190:                                             ; preds = %1
  %1191 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1192 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1193 = xor i16 %1192, 253
  %1194 = add i16 %1193, %1191
  store i16 %1194, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1195 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  %1196 = add i16 %1195, %1194
  store i16 %1196, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 2), align 1, !tbaa !2
  br label %1211

1197:                                             ; preds = %1
  %1198 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1199 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1200 = xor i16 %1199, 254
  %1201 = add i16 %1200, %1198
  store i16 %1201, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1202 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  %1203 = add i16 %1202, %1201
  store i16 %1203, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 4), align 1, !tbaa !2
  br label %1211

1204:                                             ; preds = %1
  %1205 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1206 = load i16, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  %1207 = xor i16 %1206, 255
  %1208 = add i16 %1207, %1205
  store i16 %1208, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 8), align 1, !tbaa !6
  %1209 = add i16 %1208, %1206
  store i16 %1209, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 6), align 1, !tbaa !2
  br label %1211

1210:                                             ; preds = %1
  unreachable

1211:                                             ; preds = %1, %1, %1, %1, %1, %1, %1, %1, %760, %757, %756, %751, %750, %745, %744, %739, %738, %733, %731, %728, %727, %722, %721, %716, %715, %710, %709, %704, %702, %699, %698, %693, %692, %687, %686, %681, %680, %675, %673, %670, %668, %665, %664, %659, %658, %653, %652, %647, %646, %641, %639, %636, %635, %630, %629, %624, %623, %618, %617, %612, %610, %607, %606, %601, %600, %595, %594, %589, %588, %583, %581, %578, %1204, %1197, %1190, %1183, %1176, %1170, %1163, %1156, %1149, %1142, %1136, %1129, %1122, %1115, %1108, %1102, %1099, %1096, %1093, %1090, %1087, %1084, %1081, %1078, %1075, %1072, %1069, %1066, %1063, %1060, %1057, %1054, %1050, %1045, %1040, %1035, %1030, %1026, %1021, %1016, %1011, %1006, %1002, %997, %992, %987, %982, %978, %973, %968, %963, %958, %953, %948, %943, %938, %933, %928, %923, %918, %914, %910, %906, %902, %898, %894, %890, %886, %882, %878, %874, %870, %864, %857, %850, %843, %836, %830, %823, %816, %809, %802, %796, %789, %782, %775, %768, %762, %571, %563, %555, %547, %539, %532, %524, %516, %508, %500, %493, %485, %477, %469, %461, %454, %453, %452, %451, %450, %449, %448, %447, %446, %445, %444, %443, %442, %441, %440, %439, %438, %434, %429, %424, %419, %414, %410, %405, %400, %395, %390, %386, %381, %376, %371, %366, %362, %358, %353, %348, %343, %338, %334, %329, %324, %319, %314, %310, %305, %300, %295, %290, %289, %286, %281, %276, %271, %266, %263, %258, %253, %248, %243, %240, %235, %230, %225, %220, %217, %213, %208, %203, %198, %193, %189, %184, %179, %174, %169, %165, %160, %155, %150, %145, %141, %140, %135, %130, %125, %120, %119, %114, %109, %104, %99, %98, %93, %88, %83, %78, %77, %73, %68, %63, %58, %53, %49, %44, %39, %34, %29, %25, %20, %15, %10, %5, %2
  ret void
}

; Function Attrs: minsize mustprogress nofree norecurse nosync nounwind optsize willreturn memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc void @jt_f6(i8 noundef zeroext range(i8 0, 4) %0, i8 noundef zeroext range(i8 0, 4) %1, i16 noundef %2) unnamed_addr #2 {
  %4 = zext nneg i8 %1 to i16
  %5 = getelementptr inbounds nuw [2 x i8], ptr @jt_vm, i16 %4
  %6 = load i16, ptr %5, align 1, !tbaa !2
  %7 = add i16 %6, %2
  %8 = and i16 %7, 255
  %9 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %8
  %10 = load i8, ptr %9, align 1, !tbaa !8
  %11 = zext i8 %10 to i16
  %12 = add i16 %7, 1
  %13 = and i16 %12, 255
  %14 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @jt_vm, i16 10), i16 %13
  %15 = load i8, ptr %14, align 1, !tbaa !8
  %16 = zext i8 %15 to i16
  %17 = shl nuw i16 %16, 8
  %18 = or disjoint i16 %17, %11
  %19 = zext nneg i8 %0 to i16
  %20 = getelementptr inbounds nuw [2 x i8], ptr @jt_vm, i16 %19
  store i16 %18, ptr %20, align 1, !tbaa !2
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #3

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.bswap.i16(i16) #3

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(readwrite, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { minsize mustprogress nofree norecurse nosync nounwind optsize willreturn memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { minsize optsize }
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
!17 = distinct !{!17, !10}
!18 = !{i64 848}
