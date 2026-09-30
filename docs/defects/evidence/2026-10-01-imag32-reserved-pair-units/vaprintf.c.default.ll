; ModuleID = '/work/examples/snes/vaprintf.c'
source_filename = "/work/examples/snes/vaprintf.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.App = type { %struct.Display, %struct.BitmapCanvas, %struct.TextLayer, i8, i16, i16, i16, i16, i8 }
%struct.Display = type { %struct.UploadQueue, %struct.VramAlloc, %struct.Scene, i8, i8, i8, i8, i8 }
%struct.UploadQueue = type { [16 x %struct.UpqJob], i8, i8 }
%struct.UpqJob = type { i16, i16, i16, i8, i8, i8, i8, i8 }
%struct.VramAlloc = type { i16, i16 }
%struct.Scene = type { [4 x ptr], i8 }
%struct.BitmapCanvas = type { %struct.Drawable, [4096 x i8], i16, i16, i16, i16, i8, i8 }
%struct.Drawable = type { ptr, i8 }
%struct.TextLayer = type { %struct.Drawable, i16, [2 x i8], [64 x i16], i8 }
%struct.TitleLayer = type { %struct.Drawable, ptr, ptr, ptr, ptr, i8, i8, i16, i16, i16, i16, i16, i16, i8, i16, i8, i8, i8, i8, i8, i8, i16, i16, %struct.HScrollDB, %struct.HScrollDB }
%struct.HScrollDB = type { [2 x %struct.HScrollN], i8 }
%struct.HScrollN = type { [25 x i8] }
%struct.DrawableVT = type { ptr, ptr }
%struct.HScrollW = type { ptr, i8 }

@main.a = internal global %struct.App zeroinitializer, align 1
@main.title = internal global %struct.TitleLayer zeroinitializer, align 1
@.str = private unnamed_addr constant [7 x i8] c"VA_ARG\00", align 1
@.str.1 = private unnamed_addr constant [10 x i8] c"LISSAJOUS\00", align 1
@corpus_result = dso_local global i16 0, align 1
@PAIRS_FX = internal unnamed_addr constant [6 x i8] c"\01\02\03\02\04\03", align 1
@PAIRS_FY = internal unnamed_addr constant [6 x i8] c"\02\03\04\05\05\02", align 1
@bg3_pal = internal constant [4 x i16] [i16 0, i16 25368, i16 476, i16 29376], align 1
@CANVAS_VT = internal constant %struct.DrawableVT { ptr @_canvas_reserve, ptr @_canvas_emit }, align 1
@TEXT_VT = internal constant %struct.DrawableVT { ptr @_text_reserve, ptr @_text_emit }, align 1
@FONT8 = internal unnamed_addr constant [512 x i16] [i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 32, i16 32, i16 32, i16 32, i16 32, i16 0, i16 32, i16 0, i16 80, i16 80, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 80, i16 80, i16 248, i16 80, i16 248, i16 80, i16 80, i16 0, i16 32, i16 120, i16 160, i16 112, i16 40, i16 240, i16 32, i16 0, i16 196, i16 200, i16 16, i16 32, i16 64, i16 152, i16 12, i16 0, i16 96, i16 144, i16 160, i16 64, i16 168, i16 144, i16 104, i16 0, i16 32, i16 32, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 16, i16 32, i16 64, i16 64, i16 64, i16 32, i16 16, i16 0, i16 64, i16 32, i16 16, i16 16, i16 16, i16 32, i16 64, i16 0, i16 0, i16 32, i16 168, i16 112, i16 168, i16 32, i16 0, i16 0, i16 0, i16 32, i16 32, i16 248, i16 32, i16 32, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 96, i16 96, i16 64, i16 0, i16 0, i16 0, i16 248, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 96, i16 96, i16 0, i16 8, i16 8, i16 16, i16 32, i16 64, i16 128, i16 128, i16 0, i16 112, i16 136, i16 152, i16 168, i16 200, i16 136, i16 112, i16 0, i16 32, i16 96, i16 32, i16 32, i16 32, i16 32, i16 112, i16 0, i16 112, i16 136, i16 8, i16 16, i16 32, i16 64, i16 248, i16 0, i16 112, i16 136, i16 8, i16 48, i16 8, i16 136, i16 112, i16 0, i16 16, i16 48, i16 80, i16 144, i16 248, i16 16, i16 16, i16 0, i16 248, i16 128, i16 240, i16 8, i16 8, i16 136, i16 112, i16 0, i16 112, i16 136, i16 128, i16 240, i16 136, i16 136, i16 112, i16 0, i16 248, i16 8, i16 16, i16 32, i16 64, i16 64, i16 64, i16 0, i16 112, i16 136, i16 136, i16 112, i16 136, i16 136, i16 112, i16 0, i16 112, i16 136, i16 136, i16 120, i16 8, i16 136, i16 112, i16 0, i16 0, i16 32, i16 32, i16 0, i16 32, i16 32, i16 0, i16 0, i16 0, i16 32, i16 32, i16 0, i16 32, i16 32, i16 64, i16 0, i16 16, i16 32, i16 64, i16 128, i16 64, i16 32, i16 16, i16 0, i16 0, i16 0, i16 248, i16 0, i16 248, i16 0, i16 0, i16 0, i16 128, i16 64, i16 32, i16 16, i16 32, i16 64, i16 128, i16 0, i16 112, i16 136, i16 8, i16 16, i16 32, i16 0, i16 32, i16 0, i16 112, i16 136, i16 184, i16 168, i16 184, i16 128, i16 112, i16 0, i16 112, i16 136, i16 136, i16 248, i16 136, i16 136, i16 136, i16 0, i16 240, i16 136, i16 136, i16 240, i16 136, i16 136, i16 240, i16 0, i16 112, i16 136, i16 128, i16 128, i16 128, i16 136, i16 112, i16 0, i16 224, i16 144, i16 136, i16 136, i16 136, i16 144, i16 224, i16 0, i16 248, i16 128, i16 128, i16 240, i16 128, i16 128, i16 248, i16 0, i16 248, i16 128, i16 128, i16 240, i16 128, i16 128, i16 128, i16 0, i16 112, i16 136, i16 128, i16 176, i16 136, i16 136, i16 112, i16 0, i16 136, i16 136, i16 136, i16 248, i16 136, i16 136, i16 136, i16 0, i16 112, i16 32, i16 32, i16 32, i16 32, i16 32, i16 112, i16 0, i16 56, i16 16, i16 16, i16 16, i16 144, i16 144, i16 96, i16 0, i16 136, i16 144, i16 160, i16 192, i16 160, i16 144, i16 136, i16 0, i16 128, i16 128, i16 128, i16 128, i16 128, i16 128, i16 248, i16 0, i16 136, i16 216, i16 168, i16 136, i16 136, i16 136, i16 136, i16 0, i16 136, i16 200, i16 168, i16 152, i16 136, i16 136, i16 136, i16 0, i16 112, i16 136, i16 136, i16 136, i16 136, i16 136, i16 112, i16 0, i16 240, i16 136, i16 136, i16 240, i16 128, i16 128, i16 128, i16 0, i16 112, i16 136, i16 136, i16 136, i16 168, i16 144, i16 104, i16 0, i16 240, i16 136, i16 136, i16 240, i16 160, i16 144, i16 136, i16 0, i16 112, i16 136, i16 128, i16 112, i16 8, i16 136, i16 112, i16 0, i16 248, i16 32, i16 32, i16 32, i16 32, i16 32, i16 32, i16 0, i16 136, i16 136, i16 136, i16 136, i16 136, i16 136, i16 112, i16 0, i16 136, i16 136, i16 136, i16 136, i16 136, i16 80, i16 32, i16 0, i16 136, i16 136, i16 136, i16 168, i16 168, i16 216, i16 136, i16 0, i16 136, i16 136, i16 80, i16 32, i16 80, i16 136, i16 136, i16 0, i16 136, i16 136, i16 80, i16 32, i16 32, i16 32, i16 32, i16 0, i16 248, i16 8, i16 16, i16 32, i16 64, i16 128, i16 248, i16 0, i16 48, i16 32, i16 32, i16 32, i16 32, i16 32, i16 48, i16 0, i16 128, i16 128, i16 64, i16 32, i16 16, i16 8, i16 8, i16 0, i16 48, i16 16, i16 16, i16 16, i16 16, i16 16, i16 48, i16 0, i16 32, i16 80, i16 136, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 248], align 1
@TITLE_VT = internal constant %struct.DrawableVT { ptr @_title_reserve, ptr @_title_emit }, align 1
@FONT16 = internal unnamed_addr constant [2048 x i16] [i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 15, i16 15, i16 15, i16 15, i16 15, i16 192, i16 192, i16 12480, i16 12480, i16 12480, i16 12480, i16 12480, i16 12480, i16 15, i16 768, i16 768, i16 15, i16 15, i16 15, i16 768, i16 768, i16 12480, i16 -4096, i16 -4096, i16 192, i16 192, i16 12480, i16 -4096, i16 -4096, i16 60, i16 60, i16 828, i16 828, i16 3840, i16 3840, i16 0, i16 0, i16 240, i16 240, i16 3312, i16 3312, i16 15360, i16 15360, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 28, i16 28, i16 796, i16 127, i16 127, i16 796, i16 796, i16 127, i16 112, i16 112, i16 3184, i16 252, i16 252, i16 -28816, i16 -28816, i16 252, i16 127, i16 796, i16 796, i16 796, i16 1792, i16 1792, i16 0, i16 0, i16 252, i16 -28816, i16 -28816, i16 3184, i16 7168, i16 7168, i16 0, i16 0, i16 3, i16 63, i16 123, i16 1147, i16 63, i16 4111, i16 3075, i16 123, i16 192, i16 248, i16 8414, i16 16064, i16 2040, i16 248, i16 8414, i16 8414, i16 63, i16 7171, i16 3840, i16 0, i16 0, i16 0, i16 0, i16 0, i16 2040, i16 14272, i16 -512, i16 -4096, i16 0, i16 0, i16 0, i16 0, i16 60, i16 60, i16 828, i16 828, i16 3840, i16 3585, i16 3, i16 7, i16 28, i16 56, i16 1904, i16 3808, i16 7392, i16 14528, i16 14464, i16 28672, i16 14, i16 284, i16 824, i16 1792, i16 3584, i16 0, i16 0, i16 0, i16 -8162, i16 -16354, i16 -32482, i16 286, i16 1792, i16 1792, i16 0, i16 0, i16 15, i16 31, i16 828, i16 828, i16 573, i16 31, i16 31, i16 63, i16 192, i16 224, i16 240, i16 2288, i16 7392, i16 15488, i16 30720, i16 -32648, i16 382, i16 3060, i16 3825, i16 1275, i16 127, i16 63, i16 7936, i16 3840, i16 248, i16 3824, i16 7904, i16 7392, i16 4332, i16 12492, i16 -1280, i16 -3328, i16 15, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 -16384, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 3, i16 7, i16 15, i16 15, i16 15, i16 15, i16 15, i16 240, i16 192, i16 15488, i16 -4096, i16 -8192, i16 -16384, i16 -16384, i16 -16384, i16 15, i16 7, i16 3, i16 256, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 16512, i16 192, i16 240, i16 -4096, i16 15360, i16 0, i16 0, i16 15, i16 3, i16 513, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 192, i16 224, i16 240, i16 2288, i16 3312, i16 3312, i16 3312, i16 0, i16 1, i16 3, i16 15, i16 0, i16 768, i16 0, i16 0, i16 3312, i16 7392, i16 15552, i16 30720, i16 -4096, i16 -16384, i16 0, i16 0, i16 0, i16 0, i16 3, i16 3, i16 51, i16 31, i16 15, i16 1027, i16 0, i16 0, i16 192, i16 192, i16 12492, i16 252, i16 1016, i16 16320, i16 15, i16 31, i16 51, i16 1027, i16 3072, i16 0, i16 0, i16 0, i16 1784, i16 252, i16 13004, i16 16320, i16 -3328, i16 -4096, i16 0, i16 0, i16 0, i16 0, i16 0, i16 3, i16 3, i16 3, i16 63, i16 63, i16 0, i16 0, i16 0, i16 192, i16 192, i16 12480, i16 248, i16 248, i16 63, i16 3075, i16 3075, i16 3, i16 0, i16 0, i16 0, i16 0, i16 1784, i16 16064, i16 16064, i16 12480, i16 -4096, i16 -4096, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 15, i16 286, i16 828, i16 0, i16 0, i16 192, i16 192, i16 12480, i16 28800, i16 -4096, i16 -8192, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 63, i16 63, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 248, i16 248, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 0, i16 0, i16 0, i16 1784, i16 -512, i16 -512, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 192, i16 192, i16 12480, i16 -4096, i16 -4096, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 1, i16 3, i16 7, i16 14, i16 284, i16 824, i16 1904, i16 3808, i16 7360, i16 14464, i16 7, i16 14, i16 284, i16 824, i16 1904, i16 3808, i16 7168, i16 14336, i16 28672, i16 -8192, i16 -16384, i16 -32768, i16 0, i16 0, i16 0, i16 0, i16 15, i16 31, i16 318, i16 828, i16 828, i16 828, i16 828, i16 828, i16 252, i16 254, i16 -8161, i16 -4081, i16 -32753, i16 15, i16 15, i16 15, i16 828, i16 828, i16 828, i16 318, i16 31, i16 15, i16 1792, i16 768, i16 15, i16 15, i16 15, i16 31, i16 510, i16 1020, i16 -256, i16 -256, i16 1, i16 3, i16 15, i16 15, i16 513, i16 513, i16 1, i16 1, i16 240, i16 240, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 1, i16 1, i16 1, i16 1, i16 1, i16 1, i16 0, i16 0, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 31744, i16 31744, i16 15, i16 31, i16 318, i16 828, i16 3840, i16 3840, i16 3, i16 15, i16 252, i16 254, i16 -8161, i16 -4081, i16 -32753, i16 63, i16 510, i16 4080, i16 31, i16 318, i16 318, i16 318, i16 63, i16 63, i16 3840, i16 3840, i16 32640, i16 -1024, i16 -8192, i16 -32768, i16 255, i16 255, i16 -256, i16 -256, i16 15, i16 63, i16 824, i16 3840, i16 2055, i16 7, i16 256, i16 256, i16 252, i16 254, i16 -8161, i16 -4081, i16 510, i16 1020, i16 -7906, i16 -4081, i16 0, i16 0, i16 56, i16 60, i16 63, i16 31, i16 3840, i16 1792, i16 15, i16 15, i16 15, i16 31, i16 510, i16 1020, i16 -256, i16 -256, i16 0, i16 0, i16 0, i16 1, i16 3, i16 7, i16 15, i16 286, i16 62, i16 126, i16 510, i16 510, i16 8670, i16 24990, i16 -7906, i16 -7906, i16 828, i16 828, i16 63, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 -16098, i16 -32482, i16 255, i16 255, i16 -7906, i16 -7906, i16 1792, i16 1792, i16 31, i16 63, i16 828, i16 828, i16 63, i16 31, i16 3840, i16 1792, i16 254, i16 254, i16 -256, i16 -256, i16 252, i16 254, i16 -8161, i16 -4081, i16 0, i16 0, i16 60, i16 62, i16 31, i16 15, i16 1792, i16 768, i16 15, i16 15, i16 15, i16 31, i16 510, i16 1020, i16 -256, i16 -256, i16 15, i16 31, i16 318, i16 828, i16 63, i16 63, i16 318, i16 828, i16 254, i16 255, i16 -2041, i16 -256, i16 508, i16 254, i16 -4081, i16 -2041, i16 828, i16 828, i16 828, i16 318, i16 31, i16 15, i16 1792, i16 768, i16 -32761, i16 7, i16 7, i16 15, i16 510, i16 1020, i16 -256, i16 -256, i16 63, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 0, i16 0, i16 255, i16 255, i16 -4081, i16 -4081, i16 15, i16 31, i16 318, i16 892, i16 0, i16 1, i16 3, i16 7, i16 7, i16 7, i16 256, i16 256, i16 2040, i16 4080, i16 7904, i16 15552, i16 30848, i16 28800, i16 -8192, i16 -8192, i16 15, i16 31, i16 828, i16 828, i16 828, i16 31, i16 15, i16 796, i16 252, i16 254, i16 -4081, i16 -4081, i16 15, i16 510, i16 1020, i16 -3826, i16 828, i16 828, i16 828, i16 828, i16 31, i16 15, i16 1792, i16 768, i16 -4081, i16 15, i16 15, i16 15, i16 510, i16 1020, i16 -256, i16 -256, i16 15, i16 31, i16 318, i16 828, i16 828, i16 828, i16 828, i16 318, i16 252, i16 254, i16 -8161, i16 -4081, i16 -32753, i16 15, i16 15, i16 31, i16 31, i16 15, i16 1792, i16 768, i16 0, i16 0, i16 0, i16 0, i16 255, i16 255, i16 -4081, i16 -4081, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 0, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 0, i16 0, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 0, i16 15, i16 15, i16 15, i16 270, i16 796, i16 824, i16 1792, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 -32768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 3, i16 15, i16 60, i16 828, i16 0, i16 0, i16 60, i16 240, i16 4032, i16 15360, i16 -4096, i16 -16384, i16 15, i16 3075, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 192, i16 240, i16 -16324, i16 15360, i16 3840, i16 0, i16 0, i16 0, i16 0, i16 0, i16 63, i16 63, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 0, i16 240, i16 240, i16 3312, i16 -1024, i16 -1024, i16 63, i16 63, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 0, i16 240, i16 240, i16 3312, i16 -1024, i16 -1024, i16 0, i16 0, i16 0, i16 0, i16 0, i16 60, i16 15, i16 3075, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 192, i16 240, i16 -16324, i16 60, i16 0, i16 3, i16 15, i16 60, i16 768, i16 3840, i16 0, i16 0, i16 4080, i16 4032, i16 15360, i16 -4096, i16 -16384, i16 0, i16 0, i16 0, i16 31, i16 63, i16 828, i16 3840, i16 3840, i16 7, i16 7, i16 7, i16 240, i16 248, i16 -32644, i16 -32132, i16 2040, i16 4080, i16 16064, i16 31872, i16 256, i16 256, i16 7, i16 7, i16 7, i16 256, i16 256, i16 0, i16 -4096, i16 -8192, i16 128, i16 128, i16 24704, i16 -8192, i16 -8192, i16 0, i16 31, i16 63, i16 828, i16 573, i16 573, i16 573, i16 573, i16 573, i16 248, i16 252, i16 -15812, i16 4590, i16 494, i16 4590, i16 1020, i16 1016, i16 828, i16 63, i16 31, i16 3840, i16 1792, i16 0, i16 0, i16 0, i16 32512, i16 764, i16 248, i16 -256, i16 -512, i16 0, i16 0, i16 0, i16 15, i16 31, i16 318, i16 892, i16 1020, i16 1020, i16 255, i16 255, i16 224, i16 240, i16 -32648, i16 -16324, i16 -32196, i16 828, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 -15556, i16 -15556, i16 828, i16 828, i16 828, i16 828, i16 3840, i16 3840, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 240, i16 248, i16 -16324, i16 -7652, i16 796, i16 1848, i16 2032, i16 1784, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 -16324, i16 -7652, i16 796, i16 828, i16 2040, i16 4080, i16 -512, i16 -1024, i16 63, i16 127, i16 510, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 240, i16 248, i16 -16324, i16 -7652, i16 -28928, i16 1792, i16 0, i16 0, i16 1020, i16 1020, i16 1020, i16 510, i16 127, i16 63, i16 7936, i16 3840, i16 0, i16 0, i16 28, i16 60, i16 2040, i16 4080, i16 -512, i16 -1024, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 240, i16 248, i16 -16324, i16 -7652, i16 796, i16 796, i16 796, i16 796, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 796, i16 796, i16 796, i16 828, i16 2040, i16 4080, i16 -512, i16 -1024, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 252, i16 252, i16 -256, i16 -256, i16 0, i16 0, i16 240, i16 240, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 -1024, i16 -1024, i16 0, i16 0, i16 252, i16 252, i16 -256, i16 -256, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 252, i16 252, i16 -256, i16 -256, i16 0, i16 0, i16 240, i16 240, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 -1024, i16 -1024, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 63, i16 127, i16 510, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 240, i16 248, i16 -8164, i16 -3572, i16 -30976, i16 768, i16 252, i16 252, i16 1020, i16 1020, i16 1020, i16 510, i16 127, i16 63, i16 7936, i16 3840, i16 8988, i16 8988, i16 796, i16 828, i16 2040, i16 4080, i16 -512, i16 -1024, i16 252, i16 252, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 60, i16 60, i16 828, i16 828, i16 828, i16 828, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 -15556, i16 -15556, i16 828, i16 828, i16 828, i16 828, i16 3840, i16 3840, i16 255, i16 255, i16 12303, i16 12303, i16 15, i16 15, i16 15, i16 15, i16 252, i16 252, i16 16320, i16 16320, i16 12480, i16 12480, i16 12480, i16 12480, i16 15, i16 15, i16 15, i16 15, i16 255, i16 255, i16 16128, i16 16128, i16 12480, i16 12480, i16 12480, i16 12480, i16 252, i16 252, i16 -256, i16 -256, i16 63, i16 63, i16 3075, i16 3075, i16 3, i16 3, i16 51, i16 51, i16 252, i16 252, i16 4080, i16 4080, i16 3312, i16 3312, i16 3312, i16 3312, i16 3123, i16 3123, i16 63, i16 63, i16 31, i16 15, i16 1792, i16 768, i16 3312, i16 3312, i16 3312, i16 3312, i16 7392, i16 15552, i16 -2048, i16 -4096, i16 252, i16 252, i16 1020, i16 1020, i16 765, i16 255, i16 255, i16 255, i16 28, i16 60, i16 1912, i16 4080, i16 7904, i16 15552, i16 30848, i16 12480, i16 255, i16 765, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 224, i16 240, i16 248, i16 124, i16 572, i16 828, i16 3840, i16 3840, i16 252, i16 252, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 0, i16 0, i16 0, i16 0, i16 252, i16 252, i16 -256, i16 -256, i16 248, i16 252, i16 254, i16 2295, i16 3315, i16 3315, i16 3315, i16 3315, i16 60, i16 124, i16 1020, i16 988, i16 9116, i16 25500, i16 25500, i16 25500, i16 3315, i16 3315, i16 3315, i16 3315, i16 3315, i16 3315, i16 15360, i16 15360, i16 25500, i16 25500, i16 25500, i16 25500, i16 25500, i16 25500, i16 -6400, i16 -6400, i16 240, i16 248, i16 252, i16 254, i16 255, i16 255, i16 2295, i16 3315, i16 60, i16 60, i16 828, i16 828, i16 828, i16 956, i16 1020, i16 1020, i16 3313, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 15360, i16 15360, i16 1020, i16 1020, i16 892, i16 828, i16 828, i16 828, i16 3840, i16 3840, i16 63, i16 127, i16 510, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 240, i16 248, i16 -16324, i16 -7652, i16 -31972, i16 796, i16 796, i16 796, i16 1020, i16 1020, i16 1020, i16 510, i16 127, i16 63, i16 7936, i16 3840, i16 796, i16 796, i16 796, i16 828, i16 2040, i16 4080, i16 -512, i16 -1024, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 240, i16 248, i16 -16324, i16 -7652, i16 796, i16 828, i16 2040, i16 4080, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 -512, i16 -1024, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 63, i16 127, i16 510, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 224, i16 240, i16 -32648, i16 -15304, i16 -31176, i16 1592, i16 1592, i16 1592, i16 765, i16 765, i16 1020, i16 510, i16 127, i16 63, i16 7936, i16 3840, i16 1784, i16 1784, i16 17976, i16 1656, i16 764, i16 764, i16 -256, i16 -256, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 240, i16 248, i16 -16324, i16 -7652, i16 796, i16 1848, i16 2032, i16 1784, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 -16324, i16 -7652, i16 796, i16 796, i16 796, i16 796, i16 1792, i16 1792, i16 63, i16 127, i16 2040, i16 4080, i16 1784, i16 255, i16 127, i16 63, i16 248, i16 252, i16 -15812, i16 -256, i16 3840, i16 240, i16 248, i16 252, i16 7936, i16 3840, i16 224, i16 255, i16 255, i16 127, i16 16128, i16 7936, i16 -32132, i16 -15556, i16 892, i16 1020, i16 2040, i16 4080, i16 -512, i16 -1024, i16 255, i16 255, i16 12303, i16 12303, i16 15, i16 15, i16 15, i16 15, i16 252, i16 252, i16 16320, i16 16320, i16 12480, i16 12480, i16 12480, i16 12480, i16 15, i16 15, i16 15, i16 15, i16 15, i16 15, i16 768, i16 768, i16 12480, i16 12480, i16 12480, i16 12480, i16 12480, i16 12480, i16 -4096, i16 -4096, i16 252, i16 252, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 28, i16 28, i16 796, i16 796, i16 796, i16 796, i16 796, i16 796, i16 1020, i16 1020, i16 510, i16 255, i16 127, i16 63, i16 7936, i16 3840, i16 796, i16 796, i16 828, i16 1020, i16 2040, i16 4080, i16 -512, i16 -1024, i16 248, i16 248, i16 1656, i16 1656, i16 1656, i16 1656, i16 1656, i16 1656, i16 124, i16 124, i16 1912, i16 1912, i16 1656, i16 1656, i16 1656, i16 1656, i16 1656, i16 572, i16 63, i16 31, i16 15, i16 7, i16 768, i16 256, i16 1656, i16 3824, i16 3824, i16 7392, i16 15552, i16 30848, i16 -4096, i16 -8192, i16 243, i16 243, i16 3315, i16 3315, i16 3315, i16 3315, i16 3315, i16 3315, i16 156, i16 156, i16 25500, i16 25500, i16 25500, i16 25500, i16 25500, i16 25500, i16 3315, i16 3315, i16 2295, i16 255, i16 510, i16 892, i16 16128, i16 7936, i16 25500, i16 25500, i16 9180, i16 1020, i16 1020, i16 -30856, i16 -16640, i16 7680, i16 240, i16 240, i16 1272, i16 124, i16 63, i16 31, i16 15, i16 15, i16 60, i16 60, i16 892, i16 2040, i16 4080, i16 7904, i16 15552, i16 14528, i16 31, i16 63, i16 892, i16 2040, i16 4080, i16 3824, i16 15360, i16 15360, i16 4320, i16 240, i16 248, i16 -32644, i16 572, i16 828, i16 3840, i16 3840, i16 240, i16 240, i16 1272, i16 124, i16 63, i16 31, i16 15, i16 7, i16 60, i16 60, i16 892, i16 2040, i16 4080, i16 7904, i16 15552, i16 30848, i16 7, i16 7, i16 7, i16 7, i16 7, i16 7, i16 256, i16 256, i16 28800, i16 24704, i16 24704, i16 24704, i16 24704, i16 24704, i16 -8192, i16 -8192, i16 127, i16 127, i16 127, i16 7936, i16 7936, i16 1, i16 3, i16 7, i16 252, i16 252, i16 1020, i16 -31876, i16 2040, i16 4080, i16 7904, i16 15552, i16 15, i16 31, i16 318, i16 127, i16 127, i16 127, i16 7936, i16 7936, i16 30848, i16 -4096, i16 -8192, i16 252, i16 252, i16 1020, i16 -256, i16 -256, i16 31, i16 31, i16 286, i16 286, i16 286, i16 286, i16 286, i16 286, i16 224, i16 224, i16 -2048, i16 -2048, i16 -32768, i16 -32768, i16 -32768, i16 -32768, i16 286, i16 286, i16 286, i16 31, i16 31, i16 1792, i16 1792, i16 0, i16 -32768, i16 -32768, i16 -32768, i16 224, i16 224, i16 -2048, i16 -2048, i16 0, i16 224, i16 112, i16 56, i16 28, i16 14, i16 7, i16 3, i16 1, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 128, i16 192, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 224, i16 112, i16 56, i16 28, i16 14, i16 7, i16 768, i16 256, i16 31, i16 31, i16 1792, i16 1792, i16 0, i16 0, i16 0, i16 0, i16 224, i16 224, i16 2288, i16 2288, i16 3312, i16 3312, i16 3312, i16 3312, i16 0, i16 0, i16 0, i16 31, i16 31, i16 1792, i16 1792, i16 0, i16 3312, i16 3312, i16 3312, i16 7392, i16 7392, i16 -2048, i16 -2048, i16 0, i16 3, i16 7, i16 14, i16 284, i16 824, i16 1840, i16 3584, i16 3072, i16 192, i16 224, i16 -32656, i16 -16328, i16 -32740, i16 524, i16 1792, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 127, i16 127, i16 7936, i16 0, i16 0, i16 0, i16 0, i16 0, i16 248, i16 248, i16 -512], align 1
@.str.2 = private unnamed_addr constant [6 x i8] c"%u+%u\00", align 1
@.str.3 = private unnamed_addr constant [6 x i8] c"%d/%u\00", align 1
@.str.4 = private unnamed_addr constant [6 x i8] c"%x %x\00", align 1
@.str.5 = private unnamed_addr constant [9 x i8] c"%u %d %x\00", align 1
@va_fmt_x.HEX = internal unnamed_addr constant [16 x i8] c"0123456789abcdef", align 1
@title_end._title_bg_black = internal constant i16 0, align 1
@.str.6 = private unnamed_addr constant [24 x i8] c"#32 VA ARG  FX=%u FY=%u\00", align 1
@.str.7 = private unnamed_addr constant [17 x i8] c"PAIR %u/%u  T=%u\00", align 1
@SPIRO_SIN_LUT = internal unnamed_addr constant [256 x i16] [i16 0, i16 6, i16 13, i16 19, i16 25, i16 31, i16 38, i16 44, i16 50, i16 56, i16 62, i16 68, i16 74, i16 80, i16 86, i16 92, i16 98, i16 104, i16 109, i16 115, i16 121, i16 126, i16 132, i16 137, i16 142, i16 147, i16 152, i16 157, i16 162, i16 167, i16 172, i16 177, i16 181, i16 185, i16 190, i16 194, i16 198, i16 202, i16 206, i16 209, i16 213, i16 216, i16 220, i16 223, i16 226, i16 229, i16 231, i16 234, i16 237, i16 239, i16 241, i16 243, i16 245, i16 247, i16 248, i16 250, i16 251, i16 252, i16 253, i16 254, i16 255, i16 255, i16 256, i16 256, i16 256, i16 256, i16 256, i16 255, i16 255, i16 254, i16 253, i16 252, i16 251, i16 250, i16 248, i16 247, i16 245, i16 243, i16 241, i16 239, i16 237, i16 234, i16 231, i16 229, i16 226, i16 223, i16 220, i16 216, i16 213, i16 209, i16 206, i16 202, i16 198, i16 194, i16 190, i16 185, i16 181, i16 177, i16 172, i16 167, i16 162, i16 157, i16 152, i16 147, i16 142, i16 137, i16 132, i16 126, i16 121, i16 115, i16 109, i16 104, i16 98, i16 92, i16 86, i16 80, i16 74, i16 68, i16 62, i16 56, i16 50, i16 44, i16 38, i16 31, i16 25, i16 19, i16 13, i16 6, i16 0, i16 -6, i16 -13, i16 -19, i16 -25, i16 -31, i16 -38, i16 -44, i16 -50, i16 -56, i16 -62, i16 -68, i16 -74, i16 -80, i16 -86, i16 -92, i16 -98, i16 -104, i16 -109, i16 -115, i16 -121, i16 -126, i16 -132, i16 -137, i16 -142, i16 -147, i16 -152, i16 -157, i16 -162, i16 -167, i16 -172, i16 -177, i16 -181, i16 -185, i16 -190, i16 -194, i16 -198, i16 -202, i16 -206, i16 -209, i16 -213, i16 -216, i16 -220, i16 -223, i16 -226, i16 -229, i16 -231, i16 -234, i16 -237, i16 -239, i16 -241, i16 -243, i16 -245, i16 -247, i16 -248, i16 -250, i16 -251, i16 -252, i16 -253, i16 -254, i16 -255, i16 -255, i16 -256, i16 -256, i16 -256, i16 -256, i16 -256, i16 -255, i16 -255, i16 -254, i16 -253, i16 -252, i16 -251, i16 -250, i16 -248, i16 -247, i16 -245, i16 -243, i16 -241, i16 -239, i16 -237, i16 -234, i16 -231, i16 -229, i16 -226, i16 -223, i16 -220, i16 -216, i16 -213, i16 -209, i16 -206, i16 -202, i16 -198, i16 -194, i16 -190, i16 -185, i16 -181, i16 -177, i16 -172, i16 -167, i16 -162, i16 -157, i16 -152, i16 -147, i16 -142, i16 -137, i16 -132, i16 -126, i16 -121, i16 -115, i16 -109, i16 -104, i16 -98, i16 -92, i16 -86, i16 -80, i16 -74, i16 -68, i16 -62, i16 -56, i16 -50, i16 -44, i16 -38, i16 -31, i16 -25, i16 -19, i16 -13, i16 -6], align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = alloca [32 x i8], align 1
  store volatile i8 -113, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  br label %2

2:                                                ; preds = %6, %0
  %3 = phi i16 [ 8449, %0 ], [ %7, %6 ]
  switch i16 %3, label %4 [
    i16 8452, label %6
    i16 8470, label %6
    i16 8471, label %6
    i16 8472, label %6
    i16 8473, label %6
    i16 8481, label %6
    i16 8482, label %6
  ]

4:                                                ; preds = %2
  %5 = inttoptr i16 %3 to ptr
  store volatile i8 0, ptr %5, align 1, !tbaa !6
  br label %6

6:                                                ; preds = %4, %2, %2, %2, %2, %2, %2, %2
  %7 = add nuw nsw i16 %3, 1
  %8 = icmp eq i16 %7, 8500
  br i1 %8, label %9, label %2, !llvm.loop !7

9:                                                ; preds = %6
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(6) getelementptr inbounds nuw (i8, ptr @main.a, i16 176), i8 0, i64 6, i1 false)
  store i32 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  store volatile i8 1, ptr inttoptr (i16 8453 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store volatile i8 -127, ptr inttoptr (i16 16896 to ptr), align 512, !tbaa !6
  store ptr @CANVAS_VT, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 196), align 1, !tbaa !15
  store i8 4, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 198), align 1, !tbaa !19
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4299), align 1, !tbaa !20
  store i16 16384, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4301), align 1, !tbaa !21
  store i8 8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4303), align 1, !tbaa !22
  store i8 6, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4304), align 1, !tbaa !23
  tail call void @llvm.memset.p0.i16(ptr noundef nonnull align 1 dereferenceable(4096) getelementptr inbounds nuw (i8, ptr @main.a, i16 199), i8 0, i16 4096, i1 false), !tbaa !6
  store i16 -1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4295), align 1, !tbaa !24
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4297), align 1, !tbaa !25
  store ptr @TEXT_VT, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4305), align 1, !tbaa !26
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4307), align 1, !tbaa !28
  store i16 16384, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4308), align 1, !tbaa !29
  store i8 2, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4310), align 1, !tbaa !6
  store i8 25, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4311), align 1, !tbaa !6
  br label %10

10:                                               ; preds = %10, %9
  %11 = phi i8 [ 0, %9 ], [ %17, %10 ]
  %12 = phi i16 [ 0, %9 ], [ %15, %10 ]
  %13 = zext i8 %11 to i16
  %14 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4312), i16 %13
  store i16 256, ptr %14, align 1, !tbaa !2
  %15 = add nuw nsw i16 %12, 1
  %16 = icmp eq i16 %15, 64
  %17 = add nuw i8 %11, 2
  br i1 %16, label %18, label %10, !llvm.loop !30

18:                                               ; preds = %10
  store i8 3, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4440), align 1, !tbaa !31
  %19 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  %20 = icmp eq i8 %19, 0
  br i1 %20, label %22, label %21

21:                                               ; preds = %18
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !33
  br label %22

22:                                               ; preds = %21, %18
  %23 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %24 = icmp ult i8 %23, 4
  br i1 %24, label %25, label %29

25:                                               ; preds = %22
  %26 = zext nneg i8 %23 to i16
  %27 = add nuw nsw i8 %23, 1
  store i8 %27, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %28 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %26
  store ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 196), ptr %28, align 1, !tbaa !35
  br label %29

29:                                               ; preds = %25, %22
  tail call void @_canvas_reserve(ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @main.a, i16 196), ptr nonnull poison) #15, !inline_history !37
  %30 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  %31 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 198), align 1, !tbaa !39
  %32 = or i8 %31, %30
  store i8 %32, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  store volatile i8 %32, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  %33 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  %34 = icmp eq i8 %33, 0
  br i1 %34, label %36, label %35

35:                                               ; preds = %29
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !33
  br label %36

36:                                               ; preds = %35, %29
  %37 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %38 = icmp ult i8 %37, 4
  br i1 %38, label %39, label %43

39:                                               ; preds = %36
  %40 = zext nneg i8 %37 to i16
  %41 = add nuw nsw i8 %37, 1
  store i8 %41, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %42 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %40
  store ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4305), ptr %42, align 1, !tbaa !35
  br label %43

43:                                               ; preds = %39, %36
  %44 = load ptr, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4305), align 1, !tbaa !40
  %45 = load ptr, ptr %44, align 1, !tbaa !41
  tail call void %45(ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @main.a, i16 4305), ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @main.a, i16 178)) #15, !inline_history !43
  %46 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  %47 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4307), align 1, !tbaa !39
  %48 = or i8 %47, %46
  store i8 %48, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  store volatile i8 %48, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  %49 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !44
  %50 = icmp ugt i8 %49, 15
  br i1 %50, label %62, label %51

51:                                               ; preds = %43
  %52 = zext nneg i8 %49 to i16
  %53 = add nuw nsw i8 %49, 1
  store i8 %53, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !44
  %54 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %52
  %55 = getelementptr inbounds nuw i8, ptr %54, i16 10
  store i8 1, ptr %55, align 1, !tbaa !45
  store i16 0, ptr %54, align 1, !tbaa !47
  %56 = getelementptr inbounds nuw i8, ptr %54, i16 9
  store i8 0, ptr %56, align 1, !tbaa !48
  %57 = getelementptr inbounds nuw i8, ptr %54, i16 7
  store i8 34, ptr %57, align 1, !tbaa !49
  %58 = getelementptr inbounds nuw i8, ptr %54, i16 8
  store i8 0, ptr %58, align 1, !tbaa !50
  %59 = getelementptr inbounds nuw i8, ptr %54, i16 2
  store i16 ptrtoint (ptr @bg3_pal to i16), ptr %59, align 1, !tbaa !51
  %60 = getelementptr inbounds nuw i8, ptr %54, i16 6
  store i8 0, ptr %60, align 1, !tbaa !52
  %61 = getelementptr inbounds nuw i8, ptr %54, i16 4
  store i16 8, ptr %61, align 1, !tbaa !53
  br label %62

62:                                               ; preds = %43, %51
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !54
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4442), align 1, !tbaa !56
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4444), align 1, !tbaa !57
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4450), align 1, !tbaa !58
  store ptr @TITLE_VT, ptr @main.title, align 1, !tbaa !59
  store i8 2, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !63
  store ptr @.str, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 3), align 1, !tbaa !64
  store ptr @.str.1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 5), align 1, !tbaa !65
  store ptr @.str.1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 7), align 1, !tbaa !66
  store i8 9, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 11), align 1, !tbaa !67
  store ptr null, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 9), align 1, !tbaa !68
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 12), align 1, !tbaa !69
  store i16 96, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 13), align 1, !tbaa !70
  store i16 112, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 15), align 1, !tbaa !71
  store i16 16, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 17), align 1, !tbaa !72
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 28), align 1, !tbaa !73
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 29), align 1, !tbaa !74
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !75
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 32), align 1, !tbaa !76
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !77
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !78
  store i16 32767, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 34), align 1, !tbaa !79
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 36), align 1, !tbaa !80
  %63 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  %64 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  %65 = icmp eq i8 %64, 0
  br i1 %65, label %67, label %66

66:                                               ; preds = %62
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !33
  br label %67

67:                                               ; preds = %66, %62
  %68 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %69 = icmp ult i8 %68, 4
  br i1 %69, label %70, label %74

70:                                               ; preds = %67
  %71 = zext nneg i8 %68 to i16
  %72 = add nuw nsw i8 %68, 1
  store i8 %72, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %73 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %71
  store ptr @main.title, ptr %73, align 1, !tbaa !35
  br label %74

74:                                               ; preds = %70, %67
  tail call void @_title_reserve(ptr noundef nonnull @main.title, ptr nonnull poison) #15, !inline_history !37
  %75 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  %76 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !39
  %77 = or i8 %76, %75
  store volatile i8 %77, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store i8 %63, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 33), align 1, !tbaa !81
  store i8 2, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  store volatile i8 2, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store volatile i8 24, ptr inttoptr (i16 16908 to ptr), align 4, !tbaa !6
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  br label %78

78:                                               ; preds = %106, %74
  %79 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %80 = icmp eq i8 %79, 0
  br i1 %80, label %92, label %81

81:                                               ; preds = %78, %81
  %82 = phi i8 [ %89, %81 ], [ 0, %78 ]
  %83 = zext i8 %82 to i16
  %84 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %83
  %85 = load ptr, ptr %84, align 1, !tbaa !35
  %86 = load ptr, ptr %85, align 1, !tbaa !40
  %87 = getelementptr inbounds nuw i8, ptr %86, i16 2
  %88 = load ptr, ptr %87, align 1, !tbaa !82
  tail call void %88(ptr noundef nonnull %85, ptr noundef nonnull @main.a) #15, !inline_history !83
  %89 = add nuw i8 %82, 1
  %90 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %91 = icmp ult i8 %89, %90
  br i1 %91, label %81, label %92, !llvm.loop !84

92:                                               ; preds = %81, %78
  %93 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %94

94:                                               ; preds = %94, %92
  %95 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %96 = icmp sgt i8 %95, -1
  br i1 %96, label %94, label %97, !llvm.loop !85

97:                                               ; preds = %94
  tail call fastcc void @upq_flush() #16
  %98 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %99 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %100 = icmp ult i8 %98, %99
  br i1 %100, label %103, label %101

101:                                              ; preds = %97
  %102 = icmp ugt i8 %98, %99
  br i1 %102, label %103, label %106

103:                                              ; preds = %101, %97
  %104 = phi i8 [ 1, %97 ], [ -1, %101 ]
  %105 = add i8 %104, %98
  store i8 %105, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %106

106:                                              ; preds = %103, %101
  %107 = phi i8 [ %98, %101 ], [ %105, %103 ]
  %108 = and i8 %107, 15
  store volatile i8 %108, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  %109 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %110 = icmp eq i8 %109, 15
  br i1 %110, label %111, label %78, !llvm.loop !86

111:                                              ; preds = %106
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !77
  %112 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !78
  %113 = icmp eq i8 %112, -1
  br i1 %113, label %151, label %114

114:                                              ; preds = %111, %143
  %115 = phi i8 [ %146, %143 ], [ 0, %111 ]
  %116 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %117 = icmp eq i8 %116, 0
  br i1 %117, label %129, label %118

118:                                              ; preds = %114, %118
  %119 = phi i8 [ %126, %118 ], [ 0, %114 ]
  %120 = zext i8 %119 to i16
  %121 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %120
  %122 = load ptr, ptr %121, align 1, !tbaa !35
  %123 = load ptr, ptr %122, align 1, !tbaa !40
  %124 = getelementptr inbounds nuw i8, ptr %123, i16 2
  %125 = load ptr, ptr %124, align 1, !tbaa !82
  tail call void %125(ptr noundef nonnull %122, ptr noundef nonnull @main.a) #15, !inline_history !87
  %126 = add nuw i8 %119, 1
  %127 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %128 = icmp ult i8 %126, %127
  br i1 %128, label %118, label %129, !llvm.loop !84

129:                                              ; preds = %118, %114
  %130 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %131

131:                                              ; preds = %131, %129
  %132 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %133 = icmp sgt i8 %132, -1
  br i1 %133, label %131, label %134, !llvm.loop !85

134:                                              ; preds = %131
  tail call fastcc void @upq_flush() #16
  %135 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %136 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %137 = icmp ult i8 %135, %136
  br i1 %137, label %140, label %138

138:                                              ; preds = %134
  %139 = icmp ugt i8 %135, %136
  br i1 %139, label %140, label %143

140:                                              ; preds = %138, %134
  %141 = phi i8 [ 1, %134 ], [ -1, %138 ]
  %142 = add i8 %141, %135
  store i8 %142, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %143

143:                                              ; preds = %140, %138
  %144 = phi i8 [ %135, %138 ], [ %142, %140 ]
  %145 = and i8 %144, 15
  store volatile i8 %145, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  %146 = add nuw i8 %115, 1
  %147 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !78
  %148 = icmp ne i8 %147, -1
  %149 = icmp ult i8 %115, -57
  %150 = select i1 %148, i1 %149, i1 false
  br i1 %150, label %114, label %151, !llvm.loop !88

151:                                              ; preds = %143, %111
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !77
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #17
  call void (ptr, ptr, ...) @mini_sprintf(ptr noundef %1, ptr noundef nonnull @.str.2, i16 noundef 123, i16 noundef 456) #16
  %152 = load i8, ptr %1, align 1, !tbaa !6
  %153 = icmp eq i8 %152, 0
  br i1 %153, label %154, label %158

154:                                              ; preds = %158, %151
  %155 = phi i16 [ 0, %151 ], [ %164, %158 ]
  call void (ptr, ptr, ...) @mini_sprintf(ptr noundef %1, ptr noundef nonnull @.str.3, i16 noundef -7, i16 noundef 3) #16
  %156 = load i8, ptr %1, align 1, !tbaa !6
  %157 = icmp eq i8 %156, 0
  br i1 %157, label %168, label %172

158:                                              ; preds = %151, %158
  %159 = phi i8 [ %166, %158 ], [ %152, %151 ]
  %160 = phi ptr [ %165, %158 ], [ %1, %151 ]
  %161 = phi i16 [ %164, %158 ], [ 0, %151 ]
  %162 = tail call i16 @llvm.fshl.i16(i16 %161, i16 %161, i16 1)
  %163 = zext i8 %159 to i16
  %164 = xor i16 %162, %163
  %165 = getelementptr inbounds nuw i8, ptr %160, i16 1
  %166 = load i8, ptr %165, align 1, !tbaa !6
  %167 = icmp eq i8 %166, 0
  br i1 %167, label %154, label %158, !llvm.loop !89

168:                                              ; preds = %172, %154
  %169 = phi i16 [ %155, %154 ], [ %178, %172 ]
  call void (ptr, ptr, ...) @mini_sprintf(ptr noundef %1, ptr noundef nonnull @.str.4, i16 noundef -16657, i16 noundef -13570) #16
  %170 = load i8, ptr %1, align 1, !tbaa !6
  %171 = icmp eq i8 %170, 0
  br i1 %171, label %182, label %186

172:                                              ; preds = %154, %172
  %173 = phi i8 [ %180, %172 ], [ %156, %154 ]
  %174 = phi ptr [ %179, %172 ], [ %1, %154 ]
  %175 = phi i16 [ %178, %172 ], [ %155, %154 ]
  %176 = tail call i16 @llvm.fshl.i16(i16 %175, i16 %175, i16 1)
  %177 = zext i8 %173 to i16
  %178 = xor i16 %176, %177
  %179 = getelementptr inbounds nuw i8, ptr %174, i16 1
  %180 = load i8, ptr %179, align 1, !tbaa !6
  %181 = icmp eq i8 %180, 0
  br i1 %181, label %168, label %172, !llvm.loop !90

182:                                              ; preds = %186, %168
  %183 = phi i16 [ %169, %168 ], [ %192, %186 ]
  call void (ptr, ptr, ...) @mini_sprintf(ptr noundef %1, ptr noundef nonnull @.str.5, i16 noundef 999, i16 noundef -1, i16 noundef -21555) #16
  %184 = load i8, ptr %1, align 1, !tbaa !6
  %185 = icmp eq i8 %184, 0
  br i1 %185, label %206, label %196

186:                                              ; preds = %168, %186
  %187 = phi i8 [ %194, %186 ], [ %170, %168 ]
  %188 = phi ptr [ %193, %186 ], [ %1, %168 ]
  %189 = phi i16 [ %192, %186 ], [ %169, %168 ]
  %190 = tail call i16 @llvm.fshl.i16(i16 %189, i16 %189, i16 1)
  %191 = zext i8 %187 to i16
  %192 = xor i16 %190, %191
  %193 = getelementptr inbounds nuw i8, ptr %188, i16 1
  %194 = load i8, ptr %193, align 1, !tbaa !6
  %195 = icmp eq i8 %194, 0
  br i1 %195, label %182, label %186, !llvm.loop !91

196:                                              ; preds = %182, %196
  %197 = phi i8 [ %204, %196 ], [ %184, %182 ]
  %198 = phi ptr [ %203, %196 ], [ %1, %182 ]
  %199 = phi i16 [ %202, %196 ], [ %183, %182 ]
  %200 = tail call i16 @llvm.fshl.i16(i16 %199, i16 %199, i16 1)
  %201 = zext i8 %197 to i16
  %202 = xor i16 %200, %201
  %203 = getelementptr inbounds nuw i8, ptr %198, i16 1
  %204 = load i8, ptr %203, align 1, !tbaa !6
  %205 = icmp eq i8 %204, 0
  br i1 %205, label %206, label %196, !llvm.loop !92

206:                                              ; preds = %196, %182
  %207 = phi i16 [ %183, %182 ], [ %202, %196 ]
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #17
  store volatile i16 %207, ptr @corpus_result, align 1, !tbaa !2
  br label %208

208:                                              ; preds = %238, %206
  %209 = phi i16 [ 90, %206 ], [ %210, %238 ]
  %210 = add nsw i16 %209, -1
  %211 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %212 = icmp eq i8 %211, 0
  br i1 %212, label %224, label %213

213:                                              ; preds = %208, %213
  %214 = phi i8 [ %221, %213 ], [ 0, %208 ]
  %215 = zext i8 %214 to i16
  %216 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %215
  %217 = load ptr, ptr %216, align 1, !tbaa !35
  %218 = load ptr, ptr %217, align 1, !tbaa !40
  %219 = getelementptr inbounds nuw i8, ptr %218, i16 2
  %220 = load ptr, ptr %219, align 1, !tbaa !82
  tail call void %220(ptr noundef nonnull %217, ptr noundef nonnull @main.a) #15, !inline_history !93
  %221 = add nuw i8 %214, 1
  %222 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %223 = icmp ult i8 %221, %222
  br i1 %223, label %213, label %224, !llvm.loop !84

224:                                              ; preds = %213, %208
  %225 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %226

226:                                              ; preds = %226, %224
  %227 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %228 = icmp sgt i8 %227, -1
  br i1 %228, label %226, label %229, !llvm.loop !85

229:                                              ; preds = %226
  tail call fastcc void @upq_flush() #16
  %230 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %231 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %232 = icmp ult i8 %230, %231
  br i1 %232, label %235, label %233

233:                                              ; preds = %229
  %234 = icmp ugt i8 %230, %231
  br i1 %234, label %235, label %238

235:                                              ; preds = %233, %229
  %236 = phi i8 [ 1, %229 ], [ -1, %233 ]
  %237 = add i8 %236, %230
  store i8 %237, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %238

238:                                              ; preds = %235, %233
  %239 = phi i8 [ %230, %233 ], [ %237, %235 ]
  %240 = and i8 %239, 15
  store volatile i8 %240, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  %241 = icmp eq i16 %210, 0
  br i1 %241, label %242, label %208, !llvm.loop !94

242:                                              ; preds = %238
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !75
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 32), align 1, !tbaa !76
  br label %246

243:                                              ; preds = %275
  %244 = add nuw nsw i8 %247, 1
  %245 = icmp eq i8 %244, 90
  br i1 %245, label %280, label %246, !llvm.loop !95

246:                                              ; preds = %243, %242
  %247 = phi i8 [ 0, %242 ], [ %244, %243 ]
  %248 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %249 = icmp eq i8 %248, 0
  br i1 %249, label %261, label %250

250:                                              ; preds = %246, %250
  %251 = phi i8 [ %258, %250 ], [ 0, %246 ]
  %252 = zext i8 %251 to i16
  %253 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %252
  %254 = load ptr, ptr %253, align 1, !tbaa !35
  %255 = load ptr, ptr %254, align 1, !tbaa !40
  %256 = getelementptr inbounds nuw i8, ptr %255, i16 2
  %257 = load ptr, ptr %256, align 1, !tbaa !82
  tail call void %257(ptr noundef nonnull %254, ptr noundef nonnull @main.a) #15, !inline_history !96
  %258 = add nuw i8 %251, 1
  %259 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %260 = icmp ult i8 %258, %259
  br i1 %260, label %250, label %261, !llvm.loop !84

261:                                              ; preds = %250, %246
  %262 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %263

263:                                              ; preds = %263, %261
  %264 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %265 = icmp sgt i8 %264, -1
  br i1 %265, label %263, label %266, !llvm.loop !85

266:                                              ; preds = %263
  tail call fastcc void @upq_flush() #16
  %267 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %268 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %269 = icmp ult i8 %267, %268
  br i1 %269, label %272, label %270

270:                                              ; preds = %266
  %271 = icmp ugt i8 %267, %268
  br i1 %271, label %272, label %275

272:                                              ; preds = %270, %266
  %273 = phi i8 [ 1, %266 ], [ -1, %270 ]
  %274 = add i8 %273, %267
  store i8 %274, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %275

275:                                              ; preds = %272, %270
  %276 = phi i8 [ %267, %270 ], [ %274, %272 ]
  %277 = and i8 %276, 15
  store volatile i8 %277, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  %278 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 19), align 1, !tbaa !97
  %279 = icmp sgt i16 %278, 3583
  br i1 %279, label %280, label %243

280:                                              ; preds = %275, %243
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !75
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %281 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %282 = icmp eq i8 %281, 0
  br i1 %282, label %316, label %283

283:                                              ; preds = %280, %311
  %284 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %285 = icmp eq i8 %284, 0
  br i1 %285, label %297, label %286

286:                                              ; preds = %283, %286
  %287 = phi i8 [ %294, %286 ], [ 0, %283 ]
  %288 = zext i8 %287 to i16
  %289 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %288
  %290 = load ptr, ptr %289, align 1, !tbaa !35
  %291 = load ptr, ptr %290, align 1, !tbaa !40
  %292 = getelementptr inbounds nuw i8, ptr %291, i16 2
  %293 = load ptr, ptr %292, align 1, !tbaa !82
  tail call void %293(ptr noundef nonnull %290, ptr noundef nonnull @main.a) #15, !inline_history !98
  %294 = add nuw i8 %287, 1
  %295 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %296 = icmp ult i8 %294, %295
  br i1 %296, label %286, label %297, !llvm.loop !84

297:                                              ; preds = %286, %283
  %298 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %299

299:                                              ; preds = %299, %297
  %300 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %301 = icmp sgt i8 %300, -1
  br i1 %301, label %299, label %302, !llvm.loop !85

302:                                              ; preds = %299
  tail call fastcc void @upq_flush() #16
  %303 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %304 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %305 = icmp ult i8 %303, %304
  br i1 %305, label %308, label %306

306:                                              ; preds = %302
  %307 = icmp ugt i8 %303, %304
  br i1 %307, label %308, label %311

308:                                              ; preds = %306, %302
  %309 = phi i8 [ 1, %302 ], [ -1, %306 ]
  %310 = add i8 %309, %303
  store i8 %310, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %311

311:                                              ; preds = %308, %306
  %312 = phi i8 [ %303, %306 ], [ %310, %308 ]
  %313 = and i8 %312, 15
  store volatile i8 %313, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  %314 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %315 = icmp eq i8 %314, 0
  br i1 %315, label %316, label %283, !llvm.loop !86

316:                                              ; preds = %311, %280
  %317 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 33), align 1, !tbaa !81
  %318 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  %319 = or i8 %318, %317
  %320 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !39
  %321 = xor i8 %320, -1
  %322 = and i8 %319, %321
  store i8 %322, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !38
  store volatile i8 %322, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 16908 to ptr), align 4, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8463 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8463 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 29), align 1, !tbaa !74
  %323 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !44
  %324 = icmp ugt i8 %323, 15
  br i1 %324, label %336, label %325

325:                                              ; preds = %316
  %326 = zext nneg i8 %323 to i16
  %327 = add nuw nsw i8 %323, 1
  store i8 %327, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !44
  %328 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %326
  %329 = getelementptr inbounds nuw i8, ptr %328, i16 10
  store i8 1, ptr %329, align 1, !tbaa !45
  store i16 0, ptr %328, align 1, !tbaa !47
  %330 = getelementptr inbounds nuw i8, ptr %328, i16 9
  store i8 0, ptr %330, align 1, !tbaa !48
  %331 = getelementptr inbounds nuw i8, ptr %328, i16 7
  store i8 34, ptr %331, align 1, !tbaa !49
  %332 = getelementptr inbounds nuw i8, ptr %328, i16 8
  store i8 0, ptr %332, align 1, !tbaa !50
  %333 = getelementptr inbounds nuw i8, ptr %328, i16 2
  store i16 ptrtoint (ptr @title_end._title_bg_black to i16), ptr %333, align 1, !tbaa !51
  %334 = getelementptr inbounds nuw i8, ptr %328, i16 6
  store i8 0, ptr %334, align 1, !tbaa !52
  %335 = getelementptr inbounds nuw i8, ptr %328, i16 4
  store i16 2, ptr %335, align 1, !tbaa !53
  br label %336

336:                                              ; preds = %316, %325
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  tail call fastcc void @hud_update() #16
  br label %337

337:                                              ; preds = %381, %336
  %338 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !54
  %339 = zext i8 %338 to i16
  %340 = getelementptr inbounds nuw i8, ptr @PAIRS_FX, i16 %339
  %341 = load i8, ptr %340, align 1, !tbaa !6
  %342 = getelementptr inbounds nuw i8, ptr @PAIRS_FY, i16 %339
  %343 = load i8, ptr %342, align 1, !tbaa !6
  tail call fastcc void @draw_pts(i8 noundef zeroext %341, i8 noundef zeroext %343) #16
  tail call fastcc void @hud_update() #16
  %344 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4444), align 1, !tbaa !57
  %345 = add i16 %344, 1
  store i16 %345, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4444), align 1, !tbaa !57
  %346 = icmp ugt i16 %345, 119
  br i1 %346, label %347, label %353

347:                                              ; preds = %337
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(4098) getelementptr inbounds nuw (i8, ptr @main.a, i16 199), i8 0, i64 4098, i1 false)
  store i16 255, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4297), align 1, !tbaa !25
  %348 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !54
  %349 = zext i8 %348 to i16
  %350 = add nuw nsw i16 %349, 1
  %351 = urem i16 %350, 6
  %352 = trunc nuw nsw i16 %351 to i8
  store i8 %352, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !54
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4444), align 1, !tbaa !57
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4442), align 1, !tbaa !56
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4450), align 1, !tbaa !58
  br label %353

353:                                              ; preds = %347, %337
  %354 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %355 = icmp eq i8 %354, 0
  br i1 %355, label %367, label %356

356:                                              ; preds = %353, %356
  %357 = phi i8 [ %364, %356 ], [ 0, %353 ]
  %358 = zext i8 %357 to i16
  %359 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %358
  %360 = load ptr, ptr %359, align 1, !tbaa !35
  %361 = load ptr, ptr %360, align 1, !tbaa !40
  %362 = getelementptr inbounds nuw i8, ptr %361, i16 2
  %363 = load ptr, ptr %362, align 1, !tbaa !82
  tail call void %363(ptr noundef nonnull %360, ptr noundef nonnull @main.a) #15, !inline_history !99
  %364 = add nuw i8 %357, 1
  %365 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !34
  %366 = icmp ult i8 %364, %365
  br i1 %366, label %356, label %367, !llvm.loop !84

367:                                              ; preds = %356, %353
  %368 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %369

369:                                              ; preds = %369, %367
  %370 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %371 = icmp sgt i8 %370, -1
  br i1 %371, label %369, label %372, !llvm.loop !85

372:                                              ; preds = %369
  tail call fastcc void @upq_flush() #16
  %373 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %374 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %375 = icmp ult i8 %373, %374
  br i1 %375, label %378, label %376

376:                                              ; preds = %372
  %377 = icmp ugt i8 %373, %374
  br i1 %377, label %378, label %381

378:                                              ; preds = %376, %372
  %379 = phi i8 [ 1, %372 ], [ -1, %376 ]
  %380 = add i8 %379, %373
  store i8 %380, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %381

381:                                              ; preds = %376, %378
  %382 = phi i8 [ %373, %376 ], [ %380, %378 ]
  %383 = and i8 %382, 15
  store volatile i8 %383, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !32
  br label %337
}

; Function Attrs: nofree norecurse nosync nounwind optsize
define internal fastcc void @hud_update() unnamed_addr #1 {
  %1 = alloca [32 x i8], align 1
  %2 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !54
  %3 = zext i8 %2 to i16
  %4 = getelementptr inbounds nuw i8, ptr @PAIRS_FX, i16 %3
  %5 = load i8, ptr %4, align 1, !tbaa !6
  %6 = getelementptr inbounds nuw i8, ptr @PAIRS_FY, i16 %3
  %7 = load i8, ptr %6, align 1, !tbaa !6
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #17
  %8 = zext i8 %5 to i16
  %9 = zext i8 %7 to i16
  call void (ptr, ptr, ...) @mini_sprintf(ptr noundef %1, ptr noundef nonnull @.str.6, i16 noundef %8, i16 noundef %9) #16
  br label %10

10:                                               ; preds = %10, %0
  %11 = phi i8 [ 0, %0 ], [ %17, %10 ]
  %12 = phi i8 [ 0, %0 ], [ %15, %10 ]
  %13 = zext nneg i8 %11 to i16
  %14 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4312), i16 %13
  store i16 256, ptr %14, align 1, !tbaa !2
  %15 = add nuw nsw i8 %12, 1
  %16 = icmp eq i8 %15, 32
  %17 = add nuw nsw i8 %11, 2
  br i1 %16, label %18, label %10, !llvm.loop !100

18:                                               ; preds = %10
  %19 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4440), align 1, !tbaa !31
  %20 = or i8 %19, 1
  %21 = load i8, ptr %1, align 1, !tbaa !6
  %22 = icmp eq i8 %21, 0
  br i1 %22, label %47, label %23

23:                                               ; preds = %18
  %24 = getelementptr inbounds nuw i8, ptr %1, i16 1
  br label %29

25:                                               ; preds = %39
  %26 = add nuw nsw i8 %30, 1
  %27 = add nuw nsw i8 %32, 2
  %28 = icmp eq i8 %26, 32
  br i1 %28, label %47, label %29, !llvm.loop !101

29:                                               ; preds = %23, %25
  %30 = phi i8 [ 0, %23 ], [ %26, %25 ]
  %31 = phi i8 [ %21, %23 ], [ %45, %25 ]
  %32 = phi i8 [ 0, %23 ], [ %27, %25 ]
  %33 = zext i8 %31 to i16
  %34 = icmp ugt i8 %31, 31
  br i1 %34, label %35, label %39

35:                                               ; preds = %29
  %36 = icmp ult i8 %31, 96
  br i1 %36, label %37, label %39

37:                                               ; preds = %35
  %38 = add nuw nsw i16 %33, 224
  br label %39

39:                                               ; preds = %37, %35, %29
  %40 = phi i16 [ %38, %37 ], [ 256, %35 ], [ 256, %29 ]
  %41 = zext nneg i8 %32 to i16
  %42 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4312), i16 %41
  store i16 %40, ptr %42, align 1, !tbaa !2
  %43 = zext nneg i8 %30 to i16
  %44 = getelementptr i8, ptr %24, i16 %43
  %45 = load i8, ptr %44, align 1, !tbaa !6
  %46 = icmp eq i8 %45, 0
  br i1 %46, label %47, label %25, !llvm.loop !101

47:                                               ; preds = %25, %39, %18
  store i8 %20, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4440), align 1, !tbaa !31
  %48 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4441), align 1, !tbaa !54
  %49 = zext i8 %48 to i16
  %50 = add nuw nsw i16 %49, 1
  %51 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4442), align 1, !tbaa !56
  call void (ptr, ptr, ...) @mini_sprintf(ptr noundef %1, ptr noundef nonnull @.str.7, i16 noundef %50, i16 noundef 6, i16 noundef %51) #16
  br label %52

52:                                               ; preds = %52, %47
  %53 = phi i8 [ 0, %47 ], [ %59, %52 ]
  %54 = phi i8 [ 0, %47 ], [ %57, %52 ]
  %55 = zext nneg i8 %53 to i16
  %56 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4376), i16 %55
  store i16 256, ptr %56, align 1, !tbaa !2
  %57 = add nuw nsw i8 %54, 1
  %58 = icmp eq i8 %57, 32
  %59 = add nuw nsw i8 %53, 2
  br i1 %58, label %60, label %52, !llvm.loop !100

60:                                               ; preds = %52
  %61 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4440), align 1, !tbaa !31
  %62 = load i8, ptr %1, align 1, !tbaa !6
  %63 = icmp eq i8 %62, 0
  br i1 %63, label %88, label %64

64:                                               ; preds = %60
  %65 = getelementptr inbounds nuw i8, ptr %1, i16 1
  br label %70

66:                                               ; preds = %80
  %67 = add nuw nsw i8 %71, 1
  %68 = add nuw nsw i8 %73, 2
  %69 = icmp eq i8 %67, 32
  br i1 %69, label %88, label %70, !llvm.loop !101

70:                                               ; preds = %64, %66
  %71 = phi i8 [ 0, %64 ], [ %67, %66 ]
  %72 = phi i8 [ %62, %64 ], [ %86, %66 ]
  %73 = phi i8 [ 0, %64 ], [ %68, %66 ]
  %74 = zext i8 %72 to i16
  %75 = icmp ugt i8 %72, 31
  br i1 %75, label %76, label %80

76:                                               ; preds = %70
  %77 = icmp ult i8 %72, 96
  br i1 %77, label %78, label %80

78:                                               ; preds = %76
  %79 = add nuw nsw i16 %74, 224
  br label %80

80:                                               ; preds = %78, %76, %70
  %81 = phi i16 [ %79, %78 ], [ 256, %76 ], [ 256, %70 ]
  %82 = zext nneg i8 %73 to i16
  %83 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4376), i16 %82
  store i16 %81, ptr %83, align 1, !tbaa !2
  %84 = zext nneg i8 %71 to i16
  %85 = getelementptr i8, ptr %65, i16 %84
  %86 = load i8, ptr %85, align 1, !tbaa !6
  %87 = icmp eq i8 %86, 0
  br i1 %87, label %88, label %66, !llvm.loop !101

88:                                               ; preds = %66, %80, %60
  %89 = or i8 %61, 2
  store i8 %89, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4440), align 1, !tbaa !31
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #17
  ret void
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #2

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @draw_pts(i8 noundef zeroext %0, i8 noundef zeroext %1) unnamed_addr #3 {
  %3 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4442), align 1, !tbaa !56
  %4 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4450), align 1, !tbaa !58
  %5 = trunc i16 %3 to i8
  %6 = icmp eq i8 %4, 0
  br label %8

7:                                                ; preds = %67
  ret void

8:                                                ; preds = %2, %67
  %9 = phi i1 [ %6, %2 ], [ false, %67 ]
  %10 = phi i8 [ %5, %2 ], [ %71, %67 ]
  %11 = phi i16 [ 0, %2 ], [ %69, %67 ]
  %12 = mul i8 %0, %10
  %13 = add i8 %12, 64
  %14 = zext i8 %13 to i16
  %15 = getelementptr inbounds nuw [2 x i8], ptr @SPIRO_SIN_LUT, i16 %14
  %16 = load i16, ptr %15, align 1, !tbaa !2
  %17 = sext i16 %16 to i32
  %18 = mul nsw i32 %17, 56
  %19 = lshr i32 %18, 8
  %20 = trunc i32 %19 to i16
  %21 = add nsw i16 %20, 64
  %22 = mul i8 %1, %10
  %23 = zext i8 %22 to i16
  %24 = getelementptr inbounds nuw [2 x i8], ptr @SPIRO_SIN_LUT, i16 %23
  %25 = load i16, ptr %24, align 1, !tbaa !2
  %26 = sext i16 %25 to i32
  %27 = mul nsw i32 %26, 56
  %28 = lshr i32 %27, 8
  %29 = trunc i32 %28 to i16
  %30 = sub nsw i16 64, %29
  br i1 %9, label %34, label %31

31:                                               ; preds = %8
  %32 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4446), align 1, !tbaa !102
  %33 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4448), align 1, !tbaa !103
  tail call fastcc void @canvas_line(i16 noundef %32, i16 noundef %33, i16 noundef %21, i16 noundef %30) #16
  br label %34

34:                                               ; preds = %31, %8
  %35 = icmp ugt i16 %21, 127
  br i1 %35, label %62, label %36

36:                                               ; preds = %34
  %37 = icmp ugt i16 %30, 127
  br i1 %37, label %62, label %38

38:                                               ; preds = %36
  %39 = shl nuw nsw i16 %30, 1
  %40 = and i16 %39, 240
  %41 = lshr i16 %21, 3
  %42 = or disjoint i16 %40, %41
  %43 = shl nuw nsw i16 %42, 4
  %44 = and i16 %39, 14
  %45 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 199), i16 %43
  %46 = getelementptr inbounds nuw i8, ptr %45, i16 %44
  %47 = and i16 %20, 7
  %48 = lshr exact i16 128, %47
  %49 = load i8, ptr %46, align 1, !tbaa !6
  %50 = trunc nuw i16 %48 to i8
  %51 = or i8 %49, %50
  store i8 %51, ptr %46, align 1, !tbaa !6
  %52 = getelementptr inbounds nuw i8, ptr %46, i16 1
  %53 = load i8, ptr %52, align 1, !tbaa !6
  %54 = or i8 %53, %50
  store i8 %54, ptr %52, align 1, !tbaa !6
  %55 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4295), align 1, !tbaa !24
  %56 = icmp ult i16 %42, %55
  br i1 %56, label %57, label %58

57:                                               ; preds = %38
  store i16 %42, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4295), align 1, !tbaa !24
  br label %58

58:                                               ; preds = %57, %38
  %59 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4297), align 1, !tbaa !25
  %60 = icmp ugt i16 %42, %59
  br i1 %60, label %61, label %62

61:                                               ; preds = %58
  store i16 %42, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4297), align 1, !tbaa !25
  br label %62

62:                                               ; preds = %34, %36, %58, %61
  store i16 %21, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4446), align 1, !tbaa !102
  store i16 %30, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4448), align 1, !tbaa !103
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4450), align 1, !tbaa !58
  %63 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4442), align 1, !tbaa !56
  %64 = add i16 %63, 1
  %65 = icmp ugt i16 %64, 255
  br i1 %65, label %66, label %67

66:                                               ; preds = %62
  br label %67

67:                                               ; preds = %66, %62
  %68 = phi i16 [ 0, %66 ], [ %64, %62 ]
  store i16 %68, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4442), align 1, !tbaa !56
  %69 = add nuw nsw i16 %11, 1
  %70 = icmp eq i16 %69, 6
  %71 = trunc nuw i16 %68 to i8
  br i1 %70, label %7, label %8, !llvm.loop !104
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #2

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal void @_canvas_reserve(ptr noundef readonly captures(none) %0, ptr readnone captures(none) %1) #4 {
  %3 = getelementptr inbounds nuw i8, ptr %0, i16 4105
  %4 = load i16, ptr %3, align 1, !tbaa !21
  %5 = lshr i16 %4, 8
  %6 = trunc nuw i16 %5 to i8
  %7 = and i8 %6, -4
  store volatile i8 %7, ptr inttoptr (i16 8457 to ptr), align 1, !tbaa !6
  %8 = getelementptr inbounds nuw i8, ptr %0, i16 4103
  %9 = load i16, ptr %8, align 1, !tbaa !20
  %10 = lshr i16 %9, 12
  %11 = trunc nuw nsw i16 %10 to i8
  store volatile i8 %11, ptr inttoptr (i16 8460 to ptr), align 4, !tbaa !6
  %12 = load i16, ptr %8, align 1, !tbaa !20
  %13 = lshr i16 %12, 3
  %14 = add nuw nsw i16 %13, 256
  %15 = load i16, ptr %3, align 1, !tbaa !21
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 %15, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  %16 = getelementptr inbounds nuw i8, ptr %0, i16 4107
  %17 = load i8, ptr %16, align 1, !tbaa !22
  %18 = getelementptr inbounds nuw i8, ptr %0, i16 4108
  br label %19

19:                                               ; preds = %2, %23
  %20 = phi i8 [ 0, %2 ], [ %24, %23 ]
  br label %26

21:                                               ; preds = %23
  %22 = load i16, ptr %8, align 1, !tbaa !20
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 %22, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %45

23:                                               ; preds = %40
  %24 = add nuw nsw i8 %20, 1
  %25 = icmp eq i8 %24, 32
  br i1 %25, label %21, label %19, !llvm.loop !105

26:                                               ; preds = %19, %40
  %27 = phi i8 [ 0, %19 ], [ %42, %40 ]
  %28 = sub i8 %27, %17
  %29 = zext i8 %28 to i16
  %30 = icmp ult i8 %28, 16
  br i1 %30, label %31, label %40

31:                                               ; preds = %26
  %32 = load i8, ptr %18, align 1, !tbaa !23
  %33 = sub i8 %20, %32
  %34 = icmp ult i8 %33, 16
  br i1 %34, label %35, label %40

35:                                               ; preds = %31
  %36 = shl nuw i8 %33, 4
  %37 = zext i8 %36 to i16
  %38 = add nuw nsw i16 %13, %29
  %39 = add nuw nsw i16 %38, %37
  br label %40

40:                                               ; preds = %26, %31, %35
  %41 = phi i16 [ %39, %35 ], [ %14, %31 ], [ %14, %26 ]
  store volatile i16 %41, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %42 = add nuw nsw i8 %27, 1
  %43 = icmp eq i8 %42, 32
  br i1 %43, label %23, label %26, !llvm.loop !106

44:                                               ; preds = %45
  ret void

45:                                               ; preds = %21, %45
  %46 = phi i16 [ 0, %21 ], [ %47, %45 ]
  store volatile i16 0, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %47 = add nuw nsw i16 %46, 1
  %48 = icmp eq i16 %47, 2056
  br i1 %48, label %44, label %45, !llvm.loop !107
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: readwrite)
define internal void @_canvas_emit(ptr noundef %0, ptr noundef captures(none) %1) #5 {
  %3 = getelementptr inbounds nuw i8, ptr %0, i16 4099
  %4 = load i16, ptr %3, align 1, !tbaa !24
  %5 = getelementptr inbounds nuw i8, ptr %0, i16 4101
  %6 = load i16, ptr %5, align 1, !tbaa !25
  %7 = icmp ugt i16 %4, %6
  br i1 %7, label %48, label %8

8:                                                ; preds = %2
  %9 = sub nuw i16 %6, %4
  %10 = add i16 %9, -64
  %11 = icmp ult i16 %10, -65
  br i1 %11, label %12, label %14

12:                                               ; preds = %8
  %13 = add i16 %4, 63
  br label %14

14:                                               ; preds = %12, %8
  %15 = phi i16 [ 63, %12 ], [ %9, %8 ]
  %16 = phi i16 [ %13, %12 ], [ %6, %8 ]
  %17 = getelementptr inbounds nuw i8, ptr %0, i16 4103
  %18 = load i16, ptr %17, align 1, !tbaa !20
  %19 = shl i16 %4, 3
  %20 = add i16 %18, %19
  %21 = getelementptr inbounds nuw i8, ptr %0, i16 3
  %22 = shl i16 %4, 4
  %23 = getelementptr inbounds nuw i8, ptr %21, i16 %22
  %24 = shl nsw i16 %15, 4
  %25 = add nsw i16 %24, 16
  %26 = icmp eq i16 %25, 0
  br i1 %26, label %43, label %27

27:                                               ; preds = %14
  %28 = getelementptr inbounds nuw i8, ptr %1, i16 176
  %29 = load i8, ptr %28, align 1, !tbaa !44
  %30 = icmp ugt i8 %29, 15
  br i1 %30, label %43, label %31

31:                                               ; preds = %27
  %32 = zext nneg i8 %29 to i16
  %33 = add nuw nsw i8 %29, 1
  store i8 %33, ptr %28, align 1, !tbaa !44
  %34 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %32
  %35 = getelementptr inbounds nuw i8, ptr %34, i16 10
  store i8 0, ptr %35, align 1, !tbaa !45
  store i16 %20, ptr %34, align 1, !tbaa !47
  %36 = getelementptr inbounds nuw i8, ptr %34, i16 9
  store i8 -128, ptr %36, align 1, !tbaa !48
  %37 = getelementptr inbounds nuw i8, ptr %34, i16 7
  store i8 24, ptr %37, align 1, !tbaa !49
  %38 = getelementptr inbounds nuw i8, ptr %34, i16 8
  store i8 1, ptr %38, align 1, !tbaa !50
  %39 = ptrtoint ptr %23 to i16
  %40 = getelementptr inbounds nuw i8, ptr %34, i16 2
  store i16 %39, ptr %40, align 1, !tbaa !51
  %41 = getelementptr inbounds nuw i8, ptr %34, i16 6
  store i8 0, ptr %41, align 1, !tbaa !52
  %42 = getelementptr inbounds nuw i8, ptr %34, i16 4
  store i16 %25, ptr %42, align 1, !tbaa !53
  br label %43

43:                                               ; preds = %14, %27, %31
  %44 = icmp ult i16 %16, %6
  br i1 %44, label %46, label %45

45:                                               ; preds = %43
  store i16 -1, ptr %3, align 1, !tbaa !24
  store i16 0, ptr %5, align 1, !tbaa !25
  br label %48

46:                                               ; preds = %43
  %47 = add nuw i16 %16, 1
  store i16 %47, ptr %3, align 1, !tbaa !24
  br label %48

48:                                               ; preds = %45, %46, %2
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal void @_text_reserve(ptr readnone captures(none) %0, ptr readnone captures(none) %1) #4 {
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 2048, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %4

3:                                                ; preds = %4
  ret void

4:                                                ; preds = %2, %4
  %5 = phi i16 [ 0, %2 ], [ %8, %4 ]
  %6 = getelementptr inbounds nuw [2 x i8], ptr @FONT8, i16 %5
  %7 = load i16, ptr %6, align 1, !tbaa !2
  store volatile i16 %7, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %8 = add nuw nsw i16 %5, 1
  %9 = icmp eq i16 %8, 512
  br i1 %9, label %3, label %4, !llvm.loop !108
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(argmem: readwrite)
define internal void @_text_emit(ptr noundef %0, ptr noundef captures(none) %1) #6 {
  %3 = getelementptr inbounds nuw i8, ptr %0, i16 135
  %4 = load i8, ptr %3, align 1, !tbaa !31
  %5 = zext i8 %4 to i16
  %6 = getelementptr inbounds nuw i8, ptr %1, i16 176
  %7 = getelementptr i8, ptr %0, i16 7
  %8 = getelementptr inbounds nuw i8, ptr %0, i16 3
  %9 = getelementptr i8, ptr %0, i16 5
  br label %11

10:                                               ; preds = %42
  store i8 0, ptr %3, align 1, !tbaa !31
  ret void

11:                                               ; preds = %2, %42
  %12 = phi i8 [ 0, %2 ], [ %43, %42 ]
  %13 = phi i1 [ true, %2 ], [ false, %42 ]
  %14 = phi i8 [ 0, %2 ], [ 1, %42 ]
  %15 = zext nneg i8 %14 to i16
  %16 = shl nuw nsw i16 1, %15
  %17 = and i16 %16, %5
  %18 = icmp eq i16 %17, 0
  br i1 %18, label %42, label %19

19:                                               ; preds = %11
  %20 = load i8, ptr %6, align 1, !tbaa !44
  %21 = icmp ugt i8 %20, 15
  br i1 %21, label %42, label %22

22:                                               ; preds = %19
  %23 = zext i8 %12 to i16
  %24 = getelementptr i8, ptr %7, i16 %23
  %25 = load i16, ptr %8, align 1, !tbaa !29
  %26 = getelementptr i8, ptr %9, i16 %15
  %27 = load i8, ptr %26, align 1, !tbaa !6
  %28 = zext i8 %27 to i16
  %29 = shl nuw nsw i16 %28, 5
  %30 = add i16 %29, %25
  %31 = zext nneg i8 %20 to i16
  %32 = add nuw nsw i8 %20, 1
  store i8 %32, ptr %6, align 1, !tbaa !44
  %33 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %31
  %34 = getelementptr inbounds nuw i8, ptr %33, i16 10
  store i8 0, ptr %34, align 1, !tbaa !45
  store i16 %30, ptr %33, align 1, !tbaa !47
  %35 = getelementptr inbounds nuw i8, ptr %33, i16 9
  store i8 -128, ptr %35, align 1, !tbaa !48
  %36 = getelementptr inbounds nuw i8, ptr %33, i16 7
  store i8 24, ptr %36, align 1, !tbaa !49
  %37 = getelementptr inbounds nuw i8, ptr %33, i16 8
  store i8 1, ptr %37, align 1, !tbaa !50
  %38 = ptrtoint ptr %24 to i16
  %39 = getelementptr inbounds nuw i8, ptr %33, i16 2
  store i16 %38, ptr %39, align 1, !tbaa !51
  %40 = getelementptr inbounds nuw i8, ptr %33, i16 6
  store i8 0, ptr %40, align 1, !tbaa !52
  %41 = getelementptr inbounds nuw i8, ptr %33, i16 4
  store i16 64, ptr %41, align 1, !tbaa !53
  br label %42

42:                                               ; preds = %22, %19, %11
  %43 = add nuw i8 %12, 64
  br i1 %13, label %11, label %10, !llvm.loop !109
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal void @_title_reserve(ptr noundef %0, ptr readnone captures(none) %1) #4 {
  store volatile i8 80, ptr inttoptr (i16 8456 to ptr), align 8, !tbaa !6
  store volatile i8 16, ptr inttoptr (i16 8459 to ptr), align 1, !tbaa !6
  store volatile i8 112, ptr inttoptr (i16 8481 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8482 to ptr), align 2, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8482 to ptr), align 2, !tbaa !6
  store volatile i8 -1, ptr inttoptr (i16 8482 to ptr), align 2, !tbaa !6
  store volatile i8 127, ptr inttoptr (i16 8482 to ptr), align 2, !tbaa !6
  store volatile i8 -124, ptr inttoptr (i16 8482 to ptr), align 2, !tbaa !6
  store volatile i8 16, ptr inttoptr (i16 8482 to ptr), align 2, !tbaa !6
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 4096, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %3

3:                                                ; preds = %2, %16
  %4 = phi ptr [ @FONT8, %2 ], [ %18, %16 ]
  %5 = phi i16 [ 0, %2 ], [ %17, %16 ]
  br label %7

6:                                                ; preds = %16
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 5120, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %24

7:                                                ; preds = %3, %7
  %8 = phi i8 [ 0, %3 ], [ %15, %7 ]
  %9 = phi i8 [ 0, %3 ], [ %13, %7 ]
  %10 = zext nneg i8 %8 to i16
  %11 = getelementptr i8, ptr %4, i16 %10
  %12 = load i16, ptr %11, align 1, !tbaa !2
  store volatile i16 %12, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %13 = add nuw nsw i8 %9, 1
  %14 = icmp eq i8 %13, 8
  %15 = add nuw nsw i8 %8, 2
  br i1 %14, label %20, label %7, !llvm.loop !110

16:                                               ; preds = %20
  %17 = add nuw nsw i16 %5, 1
  %18 = getelementptr i8, ptr %4, i16 16
  %19 = icmp eq i16 %17, 64
  br i1 %19, label %6, label %3, !llvm.loop !111

20:                                               ; preds = %7, %20
  %21 = phi i8 [ %22, %20 ], [ 0, %7 ]
  store volatile i16 0, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %22 = add nuw nsw i8 %21, 1
  %23 = icmp eq i8 %22, 8
  br i1 %23, label %16, label %20, !llvm.loop !112

24:                                               ; preds = %6, %33
  %25 = phi ptr [ getelementptr inbounds nuw (i8, ptr @FONT16, i16 16), %6 ], [ %36, %33 ]
  %26 = phi ptr [ @FONT16, %6 ], [ %35, %33 ]
  %27 = phi i16 [ 0, %6 ], [ %34, %33 ]
  br label %29

28:                                               ; preds = %33
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 20480, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %66

29:                                               ; preds = %24, %47
  %30 = phi i8 [ 0, %24 ], [ %52, %47 ]
  %31 = phi ptr [ %26, %24 ], [ %50, %47 ]
  %32 = phi i8 [ 0, %24 ], [ %48, %47 ]
  br label %38

33:                                               ; preds = %47
  %34 = add nuw nsw i16 %27, 1
  %35 = getelementptr i8, ptr %26, i16 64
  %36 = getelementptr i8, ptr %25, i16 64
  %37 = icmp eq i16 %34, 64
  br i1 %37, label %28, label %24, !llvm.loop !113

38:                                               ; preds = %29, %38
  %39 = phi i8 [ 0, %29 ], [ %46, %38 ]
  %40 = phi i8 [ 0, %29 ], [ %44, %38 ]
  %41 = zext nneg i8 %39 to i16
  %42 = getelementptr i8, ptr %31, i16 %41
  %43 = load i16, ptr %42, align 1, !tbaa !2
  store volatile i16 %43, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %44 = add nuw nsw i8 %40, 1
  %45 = icmp eq i8 %44, 8
  %46 = add nuw nsw i8 %39, 2
  br i1 %45, label %53, label %38, !llvm.loop !114

47:                                               ; preds = %53
  %48 = add nuw nsw i8 %32, 1
  %49 = zext nneg i8 %30 to i16
  %50 = getelementptr i8, ptr %25, i16 %49
  %51 = icmp eq i8 %48, 4
  %52 = add nuw nsw i8 %30, 16
  br i1 %51, label %33, label %29, !llvm.loop !115

53:                                               ; preds = %38, %53
  %54 = phi i8 [ %55, %53 ], [ 0, %38 ]
  store volatile i16 0, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %55 = add nuw nsw i8 %54, 1
  %56 = icmp eq i8 %55, 8
  br i1 %56, label %47, label %53, !llvm.loop !116

57:                                               ; preds = %66
  %58 = getelementptr inbounds nuw i8, ptr %0, i16 3
  %59 = load ptr, ptr %58, align 1, !tbaa !64
  %60 = icmp eq ptr %59, null
  br i1 %60, label %79, label %61

61:                                               ; preds = %57
  %62 = load i8, ptr %59, align 1, !tbaa !6
  %63 = icmp eq i8 %62, 0
  br i1 %63, label %79, label %64

64:                                               ; preds = %61
  %65 = getelementptr i8, ptr %59, i16 1
  br label %70

66:                                               ; preds = %28, %66
  %67 = phi i16 [ 0, %28 ], [ %68, %66 ]
  store volatile i16 7168, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %68 = add nuw nsw i16 %67, 1
  %69 = icmp eq i16 %68, 1024
  br i1 %69, label %57, label %66, !llvm.loop !117

70:                                               ; preds = %64, %70
  %71 = phi i8 [ %72, %70 ], [ 0, %64 ]
  %72 = add nuw nsw i8 %71, 1
  %73 = zext nneg i8 %71 to i16
  %74 = getelementptr i8, ptr %65, i16 %73
  %75 = load i8, ptr %74, align 1, !tbaa !6
  %76 = icmp ne i8 %75, 0
  %77 = icmp samesign ult i8 %71, 31
  %78 = select i1 %76, i1 %77, i1 false
  br i1 %78, label %70, label %79, !llvm.loop !118

79:                                               ; preds = %70, %61, %57
  %80 = phi i8 [ 0, %57 ], [ 0, %61 ], [ %72, %70 ]
  %81 = zext nneg i8 %80 to i16
  %82 = sub nuw nsw i16 32, %81
  %83 = lshr i16 %82, 1
  %84 = getelementptr inbounds nuw i8, ptr %0, i16 13
  %85 = load i16, ptr %84, align 1, !tbaa !70
  %86 = shl i16 %85, 2
  %87 = and i16 %86, -32
  %88 = add i16 %87, 20480
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 %88, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  %89 = trunc nuw nsw i16 %83 to i8
  %90 = add nuw nsw i8 %80, %89
  %91 = sub nsw i16 0, %83
  %92 = getelementptr i8, ptr %59, i16 %91
  br label %105

93:                                               ; preds = %128
  %94 = getelementptr inbounds nuw i8, ptr %0, i16 7
  %95 = load ptr, ptr %94, align 1, !tbaa !66
  %96 = getelementptr inbounds nuw i8, ptr %0, i16 11
  %97 = load i8, ptr %96, align 1, !tbaa !67
  %98 = getelementptr inbounds nuw i8, ptr %0, i16 15
  %99 = load i16, ptr %98, align 1, !tbaa !71
  %100 = lshr i16 %99, 3
  %101 = trunc i16 %100 to i8
  tail call fastcc void @_title_write16(ptr noundef %95, i8 noundef zeroext %97, i8 noundef zeroext %101) #16
  %102 = getelementptr inbounds nuw i8, ptr %0, i16 9
  %103 = load ptr, ptr %102, align 1, !tbaa !68
  %104 = icmp eq ptr %103, null
  br i1 %104, label %139, label %132

105:                                              ; preds = %79, %128
  %106 = phi i8 [ 0, %79 ], [ %130, %128 ]
  %107 = zext nneg i8 %106 to i16
  br i1 %60, label %128, label %108

108:                                              ; preds = %105
  %109 = icmp samesign ugt i16 %83, %107
  br i1 %109, label %128, label %110

110:                                              ; preds = %108
  %111 = icmp ult i8 %106, %90
  br i1 %111, label %112, label %128

112:                                              ; preds = %110
  %113 = getelementptr i8, ptr %92, i16 %107
  %114 = load i8, ptr %113, align 1, !tbaa !6
  %115 = icmp ugt i8 %114, 96
  br i1 %115, label %116, label %120

116:                                              ; preds = %112
  %117 = icmp ult i8 %114, 123
  br i1 %117, label %118, label %128

118:                                              ; preds = %116
  %119 = add nsw i8 %114, -32
  br label %124

120:                                              ; preds = %112
  %121 = icmp samesign ugt i8 %114, 31
  br i1 %121, label %122, label %128

122:                                              ; preds = %120
  %123 = icmp eq i8 %114, 96
  br i1 %123, label %128, label %124

124:                                              ; preds = %122, %118
  %125 = phi i8 [ %119, %118 ], [ %114, %122 ]
  %126 = zext nneg i8 %125 to i16
  %127 = add nuw nsw i16 %126, 7136
  br label %128

128:                                              ; preds = %124, %122, %120, %116, %105, %108, %110
  %129 = phi i16 [ 7168, %105 ], [ 7168, %110 ], [ 7168, %108 ], [ %127, %124 ], [ 7168, %122 ], [ 7168, %120 ], [ 7168, %116 ]
  store volatile i16 %129, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %130 = add nuw nsw i8 %106, 1
  %131 = icmp eq i8 %130, 32
  br i1 %131, label %93, label %105, !llvm.loop !119

132:                                              ; preds = %93
  %133 = getelementptr inbounds nuw i8, ptr %0, i16 12
  %134 = load i8, ptr %133, align 1, !tbaa !69
  %135 = load i16, ptr %98, align 1, !tbaa !71
  %136 = lshr i16 %135, 3
  %137 = trunc i16 %136 to i8
  %138 = add i8 %137, 2
  tail call fastcc void @_title_write16(ptr noundef nonnull %103, i8 noundef zeroext %134, i8 noundef zeroext %138) #16
  br label %139

139:                                              ; preds = %132, %93
  %140 = getelementptr inbounds nuw i8, ptr %0, i16 19
  store i16 -128, ptr %140, align 1, !tbaa !97
  %141 = getelementptr inbounds nuw i8, ptr %0, i16 21
  store i16 3584, ptr %141, align 1, !tbaa !120
  %142 = getelementptr inbounds nuw i8, ptr %0, i16 23
  store i16 0, ptr %142, align 1, !tbaa !121
  %143 = load ptr, ptr %58, align 1, !tbaa !64
  %144 = icmp eq ptr %143, null
  br i1 %144, label %167, label %145

145:                                              ; preds = %139
  %146 = load i8, ptr %143, align 1, !tbaa !6
  %147 = icmp eq i8 %146, 0
  br i1 %147, label %150, label %148

148:                                              ; preds = %145
  %149 = getelementptr i8, ptr %143, i16 1
  br label %158

150:                                              ; preds = %158, %145
  %151 = phi i8 [ 0, %145 ], [ %160, %158 ]
  %152 = zext nneg i8 %151 to i16
  %153 = shl nuw nsw i16 %152, 2
  %154 = sub nuw nsw i16 128, %153
  %155 = and i16 %154, 248
  %156 = add nsw i16 %153, -128
  %157 = add nsw i16 %156, %155
  br label %167

158:                                              ; preds = %158, %148
  %159 = phi i8 [ %160, %158 ], [ 0, %148 ]
  %160 = add nuw nsw i8 %159, 1
  %161 = zext nneg i8 %159 to i16
  %162 = getelementptr i8, ptr %149, i16 %161
  %163 = load i8, ptr %162, align 1, !tbaa !6
  %164 = icmp ne i8 %163, 0
  %165 = icmp samesign ult i8 %159, 31
  %166 = select i1 %164, i1 %165, i1 false
  br i1 %166, label %158, label %150, !llvm.loop !122

167:                                              ; preds = %139, %150
  %168 = phi i16 [ %157, %150 ], [ 0, %139 ]
  %169 = getelementptr inbounds nuw i8, ptr %0, i16 26
  store i16 %168, ptr %169, align 1, !tbaa !123
  store volatile i8 -112, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  %170 = getelementptr inbounds nuw i8, ptr %0, i16 38
  %171 = getelementptr inbounds nuw i8, ptr %0, i16 89
  tail call fastcc void @_title_build(ptr noundef nonnull %0, i16 noundef -8, i16 noundef 224, ptr noundef nonnull %170, ptr noundef nonnull %171) #16
  %172 = getelementptr inbounds nuw i8, ptr %0, i16 88
  store i8 0, ptr %172, align 1, !tbaa !124
  store volatile i8 2, ptr inttoptr (i16 17200 to ptr), align 16, !tbaa !6
  store volatile i8 16, ptr inttoptr (i16 17201 to ptr), align 1, !tbaa !6
  %173 = ptrtoint ptr %170 to i16
  %174 = trunc i16 %173 to i8
  store volatile i8 %174, ptr inttoptr (i16 17202 to ptr), align 2, !tbaa !6
  %175 = lshr i16 %173, 8
  %176 = trunc nuw i16 %175 to i8
  store volatile i8 %176, ptr inttoptr (i16 17203 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 17204 to ptr), align 4, !tbaa !6
  %177 = getelementptr inbounds nuw i8, ptr %0, i16 139
  store i8 0, ptr %177, align 1, !tbaa !124
  store volatile i8 2, ptr inttoptr (i16 17216 to ptr), align 64, !tbaa !6
  store volatile i8 15, ptr inttoptr (i16 17217 to ptr), align 1, !tbaa !6
  %178 = ptrtoint ptr %171 to i16
  %179 = trunc i16 %178 to i8
  store volatile i8 %179, ptr inttoptr (i16 17218 to ptr), align 2, !tbaa !6
  %180 = lshr i16 %178, 8
  %181 = trunc nuw i16 %180 to i8
  store volatile i8 %181, ptr inttoptr (i16 17219 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 17220 to ptr), align 4, !tbaa !6
  %182 = getelementptr inbounds nuw i8, ptr %0, i16 2
  store i8 2, ptr %182, align 1, !tbaa !63
  ret void
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal void @_title_emit(ptr noundef %0, ptr noundef captures(none) %1) #7 {
  %3 = getelementptr inbounds nuw i8, ptr %0, i16 29
  %4 = load i8, ptr %3, align 1, !tbaa !74
  %5 = icmp eq i8 %4, 0
  br i1 %5, label %188, label %6

6:                                                ; preds = %2
  %7 = getelementptr inbounds nuw i8, ptr %0, i16 30
  %8 = load i8, ptr %7, align 1, !tbaa !77
  %9 = icmp eq i8 %8, 0
  br i1 %9, label %39, label %10

10:                                               ; preds = %6
  %11 = getelementptr inbounds nuw i8, ptr %0, i16 25
  %12 = load i8, ptr %11, align 1, !tbaa !78
  %13 = icmp ugt i8 %12, -6
  br i1 %13, label %16, label %14

14:                                               ; preds = %10
  %15 = add nuw i8 %12, 4
  br label %16

16:                                               ; preds = %10, %14
  %17 = phi i8 [ %15, %14 ], [ -1, %10 ]
  store i8 %17, ptr %11, align 1, !tbaa !78
  %18 = getelementptr inbounds nuw i8, ptr %0, i16 13
  %19 = load i16, ptr %18, align 1, !tbaa !70
  %20 = xor i8 %17, -1
  %21 = zext i8 %20 to i16
  %22 = mul nuw i16 %21, %21
  %23 = lshr i16 %22, 8
  %24 = sub nuw nsw i16 256, %23
  %25 = add nsw i16 %19, 8
  %26 = mul nsw i16 %24, %25
  %27 = ashr i16 %26, 4
  %28 = and i16 %27, -16
  %29 = add nsw i16 %28, -128
  %30 = getelementptr inbounds nuw i8, ptr %0, i16 19
  store i16 %29, ptr %30, align 1, !tbaa !97
  %31 = getelementptr inbounds nuw i8, ptr %0, i16 15
  %32 = load i16, ptr %31, align 1, !tbaa !71
  %33 = add nsw i16 %32, -224
  %34 = mul nsw i16 %33, %24
  %35 = ashr i16 %34, 4
  %36 = and i16 %35, -16
  %37 = add nsw i16 %36, 3584
  %38 = getelementptr inbounds nuw i8, ptr %0, i16 21
  store i16 %37, ptr %38, align 1, !tbaa !120
  br label %64

39:                                               ; preds = %6
  %40 = getelementptr inbounds nuw i8, ptr %0, i16 31
  %41 = load i8, ptr %40, align 1, !tbaa !75
  %42 = icmp eq i8 %41, 0
  br i1 %42, label %43, label %48

43:                                               ; preds = %39
  %44 = getelementptr inbounds nuw i8, ptr %0, i16 19
  %45 = load i16, ptr %44, align 1, !tbaa !97
  %46 = getelementptr inbounds nuw i8, ptr %0, i16 21
  %47 = load i16, ptr %46, align 1, !tbaa !120
  br label %64

48:                                               ; preds = %39
  %49 = getelementptr inbounds nuw i8, ptr %0, i16 23
  %50 = load i16, ptr %49, align 1, !tbaa !121
  %51 = add nsw i16 %50, 2
  store i16 %51, ptr %49, align 1, !tbaa !121
  %52 = getelementptr inbounds nuw i8, ptr %0, i16 19
  %53 = load i16, ptr %52, align 1, !tbaa !97
  %54 = add nsw i16 %53, %51
  store i16 %54, ptr %52, align 1, !tbaa !97
  %55 = getelementptr inbounds nuw i8, ptr %0, i16 21
  %56 = load i16, ptr %55, align 1, !tbaa !120
  %57 = add nsw i16 %56, %51
  store i16 %57, ptr %55, align 1, !tbaa !120
  %58 = icmp sgt i16 %54, 4480
  br i1 %58, label %59, label %60

59:                                               ; preds = %48
  store i16 4480, ptr %52, align 1, !tbaa !97
  br label %60

60:                                               ; preds = %59, %48
  %61 = phi i16 [ 4480, %59 ], [ %54, %48 ]
  %62 = icmp sgt i16 %57, 4736
  br i1 %62, label %63, label %64

63:                                               ; preds = %60
  store i16 4736, ptr %55, align 1, !tbaa !120
  br label %64

64:                                               ; preds = %43, %63, %60, %16
  %65 = phi i16 [ %47, %43 ], [ 4736, %63 ], [ %57, %60 ], [ %37, %16 ]
  %66 = phi i16 [ %45, %43 ], [ %61, %63 ], [ %61, %60 ], [ %29, %16 ]
  %67 = ashr i16 %66, 4
  %68 = ashr i16 %65, 4
  %69 = getelementptr inbounds nuw i8, ptr %0, i16 38
  %70 = getelementptr inbounds nuw i8, ptr %0, i16 88
  %71 = load i8, ptr %70, align 1, !tbaa !124
  %72 = xor i8 %71, 1
  %73 = zext i8 %72 to i16
  %74 = getelementptr inbounds nuw [25 x i8], ptr %69, i16 %73
  %75 = getelementptr inbounds nuw i8, ptr %0, i16 89
  %76 = getelementptr inbounds nuw i8, ptr %0, i16 139
  %77 = load i8, ptr %76, align 1, !tbaa !124
  %78 = xor i8 %77, 1
  %79 = zext i8 %78 to i16
  %80 = getelementptr inbounds nuw [25 x i8], ptr %75, i16 %79
  tail call fastcc void @_title_build(ptr noundef nonnull %0, i16 noundef %67, i16 noundef %68, ptr noundef nonnull %74, ptr noundef nonnull %80) #16
  %81 = getelementptr inbounds nuw i8, ptr %1, i16 176
  %82 = load i8, ptr %81, align 1, !tbaa !44
  %83 = icmp ugt i8 %82, 15
  br i1 %83, label %109, label %84

84:                                               ; preds = %64
  %85 = load i8, ptr %70, align 1, !tbaa !124
  %86 = xor i8 %85, 1
  %87 = zext i8 %86 to i16
  %88 = getelementptr inbounds nuw [25 x i8], ptr %69, i16 %87
  %89 = ptrtoint ptr %88 to i16
  %90 = zext nneg i8 %82 to i16
  %91 = add nuw nsw i8 %82, 1
  store i8 %91, ptr %81, align 1, !tbaa !44
  %92 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %90
  %93 = getelementptr inbounds nuw i8, ptr %92, i16 10
  store i8 4, ptr %93, align 1, !tbaa !45
  store i16 17202, ptr %92, align 1, !tbaa !47
  %94 = getelementptr inbounds nuw i8, ptr %92, i16 2
  store i16 %89, ptr %94, align 1, !tbaa !51
  %95 = getelementptr inbounds nuw i8, ptr %92, i16 4
  store i16 0, ptr %95, align 1, !tbaa !53
  store i8 %86, ptr %70, align 1, !tbaa !124
  %96 = icmp eq i8 %82, 15
  br i1 %96, label %109, label %97

97:                                               ; preds = %84
  %98 = load i8, ptr %76, align 1, !tbaa !124
  %99 = xor i8 %98, 1
  %100 = zext i8 %99 to i16
  %101 = getelementptr inbounds nuw [25 x i8], ptr %75, i16 %100
  %102 = ptrtoint ptr %101 to i16
  %103 = zext nneg i8 %91 to i16
  %104 = add nuw nsw i8 %82, 2
  store i8 %104, ptr %81, align 1, !tbaa !44
  %105 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %103
  %106 = getelementptr inbounds nuw i8, ptr %105, i16 10
  store i8 4, ptr %106, align 1, !tbaa !45
  store i16 17218, ptr %105, align 1, !tbaa !47
  %107 = getelementptr inbounds nuw i8, ptr %105, i16 2
  store i16 %102, ptr %107, align 1, !tbaa !51
  %108 = getelementptr inbounds nuw i8, ptr %105, i16 4
  store i16 0, ptr %108, align 1, !tbaa !53
  store i8 %99, ptr %76, align 1, !tbaa !124
  br label %109

109:                                              ; preds = %64, %84, %97
  %110 = phi i8 [ %82, %64 ], [ 16, %84 ], [ %104, %97 ]
  %111 = getelementptr inbounds nuw i8, ptr %0, i16 28
  %112 = load i8, ptr %111, align 1, !tbaa !73
  %113 = add i8 %112, 1
  store i8 %113, ptr %111, align 1, !tbaa !73
  %114 = getelementptr inbounds nuw i8, ptr %0, i16 32
  %115 = load i8, ptr %114, align 1, !tbaa !76
  %116 = icmp eq i8 %115, 0
  br i1 %116, label %117, label %155

117:                                              ; preds = %109
  %118 = shl i8 %113, 1
  %119 = icmp sgt i8 %118, -1
  br i1 %119, label %122, label %120

120:                                              ; preds = %117
  %121 = xor i8 %118, -1
  br label %122

122:                                              ; preds = %117, %120
  %123 = phi i8 [ %121, %120 ], [ %118, %117 ]
  %124 = lshr i8 %123, 4
  %125 = add nuw nsw i8 %124, 24
  %126 = zext nneg i8 %125 to i16
  %127 = mul nuw nsw i16 %126, 1057
  %128 = getelementptr inbounds nuw i8, ptr %0, i16 34
  store i16 %127, ptr %128, align 1, !tbaa !79
  %129 = add i8 %118, -86
  %130 = icmp sgt i8 %129, -1
  br i1 %130, label %133, label %131

131:                                              ; preds = %122
  %132 = sub nsw i8 85, %118
  br label %133

133:                                              ; preds = %122, %131
  %134 = phi i8 [ %132, %131 ], [ %129, %122 ]
  %135 = lshr i8 %134, 2
  %136 = zext nneg i8 %135 to i16
  %137 = shl nuw nsw i16 %136, 10
  %138 = add i8 %118, 85
  %139 = icmp sgt i8 %138, -1
  br i1 %139, label %142, label %140

140:                                              ; preds = %133
  %141 = sub nuw i8 -86, %118
  br label %142

142:                                              ; preds = %133, %140
  %143 = phi i8 [ %141, %140 ], [ %138, %133 ]
  %144 = lshr i8 %143, 2
  %145 = zext nneg i8 %144 to i16
  %146 = shl nuw nsw i16 %145, 5
  %147 = add nuw nsw i16 %146, %137
  br i1 %119, label %150, label %148

148:                                              ; preds = %142
  %149 = xor i8 %118, -1
  br label %150

150:                                              ; preds = %142, %148
  %151 = phi i8 [ %149, %148 ], [ %118, %142 ]
  %152 = lshr i8 %151, 2
  %153 = zext nneg i8 %152 to i16
  %154 = add nuw nsw i16 %147, %153
  br label %157

155:                                              ; preds = %109
  %156 = getelementptr inbounds nuw i8, ptr %0, i16 34
  store i16 29596, ptr %156, align 1, !tbaa !79
  br label %157

157:                                              ; preds = %155, %150
  %158 = phi i16 [ 0, %155 ], [ %154, %150 ]
  %159 = getelementptr inbounds nuw i8, ptr %0, i16 36
  store i16 %158, ptr %159, align 1, !tbaa !80
  %160 = icmp ugt i8 %110, 15
  br i1 %160, label %188, label %161

161:                                              ; preds = %157
  %162 = getelementptr inbounds nuw i8, ptr %0, i16 34
  %163 = zext nneg i8 %110 to i16
  %164 = add nuw nsw i8 %110, 1
  store i8 %164, ptr %81, align 1, !tbaa !44
  %165 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %163
  %166 = getelementptr inbounds nuw i8, ptr %165, i16 10
  store i8 1, ptr %166, align 1, !tbaa !45
  store i16 113, ptr %165, align 1, !tbaa !47
  %167 = getelementptr inbounds nuw i8, ptr %165, i16 9
  store i8 0, ptr %167, align 1, !tbaa !48
  %168 = getelementptr inbounds nuw i8, ptr %165, i16 7
  store i8 34, ptr %168, align 1, !tbaa !49
  %169 = getelementptr inbounds nuw i8, ptr %165, i16 8
  store i8 0, ptr %169, align 1, !tbaa !50
  %170 = ptrtoint ptr %162 to i16
  %171 = getelementptr inbounds nuw i8, ptr %165, i16 2
  store i16 %170, ptr %171, align 1, !tbaa !51
  %172 = getelementptr inbounds nuw i8, ptr %165, i16 6
  store i8 0, ptr %172, align 1, !tbaa !52
  %173 = getelementptr inbounds nuw i8, ptr %165, i16 4
  store i16 2, ptr %173, align 1, !tbaa !53
  %174 = icmp eq i8 %110, 15
  br i1 %174, label %188, label %175

175:                                              ; preds = %161
  %176 = getelementptr inbounds nuw i8, ptr %0, i16 36
  %177 = zext nneg i8 %164 to i16
  %178 = add nuw nsw i8 %110, 2
  store i8 %178, ptr %81, align 1, !tbaa !44
  %179 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %177
  %180 = getelementptr inbounds nuw i8, ptr %179, i16 10
  store i8 1, ptr %180, align 1, !tbaa !45
  store i16 0, ptr %179, align 1, !tbaa !47
  %181 = getelementptr inbounds nuw i8, ptr %179, i16 9
  store i8 0, ptr %181, align 1, !tbaa !48
  %182 = getelementptr inbounds nuw i8, ptr %179, i16 7
  store i8 34, ptr %182, align 1, !tbaa !49
  %183 = getelementptr inbounds nuw i8, ptr %179, i16 8
  store i8 0, ptr %183, align 1, !tbaa !50
  %184 = ptrtoint ptr %176 to i16
  %185 = getelementptr inbounds nuw i8, ptr %179, i16 2
  store i16 %184, ptr %185, align 1, !tbaa !51
  %186 = getelementptr inbounds nuw i8, ptr %179, i16 6
  store i8 0, ptr %186, align 1, !tbaa !52
  %187 = getelementptr inbounds nuw i8, ptr %179, i16 4
  store i16 2, ptr %187, align 1, !tbaa !53
  br label %188

188:                                              ; preds = %157, %175, %161, %2
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal fastcc void @_title_write16(ptr noundef readonly captures(address_is_null) %0, i8 noundef zeroext %1, i8 noundef zeroext %2) unnamed_addr #4 {
  %4 = zext i8 %1 to i16
  %5 = shl nuw nsw i16 %4, 1
  %6 = and i16 %5, 254
  %7 = sub nsw i16 32, %6
  %8 = lshr exact i16 %7, 1
  %9 = zext i8 %2 to i16
  %10 = icmp eq ptr %0, null
  %11 = and i16 %8, 255
  %12 = add nuw i16 %8, %5
  %13 = and i16 %12, 255
  br label %15

14:                                               ; preds = %23
  ret void

15:                                               ; preds = %3, %23
  %16 = phi i1 [ true, %3 ], [ false, %23 ]
  %17 = phi i8 [ 0, %3 ], [ 1, %23 ]
  %18 = zext nneg i8 %17 to i16
  %19 = add nuw nsw i16 %18, %9
  %20 = shl nuw nsw i16 %19, 5
  %21 = add nuw nsw i16 %20, 20480
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 %21, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  %22 = select i1 %16, i16 7168, i16 7170
  br label %24

23:                                               ; preds = %56
  br i1 %16, label %15, label %14, !llvm.loop !125

24:                                               ; preds = %15, %56
  %25 = phi i8 [ 0, %15 ], [ %58, %56 ]
  %26 = zext nneg i8 %25 to i16
  br i1 %10, label %56, label %27

27:                                               ; preds = %24
  %28 = icmp samesign ugt i16 %11, %26
  br i1 %28, label %56, label %29

29:                                               ; preds = %27
  %30 = icmp samesign ugt i16 %13, %26
  br i1 %30, label %31, label %56

31:                                               ; preds = %29
  %32 = sub nsw i16 %26, %11
  %33 = lshr i16 %32, 1
  %34 = and i16 %33, 255
  %35 = getelementptr inbounds nuw i8, ptr %0, i16 %34
  %36 = load i8, ptr %35, align 1, !tbaa !6
  %37 = icmp ugt i8 %36, 96
  br i1 %37, label %38, label %42

38:                                               ; preds = %31
  %39 = icmp ult i8 %36, 123
  br i1 %39, label %40, label %51

40:                                               ; preds = %38
  %41 = add nsw i8 %36, -32
  br label %46

42:                                               ; preds = %31
  %43 = icmp samesign ugt i8 %36, 31
  br i1 %43, label %44, label %51

44:                                               ; preds = %42
  %45 = icmp eq i8 %36, 96
  br i1 %45, label %51, label %46

46:                                               ; preds = %44, %40
  %47 = phi i8 [ %41, %40 ], [ %36, %44 ]
  %48 = zext nneg i8 %47 to i16
  %49 = shl nuw nsw i16 %48, 2
  %50 = add nsw i16 %49, -64
  br label %51

51:                                               ; preds = %38, %42, %44, %46
  %52 = phi i16 [ %50, %46 ], [ 64, %44 ], [ 64, %42 ], [ 64, %38 ]
  %53 = and i16 %32, 1
  %54 = or disjoint i16 %22, %53
  %55 = or disjoint i16 %54, %52
  br label %56

56:                                               ; preds = %51, %29, %27, %24
  %57 = phi i16 [ %55, %51 ], [ 7168, %29 ], [ 7168, %27 ], [ 7168, %24 ]
  store volatile i16 %57, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %58 = add nuw nsw i8 %25, 1
  %59 = icmp eq i8 %58, 32
  br i1 %59, label %23, label %24, !llvm.loop !126
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @_title_build(ptr noundef readonly captures(none) %0, i16 noundef range(i16 -2048, 2048) %1, i16 noundef range(i16 -2048, 2048) %2, ptr noundef %3, ptr noundef %4) unnamed_addr #7 {
  %6 = alloca %struct.HScrollW, align 1
  %7 = alloca %struct.HScrollW, align 1
  %8 = alloca i16, align 1
  call void @llvm.lifetime.start.p0(ptr nonnull %6) #17
  call void @llvm.lifetime.start.p0(ptr nonnull %7) #17
  call void @llvm.lifetime.start.p0(ptr nonnull %8) #17
  store i16 0, ptr %8, align 1, !tbaa !2
  store ptr %3, ptr %6, align 1, !tbaa !127
  %9 = getelementptr inbounds nuw i8, ptr %6, i16 2
  store i8 0, ptr %9, align 1, !tbaa !129
  store ptr %4, ptr %7, align 1, !tbaa !127
  %10 = getelementptr inbounds nuw i8, ptr %7, i16 2
  store i8 0, ptr %10, align 1, !tbaa !129
  %11 = getelementptr inbounds nuw i8, ptr %0, i16 13
  %12 = load i16, ptr %11, align 1, !tbaa !70
  %13 = getelementptr inbounds nuw i8, ptr %0, i16 26
  %14 = load i16, ptr %13, align 1, !tbaa !123
  call fastcc void @_title_glyph_band(ptr noundef %6, ptr noundef %7, ptr noundef %8, i16 noundef %1, i16 noundef 8, i16 noundef %12, i16 noundef %14) #16
  %15 = getelementptr inbounds nuw i8, ptr %0, i16 17
  %16 = load i16, ptr %15, align 1, !tbaa !72
  %17 = getelementptr inbounds nuw i8, ptr %0, i16 15
  %18 = load i16, ptr %17, align 1, !tbaa !71
  call fastcc void @_title_glyph_band(ptr noundef %6, ptr noundef %7, ptr noundef %8, i16 noundef %2, i16 noundef %16, i16 noundef %18, i16 noundef 0) #16
  %19 = load i16, ptr %8, align 1, !tbaa !2
  call fastcc void @_title_blank(ptr noundef %6, ptr noundef %7, i16 noundef %19, i16 noundef 224) #16
  %20 = load ptr, ptr %6, align 1, !tbaa !127
  %21 = load i8, ptr %9, align 1, !tbaa !129
  %22 = zext i8 %21 to i16
  %23 = getelementptr inbounds nuw i8, ptr %20, i16 %22
  store i8 0, ptr %23, align 1, !tbaa !6
  %24 = load ptr, ptr %7, align 1, !tbaa !127
  %25 = load i8, ptr %10, align 1, !tbaa !129
  %26 = zext i8 %25 to i16
  %27 = getelementptr inbounds nuw i8, ptr %24, i16 %26
  store i8 0, ptr %27, align 1, !tbaa !6
  call void @llvm.lifetime.end.p0(ptr nonnull %8) #17
  call void @llvm.lifetime.end.p0(ptr nonnull %7) #17
  call void @llvm.lifetime.end.p0(ptr nonnull %6) #17
  ret void
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @_title_glyph_band(ptr noundef nonnull captures(none) %0, ptr noundef nonnull captures(none) %1, ptr noundef nonnull captures(none) %2, i16 noundef range(i16 -2048, 2048) %3, i16 noundef %4, i16 noundef %5, i16 noundef %6) unnamed_addr #7 {
  %8 = add nsw i16 %3, -2
  %9 = add nsw i16 %4, %3
  %10 = add nsw i16 %9, 2
  %11 = load i16, ptr %2, align 1, !tbaa !2
  %12 = icmp slt i16 %8, %11
  br i1 %12, label %13, label %14

13:                                               ; preds = %7
  br label %14

14:                                               ; preds = %13, %7
  %15 = phi i16 [ %11, %13 ], [ %8, %7 ]
  %16 = icmp sgt i16 %9, 222
  br i1 %16, label %17, label %18

17:                                               ; preds = %14
  br label %18

18:                                               ; preds = %17, %14
  %19 = phi i16 [ 224, %17 ], [ %10, %14 ]
  %20 = icmp sgt i16 %19, %15
  br i1 %20, label %21, label %92

21:                                               ; preds = %18
  tail call fastcc void @_title_blank(ptr noundef %0, ptr noundef %1, i16 noundef %11, i16 noundef %15) #16
  %22 = sub nsw i16 %19, %15
  %23 = trunc i16 %22 to i8
  %24 = getelementptr inbounds nuw i8, ptr %0, i16 2
  %25 = icmp eq i8 %23, 0
  br i1 %25, label %91, label %26

26:                                               ; preds = %21
  %27 = sub nsw i16 %5, %3
  %28 = and i16 %22, 255
  %29 = trunc i16 %27 to i8
  %30 = lshr i16 %27, 8
  %31 = trunc nuw i16 %30 to i8
  br label %32

32:                                               ; preds = %40, %26
  %33 = phi i16 [ %28, %26 ], [ %57, %40 ]
  %34 = load i8, ptr %24, align 1, !tbaa !129
  %35 = icmp ult i8 %34, 22
  br i1 %35, label %36, label %59

36:                                               ; preds = %32
  %37 = icmp ugt i16 %33, 127
  br i1 %37, label %40, label %38

38:                                               ; preds = %36
  %39 = trunc nuw nsw i16 %33 to i8
  br label %40

40:                                               ; preds = %38, %36
  %41 = phi i8 [ %39, %38 ], [ 127, %36 ]
  %42 = load ptr, ptr %0, align 1, !tbaa !127
  %43 = add nuw nsw i8 %34, 1
  store i8 %43, ptr %24, align 1, !tbaa !129
  %44 = zext nneg i8 %34 to i16
  %45 = getelementptr inbounds nuw i8, ptr %42, i16 %44
  store i8 %41, ptr %45, align 1, !tbaa !6
  %46 = load ptr, ptr %0, align 1, !tbaa !127
  %47 = load i8, ptr %24, align 1, !tbaa !129
  %48 = add i8 %47, 1
  store i8 %48, ptr %24, align 1, !tbaa !129
  %49 = zext i8 %47 to i16
  %50 = getelementptr inbounds nuw i8, ptr %46, i16 %49
  store i8 %29, ptr %50, align 1, !tbaa !6
  %51 = load ptr, ptr %0, align 1, !tbaa !127
  %52 = load i8, ptr %24, align 1, !tbaa !129
  %53 = add i8 %52, 1
  store i8 %53, ptr %24, align 1, !tbaa !129
  %54 = zext i8 %52 to i16
  %55 = getelementptr inbounds nuw i8, ptr %51, i16 %54
  store i8 %31, ptr %55, align 1, !tbaa !6
  %56 = zext nneg i8 %41 to i16
  %57 = sub i16 %33, %56
  %58 = icmp eq i16 %57, 0
  br i1 %58, label %59, label %32, !llvm.loop !130

59:                                               ; preds = %32, %40
  %60 = getelementptr inbounds nuw i8, ptr %1, i16 2
  %61 = trunc i16 %6 to i8
  %62 = lshr i16 %6, 8
  %63 = trunc nuw i16 %62 to i8
  br label %64

64:                                               ; preds = %72, %59
  %65 = phi i16 [ %28, %59 ], [ %89, %72 ]
  %66 = load i8, ptr %60, align 1, !tbaa !129
  %67 = icmp ult i8 %66, 22
  br i1 %67, label %68, label %91

68:                                               ; preds = %64
  %69 = icmp ugt i16 %65, 127
  br i1 %69, label %72, label %70

70:                                               ; preds = %68
  %71 = trunc nuw nsw i16 %65 to i8
  br label %72

72:                                               ; preds = %70, %68
  %73 = phi i8 [ %71, %70 ], [ 127, %68 ]
  %74 = load ptr, ptr %1, align 1, !tbaa !127
  %75 = add nuw nsw i8 %66, 1
  store i8 %75, ptr %60, align 1, !tbaa !129
  %76 = zext nneg i8 %66 to i16
  %77 = getelementptr inbounds nuw i8, ptr %74, i16 %76
  store i8 %73, ptr %77, align 1, !tbaa !6
  %78 = load ptr, ptr %1, align 1, !tbaa !127
  %79 = load i8, ptr %60, align 1, !tbaa !129
  %80 = add i8 %79, 1
  store i8 %80, ptr %60, align 1, !tbaa !129
  %81 = zext i8 %79 to i16
  %82 = getelementptr inbounds nuw i8, ptr %78, i16 %81
  store i8 %61, ptr %82, align 1, !tbaa !6
  %83 = load ptr, ptr %1, align 1, !tbaa !127
  %84 = load i8, ptr %60, align 1, !tbaa !129
  %85 = add i8 %84, 1
  store i8 %85, ptr %60, align 1, !tbaa !129
  %86 = zext i8 %84 to i16
  %87 = getelementptr inbounds nuw i8, ptr %83, i16 %86
  store i8 %63, ptr %87, align 1, !tbaa !6
  %88 = zext nneg i8 %73 to i16
  %89 = sub i16 %65, %88
  %90 = icmp eq i16 %89, 0
  br i1 %90, label %91, label %64, !llvm.loop !130

91:                                               ; preds = %64, %72, %21
  store i16 %19, ptr %2, align 1, !tbaa !2
  br label %92

92:                                               ; preds = %18, %91
  ret void
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @_title_blank(ptr noundef nonnull captures(none) %0, ptr noundef nonnull captures(none) %1, i16 noundef %2, i16 noundef range(i16 -2050, 225) %3) unnamed_addr #7 {
  %5 = icmp sgt i16 %3, %2
  br i1 %5, label %6, label %83

6:                                                ; preds = %4
  %7 = getelementptr inbounds nuw i8, ptr %0, i16 2
  %8 = getelementptr inbounds nuw i8, ptr %1, i16 2
  br label %9

9:                                                ; preds = %6, %79
  %10 = phi i16 [ %2, %6 ], [ %81, %79 ]
  %11 = sub nsw i16 %3, %10
  %12 = icmp sgt i16 %11, 112
  br i1 %12, label %16, label %13

13:                                               ; preds = %9
  %14 = trunc i16 %11 to i8
  %15 = icmp eq i8 %14, 0
  br i1 %15, label %79, label %16

16:                                               ; preds = %9, %13
  %17 = phi i8 [ %14, %13 ], [ 112, %9 ]
  %18 = phi i16 [ %11, %13 ], [ 112, %9 ]
  %19 = sub nsw i16 144, %10
  %20 = zext i8 %17 to i16
  %21 = trunc i16 %19 to i8
  %22 = lshr i16 %19, 8
  %23 = trunc nuw i16 %22 to i8
  br label %24

24:                                               ; preds = %32, %16
  %25 = phi i16 [ %20, %16 ], [ %49, %32 ]
  %26 = load i8, ptr %7, align 1, !tbaa !129
  %27 = icmp ult i8 %26, 22
  br i1 %27, label %28, label %51

28:                                               ; preds = %24
  %29 = icmp ugt i16 %25, 127
  br i1 %29, label %32, label %30

30:                                               ; preds = %28
  %31 = trunc nuw nsw i16 %25 to i8
  br label %32

32:                                               ; preds = %30, %28
  %33 = phi i8 [ %31, %30 ], [ 127, %28 ]
  %34 = load ptr, ptr %0, align 1, !tbaa !127
  %35 = add nuw nsw i8 %26, 1
  store i8 %35, ptr %7, align 1, !tbaa !129
  %36 = zext nneg i8 %26 to i16
  %37 = getelementptr inbounds nuw i8, ptr %34, i16 %36
  store i8 %33, ptr %37, align 1, !tbaa !6
  %38 = load ptr, ptr %0, align 1, !tbaa !127
  %39 = load i8, ptr %7, align 1, !tbaa !129
  %40 = add i8 %39, 1
  store i8 %40, ptr %7, align 1, !tbaa !129
  %41 = zext i8 %39 to i16
  %42 = getelementptr inbounds nuw i8, ptr %38, i16 %41
  store i8 %21, ptr %42, align 1, !tbaa !6
  %43 = load ptr, ptr %0, align 1, !tbaa !127
  %44 = load i8, ptr %7, align 1, !tbaa !129
  %45 = add i8 %44, 1
  store i8 %45, ptr %7, align 1, !tbaa !129
  %46 = zext i8 %44 to i16
  %47 = getelementptr inbounds nuw i8, ptr %43, i16 %46
  store i8 %23, ptr %47, align 1, !tbaa !6
  %48 = zext nneg i8 %33 to i16
  %49 = sub i16 %25, %48
  %50 = icmp eq i16 %49, 0
  br i1 %50, label %51, label %24, !llvm.loop !130

51:                                               ; preds = %24, %32
  br label %52

52:                                               ; preds = %51, %60
  %53 = phi i16 [ %77, %60 ], [ %20, %51 ]
  %54 = load i8, ptr %8, align 1, !tbaa !129
  %55 = icmp ult i8 %54, 22
  br i1 %55, label %56, label %79

56:                                               ; preds = %52
  %57 = icmp ugt i16 %53, 127
  br i1 %57, label %60, label %58

58:                                               ; preds = %56
  %59 = trunc nuw nsw i16 %53 to i8
  br label %60

60:                                               ; preds = %58, %56
  %61 = phi i8 [ %59, %58 ], [ 127, %56 ]
  %62 = load ptr, ptr %1, align 1, !tbaa !127
  %63 = add nuw nsw i8 %54, 1
  store i8 %63, ptr %8, align 1, !tbaa !129
  %64 = zext nneg i8 %54 to i16
  %65 = getelementptr inbounds nuw i8, ptr %62, i16 %64
  store i8 %61, ptr %65, align 1, !tbaa !6
  %66 = load ptr, ptr %1, align 1, !tbaa !127
  %67 = load i8, ptr %8, align 1, !tbaa !129
  %68 = add i8 %67, 1
  store i8 %68, ptr %8, align 1, !tbaa !129
  %69 = zext i8 %67 to i16
  %70 = getelementptr inbounds nuw i8, ptr %66, i16 %69
  store i8 0, ptr %70, align 1, !tbaa !6
  %71 = load ptr, ptr %1, align 1, !tbaa !127
  %72 = load i8, ptr %8, align 1, !tbaa !129
  %73 = add i8 %72, 1
  store i8 %73, ptr %8, align 1, !tbaa !129
  %74 = zext i8 %72 to i16
  %75 = getelementptr inbounds nuw i8, ptr %71, i16 %74
  store i8 0, ptr %75, align 1, !tbaa !6
  %76 = zext nneg i8 %61 to i16
  %77 = sub i16 %53, %76
  %78 = icmp eq i16 %77, 0
  br i1 %78, label %79, label %52, !llvm.loop !130

79:                                               ; preds = %52, %60, %13
  %80 = phi i16 [ %11, %13 ], [ %18, %60 ], [ %18, %52 ]
  %81 = add nsw i16 %80, %10
  %82 = icmp sgt i16 %3, %81
  br i1 %82, label %9, label %83, !llvm.loop !131

83:                                               ; preds = %79, %4
  ret void
}

; Function Attrs: nofree norecurse nosync nounwind optsize
define internal void @mini_sprintf(ptr noundef nonnull writeonly captures(none) %0, ptr noundef readonly captures(none) %1, ...) unnamed_addr #1 {
  %3 = alloca ptr, align 1
  call void @llvm.lifetime.start.p0(ptr nonnull %3) #17
  call void @llvm.va_start.p0(ptr nonnull %3)
  br label %4

4:                                                ; preds = %62, %2
  %5 = phi ptr [ %0, %2 ], [ %63, %62 ]
  %6 = phi ptr [ %1, %2 ], [ %65, %62 ]
  %7 = load i8, ptr %6, align 1, !tbaa !6
  switch i8 %7, label %8 [
    i8 0, label %66
    i8 37, label %10
  ]

8:                                                ; preds = %4
  %9 = getelementptr inbounds nuw i8, ptr %5, i16 1
  store i8 %7, ptr %5, align 1, !tbaa !6
  br label %62

10:                                               ; preds = %4
  %11 = getelementptr inbounds nuw i8, ptr %6, i16 1
  %12 = load i8, ptr %11, align 1, !tbaa !6
  switch i8 %12, label %58 [
    i8 117, label %13
    i8 100, label %20
    i8 120, label %34
    i8 37, label %56
  ]

13:                                               ; preds = %10
  %14 = load ptr, ptr %3, align 1
  %15 = getelementptr inbounds nuw i8, ptr %14, i16 2
  store ptr %15, ptr %3, align 1
  %16 = load i16, ptr %14, align 1, !tbaa !2
  %17 = call fastcc zeroext i8 @va_fmt_u(ptr noundef %5, i16 noundef %16) #16
  %18 = zext i8 %17 to i16
  %19 = getelementptr inbounds nuw i8, ptr %5, i16 %18
  br label %62

20:                                               ; preds = %10
  %21 = load ptr, ptr %3, align 1
  %22 = getelementptr inbounds nuw i8, ptr %21, i16 2
  store ptr %22, ptr %3, align 1
  %23 = load i16, ptr %21, align 1, !tbaa !2
  %24 = icmp slt i16 %23, 0
  br i1 %24, label %25, label %28

25:                                               ; preds = %20
  %26 = getelementptr inbounds nuw i8, ptr %5, i16 1
  store i8 45, ptr %5, align 1, !tbaa !6
  %27 = sub nsw i16 0, %23
  br label %28

28:                                               ; preds = %25, %20
  %29 = phi ptr [ %26, %25 ], [ %5, %20 ]
  %30 = phi i16 [ %27, %25 ], [ %23, %20 ]
  %31 = call fastcc zeroext i8 @va_fmt_u(ptr noundef %29, i16 noundef %30) #16
  %32 = zext i8 %31 to i16
  %33 = getelementptr inbounds nuw i8, ptr %29, i16 %32
  br label %62

34:                                               ; preds = %10
  %35 = load ptr, ptr %3, align 1
  %36 = getelementptr inbounds nuw i8, ptr %35, i16 2
  store ptr %36, ptr %3, align 1
  %37 = load i16, ptr %35, align 1, !tbaa !2
  %38 = lshr i16 %37, 12
  %39 = getelementptr inbounds nuw i8, ptr @va_fmt_x.HEX, i16 %38
  %40 = load i8, ptr %39, align 1, !tbaa !6
  store i8 %40, ptr %5, align 1, !tbaa !6
  %41 = lshr i16 %37, 8
  %42 = and i16 %41, 15
  %43 = getelementptr inbounds nuw i8, ptr @va_fmt_x.HEX, i16 %42
  %44 = load i8, ptr %43, align 1, !tbaa !6
  %45 = getelementptr inbounds nuw i8, ptr %5, i16 1
  store i8 %44, ptr %45, align 1, !tbaa !6
  %46 = lshr i16 %37, 4
  %47 = and i16 %46, 15
  %48 = getelementptr inbounds nuw i8, ptr @va_fmt_x.HEX, i16 %47
  %49 = load i8, ptr %48, align 1, !tbaa !6
  %50 = getelementptr inbounds nuw i8, ptr %5, i16 2
  store i8 %49, ptr %50, align 1, !tbaa !6
  %51 = and i16 %37, 15
  %52 = getelementptr inbounds nuw i8, ptr @va_fmt_x.HEX, i16 %51
  %53 = load i8, ptr %52, align 1, !tbaa !6
  %54 = getelementptr inbounds nuw i8, ptr %5, i16 3
  store i8 %53, ptr %54, align 1, !tbaa !6
  %55 = getelementptr inbounds nuw i8, ptr %5, i16 4
  br label %62

56:                                               ; preds = %10
  %57 = getelementptr inbounds nuw i8, ptr %5, i16 1
  store i8 37, ptr %5, align 1, !tbaa !6
  br label %62

58:                                               ; preds = %10
  %59 = getelementptr inbounds nuw i8, ptr %5, i16 1
  store i8 37, ptr %5, align 1, !tbaa !6
  %60 = load i8, ptr %11, align 1, !tbaa !6
  %61 = getelementptr inbounds nuw i8, ptr %5, i16 2
  store i8 %60, ptr %59, align 1, !tbaa !6
  br label %62

62:                                               ; preds = %13, %28, %34, %56, %58, %8
  %63 = phi ptr [ %9, %8 ], [ %61, %58 ], [ %19, %13 ], [ %33, %28 ], [ %55, %34 ], [ %57, %56 ]
  %64 = phi ptr [ %6, %8 ], [ %11, %58 ], [ %11, %13 ], [ %11, %28 ], [ %11, %34 ], [ %11, %56 ]
  %65 = getelementptr inbounds nuw i8, ptr %64, i16 1
  br label %4, !llvm.loop !132

66:                                               ; preds = %4
  store i8 0, ptr %5, align 1, !tbaa !6
  call void @llvm.va_end.p0(ptr nonnull %3)
  call void @llvm.lifetime.end.p0(ptr nonnull %3) #17
  ret void
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn
declare void @llvm.va_start.p0(ptr) #8

; Function Attrs: nofree norecurse nosync nounwind optsize memory(argmem: write)
define internal fastcc zeroext i8 @va_fmt_u(ptr noundef nonnull writeonly captures(none) %0, i16 noundef %1) unnamed_addr #9 {
  %3 = alloca [5 x i8], align 1
  call void @llvm.lifetime.start.p0(ptr nonnull %3) #17
  %4 = icmp eq i16 %1, 0
  br i1 %4, label %5, label %8

5:                                                ; preds = %2
  store i8 48, ptr %0, align 1, !tbaa !6
  br label %31

6:                                                ; preds = %8
  %7 = icmp eq i8 %15, 0
  br i1 %7, label %31, label %21

8:                                                ; preds = %2, %8
  %9 = phi i8 [ %20, %8 ], [ 1, %2 ]
  %10 = phi i8 [ %15, %8 ], [ 0, %2 ]
  %11 = phi i16 [ %18, %8 ], [ %1, %2 ]
  %12 = urem i16 %11, 10
  %13 = trunc nuw nsw i16 %12 to i8
  %14 = or disjoint i8 %13, 48
  %15 = add i8 %10, 1
  %16 = zext i8 %10 to i16
  %17 = getelementptr inbounds nuw i8, ptr %3, i16 %16
  store i8 %14, ptr %17, align 1, !tbaa !6
  %18 = udiv i16 %11, 10
  %19 = icmp ult i16 %11, 10
  %20 = add i8 %9, 1
  br i1 %19, label %6, label %8, !llvm.loop !133

21:                                               ; preds = %6, %21
  %22 = phi i8 [ %29, %21 ], [ 0, %6 ]
  %23 = sub i8 %10, %22
  %24 = zext i8 %23 to i16
  %25 = getelementptr inbounds nuw i8, ptr %3, i16 %24
  %26 = load i8, ptr %25, align 1, !tbaa !6
  %27 = zext i8 %22 to i16
  %28 = getelementptr i8, ptr %0, i16 %27
  store i8 %26, ptr %28, align 1, !tbaa !6
  %29 = add nuw i8 %22, 1
  %30 = icmp eq i8 %29, %9
  br i1 %30, label %31, label %21, !llvm.loop !134

31:                                               ; preds = %21, %6, %5
  %32 = phi i8 [ 1, %5 ], [ 0, %6 ], [ %15, %21 ]
  call void @llvm.lifetime.end.p0(ptr nonnull %3) #17
  ret i8 %32
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn
declare void @llvm.va_end.p0(ptr) #8

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc void @canvas_line(i16 noundef %0, i16 noundef %1, i16 noundef %2, i16 noundef %3) unnamed_addr #10 {
  %5 = icmp sgt i16 %2, %0
  br i1 %5, label %6, label %8

6:                                                ; preds = %4
  %7 = sub nsw i16 %2, %0
  br label %10

8:                                                ; preds = %4
  %9 = sub nsw i16 %0, %2
  br label %10

10:                                               ; preds = %8, %6
  %11 = phi i16 [ %7, %6 ], [ %9, %8 ]
  %12 = icmp sgt i16 %3, %1
  br i1 %12, label %13, label %15

13:                                               ; preds = %10
  %14 = sub nsw i16 %3, %1
  br label %17

15:                                               ; preds = %10
  %16 = sub nsw i16 %1, %3
  br label %17

17:                                               ; preds = %15, %13
  %18 = phi i16 [ 1, %13 ], [ -1, %15 ]
  %19 = phi i16 [ %14, %13 ], [ %16, %15 ]
  %20 = select i1 %5, i16 1, i16 -1
  %21 = sub nsw i16 %11, %19
  %22 = sub nsw i16 0, %19
  br label %23

23:                                               ; preds = %69, %17
  %24 = phi i16 [ %71, %69 ], [ %1, %17 ]
  %25 = phi i16 [ %70, %69 ], [ %21, %17 ]
  %26 = phi i16 [ %67, %69 ], [ %0, %17 ]
  %27 = icmp ugt i16 %24, 127
  %28 = shl nuw nsw i16 %24, 1
  %29 = and i16 %28, 240
  %30 = and i16 %28, 14
  %31 = getelementptr inbounds i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 199), i16 %30
  %32 = icmp eq i16 %24, %3
  br label %33

33:                                               ; preds = %23, %65
  %34 = phi i16 [ %66, %65 ], [ %25, %23 ]
  %35 = phi i16 [ %67, %65 ], [ %26, %23 ]
  %36 = icmp ugt i16 %35, 127
  %37 = select i1 %36, i1 true, i1 %27
  br i1 %37, label %56, label %38

38:                                               ; preds = %33
  %39 = lshr i16 %35, 3
  %40 = or disjoint i16 %39, %29
  %41 = shl nuw nsw i16 %40, 4
  %42 = getelementptr inbounds i8, ptr %31, i16 %41
  %43 = and i16 %35, 7
  %44 = lshr exact i16 128, %43
  %45 = trunc nuw i16 %44 to i8
  %46 = getelementptr inbounds nuw i8, ptr %42, i16 1
  %47 = load i8, ptr %46, align 1, !tbaa !6
  %48 = or i8 %47, %45
  store i8 %48, ptr %46, align 1, !tbaa !6
  %49 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4295), align 1, !tbaa !24
  %50 = icmp ult i16 %40, %49
  br i1 %50, label %51, label %52

51:                                               ; preds = %38
  store i16 %40, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4295), align 1, !tbaa !24
  br label %52

52:                                               ; preds = %51, %38
  %53 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4297), align 1, !tbaa !25
  %54 = icmp ugt i16 %40, %53
  br i1 %54, label %55, label %56

55:                                               ; preds = %52
  store i16 %40, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 4297), align 1, !tbaa !25
  br label %56

56:                                               ; preds = %33, %52, %55
  %57 = icmp eq i16 %35, %2
  %58 = select i1 %57, i1 %32, i1 false
  br i1 %58, label %72, label %59

59:                                               ; preds = %56
  %60 = shl nsw i16 %34, 1
  %61 = icmp sgt i16 %60, %22
  br i1 %61, label %62, label %65

62:                                               ; preds = %59
  %63 = sub nsw i16 %34, %19
  %64 = add nsw i16 %35, %20
  br label %65

65:                                               ; preds = %62, %59
  %66 = phi i16 [ %63, %62 ], [ %34, %59 ]
  %67 = phi i16 [ %64, %62 ], [ %35, %59 ]
  %68 = icmp slt i16 %60, %11
  br i1 %68, label %69, label %33

69:                                               ; preds = %65
  %70 = add nsw i16 %66, %11
  %71 = add nsw i16 %24, %18
  br label %23

72:                                               ; preds = %56
  ret void
}

; Function Attrs: nofree noinline norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal fastcc void @upq_flush() unnamed_addr #11 {
  %1 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 177), align 1, !tbaa !135
  %2 = zext i8 %1 to i16
  %3 = shl nuw nsw i16 %2, 4
  %4 = add nuw nsw i16 %3, 17152
  %5 = inttoptr i16 %4 to ptr
  %6 = shl nuw i16 1, %2
  %7 = trunc i16 %6 to i8
  %8 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !44
  %9 = icmp eq i8 %8, 0
  br i1 %9, label %108, label %10

10:                                               ; preds = %0
  %11 = getelementptr inbounds nuw i8, ptr %5, i16 1
  %12 = getelementptr inbounds nuw i8, ptr %5, i16 2
  %13 = getelementptr inbounds nuw i8, ptr %5, i16 3
  %14 = getelementptr inbounds nuw i8, ptr %5, i16 4
  %15 = getelementptr inbounds nuw i8, ptr %5, i16 5
  %16 = getelementptr inbounds nuw i8, ptr %5, i16 6
  br label %17

17:                                               ; preds = %10, %86
  %18 = phi i8 [ %8, %10 ], [ %89, %86 ]
  %19 = phi i16 [ 0, %10 ], [ %87, %86 ]
  %20 = phi i8 [ 0, %10 ], [ %88, %86 ]
  %21 = zext i8 %20 to i16
  %22 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %21
  %23 = getelementptr inbounds nuw i8, ptr %22, i16 10
  %24 = load i8, ptr %23, align 1, !tbaa !45
  switch i8 %24, label %44 [
    i8 3, label %25
    i8 4, label %34
  ]

25:                                               ; preds = %17
  %26 = load i16, ptr %22, align 1, !tbaa !47
  %27 = inttoptr i16 %26 to ptr
  %28 = getelementptr inbounds nuw i8, ptr %22, i16 2
  %29 = load i16, ptr %28, align 1, !tbaa !51
  %30 = trunc i16 %29 to i8
  store volatile i8 %30, ptr %27, align 1, !tbaa !6
  %31 = load i16, ptr %28, align 1, !tbaa !51
  %32 = lshr i16 %31, 8
  %33 = trunc nuw i16 %32 to i8
  store volatile i8 %33, ptr %27, align 1, !tbaa !6
  br label %86

34:                                               ; preds = %17
  %35 = load i16, ptr %22, align 1, !tbaa !47
  %36 = inttoptr i16 %35 to ptr
  %37 = getelementptr inbounds nuw i8, ptr %22, i16 2
  %38 = load i16, ptr %37, align 1, !tbaa !51
  %39 = trunc i16 %38 to i8
  store volatile i8 %39, ptr %36, align 1, !tbaa !6
  %40 = load i16, ptr %37, align 1, !tbaa !51
  %41 = lshr i16 %40, 8
  %42 = trunc nuw i16 %41 to i8
  %43 = getelementptr inbounds nuw i8, ptr %36, i16 1
  store volatile i8 %42, ptr %43, align 1, !tbaa !6
  br label %86

44:                                               ; preds = %17
  %45 = icmp eq i16 %19, 0
  br i1 %45, label %51, label %46

46:                                               ; preds = %44
  %47 = getelementptr inbounds nuw i8, ptr %22, i16 4
  %48 = load i16, ptr %47, align 1, !tbaa !53
  %49 = add i16 %48, %19
  %50 = icmp ugt i16 %49, 5100
  br i1 %50, label %91, label %51

51:                                               ; preds = %46, %44
  switch i8 %24, label %59 [
    i8 0, label %52
    i8 1, label %56
  ]

52:                                               ; preds = %51
  %53 = getelementptr inbounds nuw i8, ptr %22, i16 9
  %54 = load i8, ptr %53, align 1, !tbaa !48
  store volatile i8 %54, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  %55 = load i16, ptr %22, align 1, !tbaa !47
  store volatile i16 %55, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %65

56:                                               ; preds = %51
  %57 = load i16, ptr %22, align 1, !tbaa !47
  %58 = trunc i16 %57 to i8
  store volatile i8 %58, ptr inttoptr (i16 8481 to ptr), align 1, !tbaa !6
  br label %65

59:                                               ; preds = %51
  %60 = load i16, ptr %22, align 1, !tbaa !47
  %61 = trunc i16 %60 to i8
  store volatile i8 %61, ptr inttoptr (i16 8450 to ptr), align 2, !tbaa !6
  %62 = load i16, ptr %22, align 1, !tbaa !47
  %63 = lshr i16 %62, 8
  %64 = trunc nuw i16 %63 to i8
  store volatile i8 %64, ptr inttoptr (i16 8451 to ptr), align 1, !tbaa !6
  br label %65

65:                                               ; preds = %56, %59, %52
  %66 = getelementptr inbounds nuw i8, ptr %22, i16 8
  %67 = load i8, ptr %66, align 1, !tbaa !50
  store volatile i8 %67, ptr %5, align 16, !tbaa !6
  %68 = getelementptr inbounds nuw i8, ptr %22, i16 7
  %69 = load i8, ptr %68, align 1, !tbaa !49
  store volatile i8 %69, ptr %11, align 1, !tbaa !6
  %70 = getelementptr inbounds nuw i8, ptr %22, i16 2
  %71 = load i16, ptr %70, align 1, !tbaa !51
  %72 = trunc i16 %71 to i8
  store volatile i8 %72, ptr %12, align 2, !tbaa !6
  %73 = load i16, ptr %70, align 1, !tbaa !51
  %74 = lshr i16 %73, 8
  %75 = trunc nuw i16 %74 to i8
  store volatile i8 %75, ptr %13, align 1, !tbaa !6
  %76 = getelementptr inbounds nuw i8, ptr %22, i16 6
  %77 = load i8, ptr %76, align 1, !tbaa !52
  store volatile i8 %77, ptr %14, align 4, !tbaa !6
  %78 = getelementptr inbounds nuw i8, ptr %22, i16 4
  %79 = load i16, ptr %78, align 1, !tbaa !53
  %80 = trunc i16 %79 to i8
  store volatile i8 %80, ptr %15, align 1, !tbaa !6
  %81 = load i16, ptr %78, align 1, !tbaa !53
  %82 = lshr i16 %81, 8
  %83 = trunc nuw i16 %82 to i8
  store volatile i8 %83, ptr %16, align 2, !tbaa !6
  store volatile i8 %7, ptr inttoptr (i16 16907 to ptr), align 1, !tbaa !6
  %84 = load i16, ptr %78, align 1, !tbaa !53
  %85 = add i16 %84, %19
  br label %86

86:                                               ; preds = %65, %34, %25
  %87 = phi i16 [ %19, %25 ], [ %19, %34 ], [ %85, %65 ]
  %88 = add nuw i8 %20, 1
  %89 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !44
  %90 = icmp ult i8 %88, %89
  br i1 %90, label %17, label %91

91:                                               ; preds = %86, %46
  %92 = phi i8 [ %89, %86 ], [ %18, %46 ]
  %93 = phi i8 [ %88, %86 ], [ %20, %46 ]
  %94 = icmp ult i8 %93, %92
  br i1 %94, label %95, label %108

95:                                               ; preds = %91
  %96 = icmp eq i8 %93, 0
  br i1 %96, label %110, label %97

97:                                               ; preds = %95, %97
  %98 = phi i8 [ %101, %97 ], [ 0, %95 ]
  %99 = phi i8 [ %104, %97 ], [ %93, %95 ]
  %100 = zext i8 %99 to i16
  %101 = add i8 %98, 1
  %102 = zext i8 %98 to i16
  %103 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %102
  %104 = add nuw i8 %99, 1
  %105 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %100
  tail call void @llvm.memcpy.p0.p0.i16(ptr noundef nonnull align 1 dereferenceable(11) %103, ptr noundef nonnull align 1 dereferenceable(11) %105, i16 11, i1 false), !tbaa.struct !136
  %106 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !44
  %107 = icmp ult i8 %104, %106
  br i1 %107, label %97, label %108, !llvm.loop !137

108:                                              ; preds = %97, %91, %0
  %109 = phi i8 [ 0, %91 ], [ 0, %0 ], [ %101, %97 ]
  store i8 %109, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !44
  br label %110

110:                                              ; preds = %108, %95
  ret void
}

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i16(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i16, i1 immarg) #12

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #13

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #14

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i16(ptr writeonly captures(none), i8, i16, i1 immarg) #14

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #1 = { nofree norecurse nosync nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #2 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { nofree noinline norecurse nosync nounwind optsize memory(readwrite, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #4 = { nofree norecurse nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #5 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #6 = { nofree norecurse nosync nounwind optsize memory(argmem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #7 = { nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #8 = { mustprogress nocallback nofree nosync nounwind willreturn }
attributes #9 = { nofree norecurse nosync nounwind optsize memory(argmem: write) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #10 = { nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #11 = { nofree noinline norecurse nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8"  }
attributes #12 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #13 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #14 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #15 = { nounwind optsize }
attributes #16 = { optsize }
attributes #17 = { nounwind }

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
!9 = !{!10, !4, i64 194}
!10 = !{!"", !11, i64 0, !12, i64 178, !13, i64 182, !4, i64 191, !4, i64 192, !4, i64 193, !4, i64 194, !4, i64 195}
!11 = !{!"", !4, i64 0, !4, i64 176, !4, i64 177}
!12 = !{!"", !3, i64 0, !3, i64 2}
!13 = !{!"", !4, i64 0, !4, i64 8}
!14 = !{!10, !4, i64 195}
!15 = !{!16, !18, i64 0}
!16 = !{!"", !17, i64 0, !4, i64 3, !3, i64 4099, !3, i64 4101, !3, i64 4103, !3, i64 4105, !4, i64 4107, !4, i64 4108}
!17 = !{!"Drawable", !18, i64 0, !4, i64 2}
!18 = !{!"any pointer", !4, i64 0}
!19 = !{!16, !4, i64 2}
!20 = !{!16, !3, i64 4103}
!21 = !{!16, !3, i64 4105}
!22 = !{!16, !4, i64 4107}
!23 = !{!16, !4, i64 4108}
!24 = !{!16, !3, i64 4099}
!25 = !{!16, !3, i64 4101}
!26 = !{!27, !18, i64 0}
!27 = !{!"", !17, i64 0, !3, i64 3, !4, i64 5, !4, i64 7, !4, i64 135}
!28 = !{!27, !4, i64 2}
!29 = !{!27, !3, i64 3}
!30 = distinct !{!30, !8}
!31 = !{!27, !4, i64 135}
!32 = !{!10, !4, i64 192}
!33 = !{!10, !4, i64 193}
!34 = !{!13, !4, i64 8}
!35 = !{!36, !36, i64 0}
!36 = !{!"p1 _ZTS8Drawable", !18, i64 0}
!37 = distinct !{null, null}
!38 = !{!10, !4, i64 191}
!39 = !{!17, !4, i64 2}
!40 = !{!17, !18, i64 0}
!41 = !{!42, !18, i64 0}
!42 = !{!"", !18, i64 0, !18, i64 2}
!43 = distinct !{null, null, null}
!44 = !{!11, !4, i64 176}
!45 = !{!46, !4, i64 10}
!46 = !{!"", !3, i64 0, !3, i64 2, !3, i64 4, !4, i64 6, !4, i64 7, !4, i64 8, !4, i64 9, !4, i64 10}
!47 = !{!46, !3, i64 0}
!48 = !{!46, !4, i64 9}
!49 = !{!46, !4, i64 7}
!50 = !{!46, !4, i64 8}
!51 = !{!46, !3, i64 2}
!52 = !{!46, !4, i64 6}
!53 = !{!46, !3, i64 4}
!54 = !{!55, !4, i64 4441}
!55 = !{!"", !10, i64 0, !16, i64 196, !27, i64 4305, !4, i64 4441, !3, i64 4442, !3, i64 4444, !3, i64 4446, !3, i64 4448, !4, i64 4450}
!56 = !{!55, !3, i64 4442}
!57 = !{!55, !3, i64 4444}
!58 = !{!55, !4, i64 4450}
!59 = !{!60, !18, i64 0}
!60 = !{!"", !17, i64 0, !61, i64 3, !61, i64 5, !61, i64 7, !61, i64 9, !4, i64 11, !4, i64 12, !3, i64 13, !3, i64 15, !3, i64 17, !3, i64 19, !3, i64 21, !3, i64 23, !4, i64 25, !3, i64 26, !4, i64 28, !4, i64 29, !4, i64 30, !4, i64 31, !4, i64 32, !4, i64 33, !3, i64 34, !3, i64 36, !62, i64 38, !62, i64 89}
!61 = !{!"p1 omnipotent char", !18, i64 0}
!62 = !{!"", !4, i64 0, !4, i64 50}
!63 = !{!60, !4, i64 2}
!64 = !{!60, !61, i64 3}
!65 = !{!60, !61, i64 5}
!66 = !{!60, !61, i64 7}
!67 = !{!60, !4, i64 11}
!68 = !{!60, !61, i64 9}
!69 = !{!60, !4, i64 12}
!70 = !{!60, !3, i64 13}
!71 = !{!60, !3, i64 15}
!72 = !{!60, !3, i64 17}
!73 = !{!60, !4, i64 28}
!74 = !{!60, !4, i64 29}
!75 = !{!60, !4, i64 31}
!76 = !{!60, !4, i64 32}
!77 = !{!60, !4, i64 30}
!78 = !{!60, !4, i64 25}
!79 = !{!60, !3, i64 34}
!80 = !{!60, !3, i64 36}
!81 = !{!60, !4, i64 33}
!82 = !{!42, !18, i64 2}
!83 = distinct !{null, null, null, null, null}
!84 = distinct !{!84, !8}
!85 = distinct !{!85, !8}
!86 = distinct !{!86, !8}
!87 = distinct !{null, null, null, null}
!88 = distinct !{!88, !8}
!89 = distinct !{!89, !8}
!90 = distinct !{!90, !8}
!91 = distinct !{!91, !8}
!92 = distinct !{!92, !8}
!93 = distinct !{null, null, null, null, null}
!94 = distinct !{!94, !8}
!95 = distinct !{!95, !8}
!96 = distinct !{null, null, null, null}
!97 = !{!60, !3, i64 19}
!98 = distinct !{null, null, null, null, null}
!99 = distinct !{null, null, null}
!100 = distinct !{!100, !8}
!101 = distinct !{!101, !8}
!102 = !{!55, !3, i64 4446}
!103 = !{!55, !3, i64 4448}
!104 = distinct !{!104, !8}
!105 = distinct !{!105, !8}
!106 = distinct !{!106, !8}
!107 = distinct !{!107, !8}
!108 = distinct !{!108, !8}
!109 = distinct !{!109, !8}
!110 = distinct !{!110, !8}
!111 = distinct !{!111, !8}
!112 = distinct !{!112, !8}
!113 = distinct !{!113, !8}
!114 = distinct !{!114, !8}
!115 = distinct !{!115, !8}
!116 = distinct !{!116, !8}
!117 = distinct !{!117, !8}
!118 = distinct !{!118, !8}
!119 = distinct !{!119, !8}
!120 = !{!60, !3, i64 21}
!121 = !{!60, !3, i64 23}
!122 = distinct !{!122, !8}
!123 = !{!60, !3, i64 26}
!124 = !{!62, !4, i64 50}
!125 = distinct !{!125, !8}
!126 = distinct !{!126, !8}
!127 = !{!128, !18, i64 0}
!128 = !{!"", !18, i64 0, !4, i64 2}
!129 = !{!128, !4, i64 2}
!130 = distinct !{!130, !8}
!131 = distinct !{!131, !8}
!132 = distinct !{!132, !8}
!133 = distinct !{!133, !8}
!134 = distinct !{!134, !8}
!135 = !{!11, !4, i64 177}
!136 = !{i64 0, i64 2, !2, i64 2, i64 2, !2, i64 4, i64 2, !2, i64 6, i64 1, !6, i64 7, i64 1, !6, i64 8, i64 1, !6, i64 9, i64 1, !6, i64 10, i64 1, !6}
!137 = distinct !{!137, !8}
