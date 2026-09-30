define dso_local noundef i16 @main() local_unnamed_addr #0 {
  store volatile i8 -113, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !12
  br label %1

1:                                                ; preds = %4, %0
  %.010.i.i.i = phi i16 [ 8449, %0 ], [ %5, %4 ]
  switch i16 %.010.i.i.i, label %2 [
    i16 8452, label %4
    i16 8470, label %4
    i16 8471, label %4
    i16 8472, label %4
    i16 8473, label %4
    i16 8481, label %4
    i16 8482, label %4
  ]

2:                                                ; preds = %1
  %3 = inttoptr i16 %.010.i.i.i to ptr
  store volatile i8 0, ptr %3, align 1, !tbaa !12
  br label %4

4:                                                ; preds = %2, %1, %1, %1, %1, %1, %1, %1
  %5 = add nuw nsw i16 %.010.i.i.i, 1
  %exitcond.not.i.i.i = icmp eq i16 %5, 8500
  br i1 %exitcond.not.i.i.i, label %display_init.exit.i, label %1, !llvm.loop !13

display_init.exit.i:                              ; preds = %4
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(6) getelementptr inbounds nuw (i8, ptr @main.a, i16 176), i8 0, i64 6, i1 false)
  store i32 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  store volatile i8 1, ptr inttoptr (i16 8453 to ptr), align 1, !tbaa !12
  store volatile i8 0, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !12
  store volatile i8 -127, ptr inttoptr (i16 16896 to ptr), align 512, !tbaa !12
  store ptr @CANVAS_VT, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 196), align 1, !tbaa !21
  store i8 4, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 198), align 1, !tbaa !25
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4299), align 1, !tbaa !26
  store i16 16384, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4301), align 1, !tbaa !27
  store i8 8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4303), align 1, !tbaa !28
  store i8 6, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4304), align 1, !tbaa !29
  tail call void @llvm.memset.p0.i16(ptr noundef nonnull align 1 dereferenceable(4096) getelementptr inbounds nuw (i8, ptr @main.a, i16 199), i8 0, i16 4096, i1 false), !tbaa !12
  store i16 -1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4295), align 1, !tbaa !30
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4297), align 1, !tbaa !31
  store ptr @TEXT_VT, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4305), align 1, !tbaa !32
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4307), align 1, !tbaa !34
  store i16 16384, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4308), align 1, !tbaa !35
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4310), align 1, !tbaa !12
  store i8 25, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4311), align 1, !tbaa !12
  br label %6

6:                                                ; preds = %6, %display_init.exit.i
  %mos-indexiv.iv.i.i = phi i8 [ 0, %display_init.exit.i ], [ %mos-indexiv.iv.next.i.i, %6 ]
  %.012.i.i = phi i16 [ 0, %display_init.exit.i ], [ %8, %6 ]
  %7 = zext i8 %mos-indexiv.iv.i.i to i16
  %uglygep29 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4312), i16 %7
  store i16 256, ptr %uglygep29, align 1, !tbaa !1
  %8 = add nuw nsw i16 %.012.i.i, 1
  %exitcond.not.i.i = icmp eq i16 %8, 64
  %mos-indexiv.iv.next.i.i = add nuw i8 %mos-indexiv.iv.i.i, 2
  br i1 %exitcond.not.i.i, label %text_init.exit.i, label %6, !llvm.loop !36

text_init.exit.i:                                 ; preds = %6
  store i8 3, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4440), align 1, !tbaa !37
  %9 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  %.not.i.i = icmp eq i8 %9, 0
  br i1 %.not.i.i, label %11, label %10

10:                                               ; preds = %text_init.exit.i
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !39
  br label %11

11:                                               ; preds = %10, %text_init.exit.i
  %12 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %13 = icmp ult i8 %12, 4
  br i1 %13, label %14, label %display_add.exit.i

14:                                               ; preds = %11
  %15 = zext nneg i8 %12 to i16
  %16 = add nuw nsw i8 %12, 1
  store i8 %16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %17 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %15
  store ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 196), ptr %17, align 1, !tbaa !41
  br label %display_add.exit.i

display_add.exit.i:                               ; preds = %14, %11
  store volatile i8 64, ptr inttoptr (i16 8457 to ptr), align 1, !tbaa !12
  %18 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4299), align 1, !tbaa !26
  %19 = lshr i16 %18, 12
  %20 = trunc nuw nsw i16 %19 to i8
  store volatile i8 %20, ptr inttoptr (i16 8460 to ptr), align 4, !tbaa !12
  %21 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4299), align 1, !tbaa !26
  %22 = lshr i16 %21, 3
  %23 = add nuw nsw i16 %22, 256
  %24 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4301), align 1, !tbaa !27
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !12
  store volatile i16 %24, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !1
  %25 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4303), align 1, !tbaa !28
  br label %.preheader.i.i

.preheader.i.i:                                   ; preds = %33, %display_add.exit.i
  %.02431.i.i = phi i8 [ 0, %display_add.exit.i ], [ %34, %33 ]
  %26 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4304), align 1
  %27 = sub i8 %.02431.i.i, %26
  %28 = icmp ugt i8 %27, 15
  %29 = shl nuw i8 %27, 4
  %30 = zext i8 %29 to i16
  %invariant.op.i = add nuw nsw i16 %22, %30
  br label %35

31:                                               ; preds = %33
  %32 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4299), align 1, !tbaa !26
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !12
  store volatile i16 %32, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !1
  br label %43

33:                                               ; preds = %40
  %34 = add nuw nsw i8 %.02431.i.i, 1
  %exitcond33.not.i.i = icmp eq i8 %34, 32
  br i1 %exitcond33.not.i.i, label %31, label %.preheader.i.i, !llvm.loop !43

35:                                               ; preds = %40, %.preheader.i.i
  %.02530.i.i = phi i8 [ 0, %.preheader.i.i ], [ %42, %40 ]
  %36 = sub i8 %.02530.i.i, %25
  %37 = icmp ugt i8 %36, 15
  %brmerge.i = select i1 %37, i1 true, i1 %28
  br i1 %brmerge.i, label %40, label %38

38:                                               ; preds = %35
  %39 = zext nneg i8 %36 to i16
  %.reass.i = add nuw nsw i16 %invariant.op.i, %39
  br label %40

40:                                               ; preds = %38, %35
  %41 = phi i16 [ %.reass.i, %38 ], [ %23, %35 ]
  store volatile i16 %41, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !1
  %42 = add nuw nsw i8 %.02530.i.i, 1
  %exitcond.not.i39.i = icmp eq i8 %42, 32
  br i1 %exitcond.not.i39.i, label %33, label %35, !llvm.loop !44

43:                                               ; preds = %43, %31
  %.032.i.i = phi i16 [ 0, %31 ], [ %44, %43 ]
  store volatile i16 0, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !1
  %44 = add nuw nsw i16 %.032.i.i, 1
  %exitcond34.not.i.i = icmp eq i16 %44, 2056
  br i1 %exitcond34.not.i.i, label %_canvas_reserve.exit.i, label %43, !llvm.loop !45

_canvas_reserve.exit.i:                           ; preds = %43
  %45 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  %46 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 198), align 1, !tbaa !47
  %47 = or i8 %46, %45
  store i8 %47, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  store volatile i8 %47, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !12
  %48 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  %.not.i11.i = icmp eq i8 %48, 0
  br i1 %.not.i11.i, label %50, label %49

49:                                               ; preds = %_canvas_reserve.exit.i
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !39
  br label %50

50:                                               ; preds = %49, %_canvas_reserve.exit.i
  %51 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %52 = icmp ult i8 %51, 4
  br i1 %52, label %53, label %display_add.exit12.i

53:                                               ; preds = %50
  %54 = zext nneg i8 %51 to i16
  %55 = add nuw nsw i8 %51, 1
  store i8 %55, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %56 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %54
  store ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4305), ptr %56, align 1, !tbaa !41
  br label %display_add.exit12.i

display_add.exit12.i:                             ; preds = %53, %50
  %57 = load ptr, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4305), align 1, !tbaa !48
  %58 = load ptr, ptr %57, align 1, !tbaa !49
  tail call void %58(ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @main.a, i16 4305), ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @main.a, i16 178)) #28, !inline_history !51
  %59 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  %60 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4307), align 1, !tbaa !47
  %61 = or i8 %60, %59
  store i8 %61, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  store volatile i8 %61, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !12
  %62 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !52
  %63 = icmp ugt i8 %62, 15
  br i1 %63, label %upq_push_cgram.exit.i, label %64

64:                                               ; preds = %display_add.exit12.i
  %65 = zext nneg i8 %62 to i16
  %66 = add nuw nsw i8 %62, 1
  store i8 %66, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !52
  %67 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %65
  %68 = getelementptr inbounds nuw i8, ptr %67, i16 10
  store i8 1, ptr %68, align 1, !tbaa !53
  store i16 0, ptr %67, align 1, !tbaa !55
  %69 = getelementptr inbounds nuw i8, ptr %67, i16 9
  store i8 0, ptr %69, align 1, !tbaa !56
  %70 = getelementptr inbounds nuw i8, ptr %67, i16 7
  store i8 34, ptr %70, align 1, !tbaa !57
  %71 = getelementptr inbounds nuw i8, ptr %67, i16 8
  store i8 0, ptr %71, align 1, !tbaa !58
  %72 = getelementptr inbounds nuw i8, ptr %67, i16 2
  store i16 ptrtoint (ptr @bg3_pal to i16), ptr %72, align 1, !tbaa !59
  %73 = getelementptr inbounds nuw i8, ptr %67, i16 6
  store i8 0, ptr %73, align 1, !tbaa !60
  %74 = getelementptr inbounds nuw i8, ptr %67, i16 4
  store i16 8, ptr %74, align 1, !tbaa !61
  br label %upq_push_cgram.exit.i

upq_push_cgram.exit.i:                            ; preds = %64, %display_add.exit12.i
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !62
  br label %75

75:                                               ; preds = %83, %upq_push_cgram.exit.i
  %mos-indexiv.iv21.i.i = phi i8 [ 0, %upq_push_cgram.exit.i ], [ %mos-indexiv.iv.next22.i.i, %83 ]
  %mos-indexiv.iv.i13.i = phi i8 [ 0, %upq_push_cgram.exit.i ], [ %mos-indexiv.iv.next.i17.i, %83 ]
  %76 = phi i8 [ 70, %upq_push_cgram.exit.i ], [ %87, %83 ]
  %77 = zext i8 %76 to i16
  %78 = icmp ugt i8 %76, 31
  br i1 %78, label %79, label %83

79:                                               ; preds = %75
  %80 = icmp ult i8 %76, 96
  br i1 %80, label %81, label %83

81:                                               ; preds = %79
  %82 = add nuw nsw i16 %77, 224
  br label %83

83:                                               ; preds = %81, %79, %75
  %84 = phi i16 [ %82, %81 ], [ 256, %79 ], [ 256, %75 ]
  %85 = zext nneg i8 %mos-indexiv.iv.i13.i to i16
  %uglygep = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4314), i16 %85
  store i16 %84, ptr %uglygep, align 1, !tbaa !1
  %86 = zext nneg i8 %mos-indexiv.iv21.i.i to i16
  %uglygep30 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @.str.2, i16 1), i16 %86
  %87 = load i8, ptr %uglygep30, align 1, !tbaa !12
  %mos-indexiv.iv.next.i17.i = add nuw nsw i8 %mos-indexiv.iv.i13.i, 2
  %mos-indexiv.iv.next22.i.i = add nuw nsw i8 %mos-indexiv.iv21.i.i, 1
  %exitcond.i = icmp eq i8 %mos-indexiv.iv.next22.i.i, 15
  br i1 %exitcond.i, label %text_puts.exit.i, label %75, !llvm.loop !64

text_puts.exit.i:                                 ; preds = %83
  %88 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4440), align 1, !tbaa !37
  br label %89

89:                                               ; preds = %97, %text_puts.exit.i
  %mos-indexiv.iv21.i19.i = phi i8 [ 0, %text_puts.exit.i ], [ %mos-indexiv.iv.next22.i27.i, %97 ]
  %mos-indexiv.iv.i20.i = phi i8 [ 0, %text_puts.exit.i ], [ %mos-indexiv.iv.next.i26.i, %97 ]
  %90 = phi i8 [ 69, %text_puts.exit.i ], [ %101, %97 ]
  %91 = zext i8 %90 to i16
  %92 = icmp ugt i8 %90, 31
  br i1 %92, label %93, label %97

93:                                               ; preds = %89
  %94 = icmp ult i8 %90, 96
  br i1 %94, label %95, label %97

95:                                               ; preds = %93
  %96 = add nuw nsw i16 %91, 224
  br label %97

97:                                               ; preds = %95, %93, %89
  %98 = phi i16 [ %96, %95 ], [ 256, %93 ], [ 256, %89 ]
  %99 = zext nneg i8 %mos-indexiv.iv.i20.i to i16
  %uglygep31 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4376), i16 %99
  store i16 %98, ptr %uglygep31, align 1, !tbaa !1
  %100 = zext nneg i8 %mos-indexiv.iv21.i19.i to i16
  %uglygep32 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @.str.3, i16 1), i16 %100
  %mos-indexiv.iv.next22.i27.i = add nuw nsw i8 %mos-indexiv.iv21.i19.i, 1
  %101 = load i8, ptr %uglygep32, align 1, !tbaa !12
  %mos-indexiv.iv.next.i26.i = add nuw nsw i8 %mos-indexiv.iv.i20.i, 2
  %exitcond31.i = icmp eq i8 %mos-indexiv.iv.next22.i27.i, 29
  br i1 %exitcond31.i, label %app_init.exit, label %89, !llvm.loop !64

app_init.exit:                                    ; preds = %97
  %102 = or i8 %88, 3
  store i8 %102, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4440), align 1, !tbaa !37
  store ptr @TITLE_VT, ptr @main.title, align 1, !tbaa !65
  store i8 2, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !69
  store ptr @.str, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 3), align 1, !tbaa !70
  store ptr @.str.1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 5), align 1, !tbaa !71
  store ptr @.str.1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 7), align 1, !tbaa !72
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 11), align 1, !tbaa !73
  store ptr null, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 9), align 1, !tbaa !74
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 12), align 1, !tbaa !75
  store i16 96, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 13), align 1, !tbaa !76
  store i16 112, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 15), align 1, !tbaa !77
  store i16 16, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 17), align 1, !tbaa !78
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 28), align 1, !tbaa !79
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 29), align 1, !tbaa !80
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !81
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 32), align 1, !tbaa !82
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !83
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !84
  store i16 32767, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 34), align 1, !tbaa !85
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 36), align 1, !tbaa !86
  %103 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  %104 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  %.not.i.i1 = icmp eq i8 %104, 0
  br i1 %.not.i.i1, label %106, label %105

105:                                              ; preds = %app_init.exit
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !39
  br label %106

106:                                              ; preds = %105, %app_init.exit
  %107 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %108 = icmp ult i8 %107, 4
  br i1 %108, label %109, label %display_add.exit.i2

109:                                              ; preds = %106
  %110 = zext nneg i8 %107 to i16
  %111 = add nuw nsw i8 %107, 1
  store i8 %111, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %112 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %110
  store ptr @main.title, ptr %112, align 1, !tbaa !41
  br label %display_add.exit.i2

display_add.exit.i2:                              ; preds = %109, %106
  tail call void @_title_reserve(ptr noundef nonnull @main.title, ptr nonnull poison) #28, !inline_history !87
  %113 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  %114 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !47
  %115 = or i8 %114, %113
  store volatile i8 %115, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !12
  store i8 %103, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 33), align 1, !tbaa !88
  store i8 2, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  store volatile i8 2, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !12
  store volatile i8 24, ptr inttoptr (i16 16908 to ptr), align 4, !tbaa !12
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  br label %.lr.ph.i.i

.lr.ph.i.i:                                       ; preds = %display_frame.exit.i.i, %display_add.exit.i2
  %116 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %.not.i.i.i.i = icmp eq i8 %116, 0
  br i1 %.not.i.i.i.i, label %scene_emit.exit.i.i.i, label %.lr.ph.i.i.i.i

.lr.ph.i.i.i.i:                                   ; preds = %.lr.ph.i.i.i.i, %.lr.ph.i.i
  %.06.i.i.i.i = phi i8 [ %123, %.lr.ph.i.i.i.i ], [ 0, %.lr.ph.i.i ]
  %117 = zext i8 %.06.i.i.i.i to i16
  %118 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %117
  %119 = load ptr, ptr %118, align 1, !tbaa !41
  %120 = load ptr, ptr %119, align 1, !tbaa !48
  %121 = getelementptr inbounds nuw i8, ptr %120, i16 2
  %122 = load ptr, ptr %121, align 1, !tbaa !89
  tail call void %122(ptr noundef nonnull %119, ptr noundef nonnull @main.a) #28, !inline_history !90
  %123 = add nuw i8 %.06.i.i.i.i, 1
  %124 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %125 = icmp ult i8 %123, %124
  br i1 %125, label %.lr.ph.i.i.i.i, label %scene_emit.exit.i.i.i, !llvm.loop !91

scene_emit.exit.i.i.i:                            ; preds = %.lr.ph.i.i.i.i, %.lr.ph.i.i
  %126 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  br label %127

127:                                              ; preds = %127, %scene_emit.exit.i.i.i
  %128 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  %.not.i12.i.i.i = icmp sgt i8 %128, -1
  br i1 %.not.i12.i.i.i, label %127, label %snes_wait_vblank.exit.i.i.i, !llvm.loop !92

snes_wait_vblank.exit.i.i.i:                      ; preds = %127
  tail call fastcc void @upq_flush()
  %129 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %130 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  %131 = icmp ult i8 %129, %130
  br i1 %131, label %.sink.split.i.i.i, label %132

132:                                              ; preds = %snes_wait_vblank.exit.i.i.i
  %133 = icmp ugt i8 %129, %130
  br i1 %133, label %.sink.split.i.i.i, label %display_frame.exit.i.i

.sink.split.i.i.i:                                ; preds = %132, %snes_wait_vblank.exit.i.i.i
  %.sink14.i.i.i = phi i8 [ 1, %snes_wait_vblank.exit.i.i.i ], [ -1, %132 ]
  %134 = add i8 %.sink14.i.i.i, %129
  store i8 %134, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  br label %display_frame.exit.i.i

display_frame.exit.i.i:                           ; preds = %.sink.split.i.i.i, %132
  %135 = phi i8 [ %129, %132 ], [ %134, %.sink.split.i.i.i ]
  %136 = and i8 %135, 15
  store volatile i8 %136, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !12
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  %137 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %.not.i24.i = icmp eq i8 %137, 15
  br i1 %.not.i24.i, label %display_fade.exit.i, label %.lr.ph.i.i, !llvm.loop !93

display_fade.exit.i:                              ; preds = %display_frame.exit.i.i
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !83
  %138 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !84
  %.not25.not.i = icmp eq i8 %138, -1
  br i1 %.not25.not.i, label %title_begin.exit, label %.lr.ph.i

.lr.ph.i:                                         ; preds = %display_frame.exit.i, %display_fade.exit.i
  %.026.i = phi i8 [ %160, %display_frame.exit.i ], [ 0, %display_fade.exit.i ]
  %139 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %.not.i.i.i = icmp eq i8 %139, 0
  br i1 %.not.i.i.i, label %scene_emit.exit.i.i, label %.lr.ph.i.i.i

.lr.ph.i.i.i:                                     ; preds = %.lr.ph.i.i.i, %.lr.ph.i
  %.06.i.i.i = phi i8 [ %146, %.lr.ph.i.i.i ], [ 0, %.lr.ph.i ]
  %140 = zext i8 %.06.i.i.i to i16
  %141 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %140
  %142 = load ptr, ptr %141, align 1, !tbaa !41
  %143 = load ptr, ptr %142, align 1, !tbaa !48
  %144 = getelementptr inbounds nuw i8, ptr %143, i16 2
  %145 = load ptr, ptr %144, align 1, !tbaa !89
  tail call void %145(ptr noundef nonnull %142, ptr noundef nonnull @main.a) #28, !inline_history !94
  %146 = add nuw i8 %.06.i.i.i, 1
  %147 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %148 = icmp ult i8 %146, %147
  br i1 %148, label %.lr.ph.i.i.i, label %scene_emit.exit.i.i, !llvm.loop !91

scene_emit.exit.i.i:                              ; preds = %.lr.ph.i.i.i, %.lr.ph.i
  %149 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  br label %150

150:                                              ; preds = %150, %scene_emit.exit.i.i
  %151 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  %.not.i12.i.i = icmp sgt i8 %151, -1
  br i1 %.not.i12.i.i, label %150, label %snes_wait_vblank.exit.i.i, !llvm.loop !92

snes_wait_vblank.exit.i.i:                        ; preds = %150
  tail call fastcc void @upq_flush()
  %152 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %153 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  %154 = icmp ult i8 %152, %153
  br i1 %154, label %.sink.split.i.i, label %155

155:                                              ; preds = %snes_wait_vblank.exit.i.i
  %156 = icmp ugt i8 %152, %153
  br i1 %156, label %.sink.split.i.i, label %display_frame.exit.i

.sink.split.i.i:                                  ; preds = %155, %snes_wait_vblank.exit.i.i
  %.sink14.i.i = phi i8 [ 1, %snes_wait_vblank.exit.i.i ], [ -1, %155 ]
  %157 = add i8 %.sink14.i.i, %152
  store i8 %157, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  br label %display_frame.exit.i

display_frame.exit.i:                             ; preds = %.sink.split.i.i, %155
  %158 = phi i8 [ %152, %155 ], [ %157, %.sink.split.i.i ]
  %159 = and i8 %158, 15
  store volatile i8 %159, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !12
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  %160 = add nuw i8 %.026.i, 1
  %161 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !84
  %.not.i = icmp ne i8 %161, -1
  %162 = icmp ult i8 %.026.i, -57
  %or.cond.i = select i1 %.not.i, i1 %162, i1 false
  br i1 %or.cond.i, label %.lr.ph.i, label %title_begin.exit, !llvm.loop !95

title_begin.exit:                                 ; preds = %display_frame.exit.i, %display_fade.exit.i
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !83
  tail call fastcc void @ds_dither(i8 noundef zeroext 24, i8 noundef zeroext 24, i16 noundef 0, ptr noundef nonnull @dither_gate_crc.out)
  br label %183

163:                                              ; preds = %183
  %.lcssa58 = phi i16 [ %190, %183 ]
  tail call fastcc void @ds_dither(i8 noundef zeroext 24, i8 noundef zeroext 24, i16 noundef 37, ptr noundef nonnull @dither_gate_crc.out)
  br label %164

164:                                              ; preds = %164, %163
  %.012.1.i = phi i16 [ 0, %163 ], [ %172, %164 ]
  %.111.1.i = phi i16 [ %.lcssa58, %163 ], [ %171, %164 ]
  %165 = getelementptr inbounds nuw i8, ptr @dither_gate_crc.out, i16 %.012.1.i
  %166 = load i8, ptr %165, align 1, !tbaa !12
  %167 = zext i8 %166 to i16
  %168 = shl nuw nsw i16 %.012.1.i, 2
  %169 = tail call i16 @llvm.fshl.i16(i16 %.111.1.i, i16 %.111.1.i, i16 1)
  %170 = xor i16 %169, %168
  %171 = xor i16 %170, %167
  %172 = add nuw nsw i16 %.012.1.i, 1
  %exitcond.1.not.i = icmp eq i16 %172, 576
  br i1 %exitcond.1.not.i, label %173, label %164, !llvm.loop !96

173:                                              ; preds = %164
  %.lcssa57 = phi i16 [ %171, %164 ]
  tail call fastcc void @ds_dither(i8 noundef zeroext 24, i8 noundef zeroext 24, i16 noundef 74, ptr noundef nonnull @dither_gate_crc.out)
  br label %174

174:                                              ; preds = %174, %173
  %.012.2.i = phi i16 [ 0, %173 ], [ %182, %174 ]
  %.111.2.i = phi i16 [ %.lcssa57, %173 ], [ %181, %174 ]
  %175 = getelementptr inbounds nuw i8, ptr @dither_gate_crc.out, i16 %.012.2.i
  %176 = load i8, ptr %175, align 1, !tbaa !12
  %177 = zext i8 %176 to i16
  %178 = shl nuw nsw i16 %.012.2.i, 2
  %179 = tail call i16 @llvm.fshl.i16(i16 %.111.2.i, i16 %.111.2.i, i16 1)
  %180 = xor i16 %179, %178
  %181 = xor i16 %180, %177
  %182 = add nuw nsw i16 %.012.2.i, 1
  %exitcond.2.not.i = icmp eq i16 %182, 576
  br i1 %exitcond.2.not.i, label %dither_gate_crc.exit, label %174, !llvm.loop !96

183:                                              ; preds = %183, %title_begin.exit
  %.012.i = phi i16 [ 0, %title_begin.exit ], [ %191, %183 ]
  %.111.i = phi i16 [ 0, %title_begin.exit ], [ %190, %183 ]
  %184 = getelementptr inbounds nuw i8, ptr @dither_gate_crc.out, i16 %.012.i
  %185 = load i8, ptr %184, align 1, !tbaa !12
  %186 = zext i8 %185 to i16
  %187 = shl nuw nsw i16 %.012.i, 2
  %188 = tail call i16 @llvm.fshl.i16(i16 %.111.i, i16 %.111.i, i16 1)
  %189 = xor i16 %188, %187
  %190 = xor i16 %189, %186
  %191 = add nuw nsw i16 %.012.i, 1
  %exitcond.not.i = icmp eq i16 %191, 576
  br i1 %exitcond.not.i, label %163, label %183, !llvm.loop !96

dither_gate_crc.exit:                             ; preds = %174
  %.lcssa = phi i16 [ %181, %174 ]
  store volatile i16 %.lcssa, ptr @corpus_result, align 1, !tbaa !1
  br label %192

192:                                              ; preds = %display_frame.exit.i.i9, %dither_gate_crc.exit
  %.01.i.i = phi i16 [ 110, %dither_gate_crc.exit ], [ %193, %display_frame.exit.i.i9 ]
  %193 = add nsw i16 %.01.i.i, -1
  %194 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %.not.i.i.i.i3 = icmp eq i8 %194, 0
  br i1 %.not.i.i.i.i3, label %scene_emit.exit.i.i.i6, label %.lr.ph.i.i.i.i4

.lr.ph.i.i.i.i4:                                  ; preds = %.lr.ph.i.i.i.i4, %192
  %.06.i.i.i.i5 = phi i8 [ %201, %.lr.ph.i.i.i.i4 ], [ 0, %192 ]
  %195 = zext i8 %.06.i.i.i.i5 to i16
  %196 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %195
  %197 = load ptr, ptr %196, align 1, !tbaa !41
  %198 = load ptr, ptr %197, align 1, !tbaa !48
  %199 = getelementptr inbounds nuw i8, ptr %198, i16 2
  %200 = load ptr, ptr %199, align 1, !tbaa !89
  tail call void %200(ptr noundef nonnull %197, ptr noundef nonnull @main.a) #28, !inline_history !97
  %201 = add nuw i8 %.06.i.i.i.i5, 1
  %202 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %203 = icmp ult i8 %201, %202
  br i1 %203, label %.lr.ph.i.i.i.i4, label %scene_emit.exit.i.i.i6, !llvm.loop !91

scene_emit.exit.i.i.i6:                           ; preds = %.lr.ph.i.i.i.i4, %192
  %204 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  br label %205

205:                                              ; preds = %205, %scene_emit.exit.i.i.i6
  %206 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  %.not.i12.i.i.i7 = icmp sgt i8 %206, -1
  br i1 %.not.i12.i.i.i7, label %205, label %snes_wait_vblank.exit.i.i.i8, !llvm.loop !92

snes_wait_vblank.exit.i.i.i8:                     ; preds = %205
  tail call fastcc void @upq_flush()
  %207 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %208 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  %209 = icmp ult i8 %207, %208
  br i1 %209, label %.sink.split.i.i.i25, label %210

210:                                              ; preds = %snes_wait_vblank.exit.i.i.i8
  %211 = icmp ugt i8 %207, %208
  br i1 %211, label %.sink.split.i.i.i25, label %display_frame.exit.i.i9

.sink.split.i.i.i25:                              ; preds = %210, %snes_wait_vblank.exit.i.i.i8
  %.sink14.i.i.i26 = phi i8 [ 1, %snes_wait_vblank.exit.i.i.i8 ], [ -1, %210 ]
  %212 = add i8 %.sink14.i.i.i26, %207
  store i8 %212, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  br label %display_frame.exit.i.i9

display_frame.exit.i.i9:                          ; preds = %.sink.split.i.i.i25, %210
  %213 = phi i8 [ %207, %210 ], [ %212, %.sink.split.i.i.i25 ]
  %214 = and i8 %213, 15
  store volatile i8 %214, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !12
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  %.not.i.i10 = icmp eq i16 %193, 0
  br i1 %.not.i.i10, label %display_hold.exit.i, label %192, !llvm.loop !98

display_hold.exit.i:                              ; preds = %display_frame.exit.i.i9
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !81
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 32), align 1, !tbaa !82
  br label %217

215:                                              ; preds = %display_frame.exit.i18
  %216 = add nuw nsw i8 %.026.i11, 1
  %exitcond.not.i19 = icmp eq i8 %216, 90
  br i1 %exitcond.not.i19, label %241, label %217, !llvm.loop !99

217:                                              ; preds = %215, %display_hold.exit.i
  %.026.i11 = phi i8 [ 0, %display_hold.exit.i ], [ %216, %215 ]
  %218 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %.not.i.i.i12 = icmp eq i8 %218, 0
  br i1 %.not.i.i.i12, label %scene_emit.exit.i.i15, label %.lr.ph.i.i.i13

.lr.ph.i.i.i13:                                   ; preds = %.lr.ph.i.i.i13, %217
  %.06.i.i.i14 = phi i8 [ %225, %.lr.ph.i.i.i13 ], [ 0, %217 ]
  %219 = zext i8 %.06.i.i.i14 to i16
  %220 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %219
  %221 = load ptr, ptr %220, align 1, !tbaa !41
  %222 = load ptr, ptr %221, align 1, !tbaa !48
  %223 = getelementptr inbounds nuw i8, ptr %222, i16 2
  %224 = load ptr, ptr %223, align 1, !tbaa !89
  tail call void %224(ptr noundef nonnull %221, ptr noundef nonnull @main.a) #28, !inline_history !100
  %225 = add nuw i8 %.06.i.i.i14, 1
  %226 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %227 = icmp ult i8 %225, %226
  br i1 %227, label %.lr.ph.i.i.i13, label %scene_emit.exit.i.i15, !llvm.loop !91

scene_emit.exit.i.i15:                            ; preds = %.lr.ph.i.i.i13, %217
  %228 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  br label %229

229:                                              ; preds = %229, %scene_emit.exit.i.i15
  %230 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  %.not.i12.i.i16 = icmp sgt i8 %230, -1
  br i1 %.not.i12.i.i16, label %229, label %snes_wait_vblank.exit.i.i17, !llvm.loop !92

snes_wait_vblank.exit.i.i17:                      ; preds = %229
  tail call fastcc void @upq_flush()
  %231 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %232 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  %233 = icmp ult i8 %231, %232
  br i1 %233, label %.sink.split.i.i23, label %234

234:                                              ; preds = %snes_wait_vblank.exit.i.i17
  %235 = icmp ugt i8 %231, %232
  br i1 %235, label %.sink.split.i.i23, label %display_frame.exit.i18

.sink.split.i.i23:                                ; preds = %234, %snes_wait_vblank.exit.i.i17
  %.sink14.i.i24 = phi i8 [ 1, %snes_wait_vblank.exit.i.i17 ], [ -1, %234 ]
  %236 = add i8 %.sink14.i.i24, %231
  store i8 %236, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  br label %display_frame.exit.i18

display_frame.exit.i18:                           ; preds = %.sink.split.i.i23, %234
  %237 = phi i8 [ %231, %234 ], [ %236, %.sink.split.i.i23 ]
  %238 = and i8 %237, 15
  store volatile i8 %238, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !12
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  %239 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 19), align 1, !tbaa !101
  %240 = icmp sgt i16 %239, 3583
  br i1 %240, label %241, label %215

241:                                              ; preds = %display_frame.exit.i18, %215
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !81
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  %242 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %.not4.i.i = icmp eq i8 %242, 0
  br i1 %.not4.i.i, label %display_fade.exit.i21, label %.lr.ph.i.i20

.lr.ph.i.i20:                                     ; preds = %display_frame.exit.i22.i, %241
  %243 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %.not.i.i.i16.i = icmp eq i8 %243, 0
  br i1 %.not.i.i.i16.i, label %scene_emit.exit.i.i19.i, label %.lr.ph.i.i.i17.i

.lr.ph.i.i.i17.i:                                 ; preds = %.lr.ph.i.i.i17.i, %.lr.ph.i.i20
  %.06.i.i.i18.i = phi i8 [ %250, %.lr.ph.i.i.i17.i ], [ 0, %.lr.ph.i.i20 ]
  %244 = zext i8 %.06.i.i.i18.i to i16
  %245 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %244
  %246 = load ptr, ptr %245, align 1, !tbaa !41
  %247 = load ptr, ptr %246, align 1, !tbaa !48
  %248 = getelementptr inbounds nuw i8, ptr %247, i16 2
  %249 = load ptr, ptr %248, align 1, !tbaa !89
  tail call void %249(ptr noundef nonnull %246, ptr noundef nonnull @main.a) #28, !inline_history !102
  %250 = add nuw i8 %.06.i.i.i18.i, 1
  %251 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %252 = icmp ult i8 %250, %251
  br i1 %252, label %.lr.ph.i.i.i17.i, label %scene_emit.exit.i.i19.i, !llvm.loop !91

scene_emit.exit.i.i19.i:                          ; preds = %.lr.ph.i.i.i17.i, %.lr.ph.i.i20
  %253 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  br label %254

254:                                              ; preds = %254, %scene_emit.exit.i.i19.i
  %255 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  %.not.i12.i.i20.i = icmp sgt i8 %255, -1
  br i1 %.not.i12.i.i20.i, label %254, label %snes_wait_vblank.exit.i.i21.i, !llvm.loop !92

snes_wait_vblank.exit.i.i21.i:                    ; preds = %254
  tail call fastcc void @upq_flush()
  %256 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %257 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  %258 = icmp ult i8 %256, %257
  br i1 %258, label %.sink.split.i.i24.i, label %259

259:                                              ; preds = %snes_wait_vblank.exit.i.i21.i
  %260 = icmp ugt i8 %256, %257
  br i1 %260, label %.sink.split.i.i24.i, label %display_frame.exit.i22.i

.sink.split.i.i24.i:                              ; preds = %259, %snes_wait_vblank.exit.i.i21.i
  %.sink14.i.i25.i = phi i8 [ 1, %snes_wait_vblank.exit.i.i21.i ], [ -1, %259 ]
  %261 = add i8 %.sink14.i.i25.i, %256
  store i8 %261, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  br label %display_frame.exit.i22.i

display_frame.exit.i22.i:                         ; preds = %.sink.split.i.i24.i, %259
  %262 = phi i8 [ %256, %259 ], [ %261, %.sink.split.i.i24.i ]
  %263 = and i8 %262, 15
  store volatile i8 %263, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !12
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  %264 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %.not.i23.i = icmp eq i8 %264, 0
  br i1 %.not.i23.i, label %display_fade.exit.i21, label %.lr.ph.i.i20, !llvm.loop !93

display_fade.exit.i21:                            ; preds = %display_frame.exit.i22.i, %241
  %265 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 33), align 1, !tbaa !88
  %266 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  %267 = or i8 %266, %265
  %268 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !47
  %269 = xor i8 %268, -1
  %270 = and i8 %267, %269
  store i8 %270, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !46
  store volatile i8 %270, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !12
  store volatile i8 0, ptr inttoptr (i16 16908 to ptr), align 4, !tbaa !12
  store volatile i8 0, ptr inttoptr (i16 8463 to ptr), align 1, !tbaa !12
  store volatile i8 0, ptr inttoptr (i16 8463 to ptr), align 1, !tbaa !12
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !12
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !12
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 29), align 1, !tbaa !80
  %271 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !52
  %272 = icmp ugt i8 %271, 15
  br i1 %272, label %title_end.exit.thread, label %title_end.exit

title_end.exit.thread:                            ; preds = %display_fade.exit.i21
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  br label %upq_push_cgram.exit.preheader

title_end.exit:                                   ; preds = %display_fade.exit.i21
  %273 = zext nneg i8 %271 to i16
  %274 = add nuw nsw i8 %271, 1
  store i8 %274, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !52
  %275 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %273
  %276 = getelementptr inbounds nuw i8, ptr %275, i16 10
  store i8 1, ptr %276, align 1, !tbaa !53
  store i16 0, ptr %275, align 1, !tbaa !55
  %277 = getelementptr inbounds nuw i8, ptr %275, i16 9
  store i8 0, ptr %277, align 1, !tbaa !56
  %278 = getelementptr inbounds nuw i8, ptr %275, i16 7
  store i8 34, ptr %278, align 1, !tbaa !57
  %279 = getelementptr inbounds nuw i8, ptr %275, i16 8
  store i8 0, ptr %279, align 1, !tbaa !58
  %280 = getelementptr inbounds nuw i8, ptr %275, i16 2
  store i16 ptrtoint (ptr @title_end._title_bg_black to i16), ptr %280, align 1, !tbaa !59
  %281 = getelementptr inbounds nuw i8, ptr %275, i16 6
  store i8 0, ptr %281, align 1, !tbaa !60
  %282 = getelementptr inbounds nuw i8, ptr %275, i16 4
  store i16 2, ptr %282, align 1, !tbaa !61
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  %283 = icmp eq i8 %271, 15
  br i1 %283, label %upq_push_cgram.exit.preheader, label %284

284:                                              ; preds = %title_end.exit
  %285 = zext nneg i8 %274 to i16
  %286 = add nuw nsw i8 %271, 2
  store i8 %286, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !52
  %287 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %285
  %288 = getelementptr inbounds nuw i8, ptr %287, i16 10
  store i8 1, ptr %288, align 1, !tbaa !53
  store i16 0, ptr %287, align 1, !tbaa !55
  %289 = getelementptr inbounds nuw i8, ptr %287, i16 9
  store i8 0, ptr %289, align 1, !tbaa !56
  %290 = getelementptr inbounds nuw i8, ptr %287, i16 7
  store i8 34, ptr %290, align 1, !tbaa !57
  %291 = getelementptr inbounds nuw i8, ptr %287, i16 8
  store i8 0, ptr %291, align 1, !tbaa !58
  %292 = getelementptr inbounds nuw i8, ptr %287, i16 2
  store i16 ptrtoint (ptr @bg3_pal to i16), ptr %292, align 1, !tbaa !59
  %293 = getelementptr inbounds nuw i8, ptr %287, i16 6
  store i8 0, ptr %293, align 1, !tbaa !60
  %294 = getelementptr inbounds nuw i8, ptr %287, i16 4
  store i16 8, ptr %294, align 1, !tbaa !61
  br label %upq_push_cgram.exit.preheader

upq_push_cgram.exit.preheader:                    ; preds = %284, %title_end.exit, %title_end.exit.thread
  br label %upq_push_cgram.exit

upq_push_cgram.exit:                              ; preds = %display_frame.exit, %upq_push_cgram.exit.preheader
  tail call fastcc void @dither_frame()
  %295 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !62
  %296 = add i16 %295, 3
  store i16 %296, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !62
  %297 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %.not.i.i27 = icmp eq i8 %297, 0
  br i1 %.not.i.i27, label %scene_emit.exit.i, label %.lr.ph.i.i28

.lr.ph.i.i28:                                     ; preds = %.lr.ph.i.i28, %upq_push_cgram.exit
  %.06.i.i = phi i8 [ %304, %.lr.ph.i.i28 ], [ 0, %upq_push_cgram.exit ]
  %298 = zext i8 %.06.i.i to i16
  %299 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %298
  %300 = load ptr, ptr %299, align 1, !tbaa !41
  %301 = load ptr, ptr %300, align 1, !tbaa !48
  %302 = getelementptr inbounds nuw i8, ptr %301, i16 2
  %303 = load ptr, ptr %302, align 1, !tbaa !89
  tail call void %303(ptr noundef nonnull %300, ptr noundef nonnull @main.a) #28, !inline_history !103
  %304 = add nuw i8 %.06.i.i, 1
  %305 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !40
  %306 = icmp ult i8 %304, %305
  br i1 %306, label %.lr.ph.i.i28, label %scene_emit.exit.i, !llvm.loop !91

scene_emit.exit.i:                                ; preds = %.lr.ph.i.i28, %upq_push_cgram.exit
  %307 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  br label %308

308:                                              ; preds = %308, %scene_emit.exit.i
  %309 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !12
  %.not.i12.i = icmp sgt i8 %309, -1
  br i1 %.not.i12.i, label %308, label %snes_wait_vblank.exit.i, !llvm.loop !92

snes_wait_vblank.exit.i:                          ; preds = %308
  tail call fastcc void @upq_flush()
  %310 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  %311 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !20
  %312 = icmp ult i8 %310, %311
  br i1 %312, label %.sink.split.i, label %313

313:                                              ; preds = %snes_wait_vblank.exit.i
  %314 = icmp ugt i8 %310, %311
  br i1 %314, label %.sink.split.i, label %display_frame.exit

.sink.split.i:                                    ; preds = %313, %snes_wait_vblank.exit.i
  %.sink14.i = phi i8 [ 1, %snes_wait_vblank.exit.i ], [ -1, %313 ]
  %315 = add i8 %.sink14.i, %310
  store i8 %315, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !15
  br label %display_frame.exit

display_frame.exit:                               ; preds = %.sink.split.i, %313
  %316 = phi i8 [ %310, %313 ], [ %315, %.sink.split.i ]
  %317 = and i8 %316, 15
  store volatile i8 %317, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !12
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !38
  br label %upq_push_cgram.exit
}
