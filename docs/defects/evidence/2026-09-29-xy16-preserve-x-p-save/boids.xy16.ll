; ModuleID = '/work/examples/snes/boids.c'
source_filename = "/work/examples/snes/boids.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.App = type { %struct.Display, %struct.SpriteSet, [32 x %struct.Boid], [16 x i16], [8 x [3 x i16]] }
%struct.Display = type { %struct.UploadQueue, %struct.VramAlloc, %struct.Scene, i8, i8, i8, i8, i8 }
%struct.UploadQueue = type { [16 x %struct.UpqJob], i8, i8 }
%struct.UpqJob = type { i16, i16, i16, i8, i8, i8, i8, i8 }
%struct.VramAlloc = type { i16, i16 }
%struct.Scene = type { [4 x ptr], i8 }
%struct.SpriteSet = type { %struct.Drawable, [512 x i8], [32 x i8], i16, i8 }
%struct.Drawable = type { ptr, i8 }
%struct.Boid = type { %struct.vec2, %struct.vec2 }
%struct.vec2 = type { i16, i16 }
%struct.TitleLayer = type { %struct.Drawable, ptr, ptr, ptr, ptr, i8, i8, i16, i16, i16, i16, i16, i16, i8, i16, i8, i8, i8, i8, i8, i8, i16, i16, %struct.HScrollDB, %struct.HScrollDB }
%struct.HScrollDB = type { [2 x %struct.HScrollN], i8 }
%struct.HScrollN = type { [25 x i8] }
%struct.DrawableVT = type { ptr, ptr }
%struct.HScrollW = type { ptr, i8 }

@main.a = internal global %struct.App zeroinitializer, align 1
@main.title = internal global %struct.TitleLayer zeroinitializer, align 1
@.str = private unnamed_addr constant [6 x i8] c"BOIDS\00", align 1
@.str.1 = private unnamed_addr constant [16 x i8] c"STRUCT-BY-VALUE\00", align 1
@corpus_result = dso_local global i16 0, align 1
@BOID_PIX = internal unnamed_addr constant [64 x i8] c"\00\00\00\01\01\00\00\00\00\00\01\01\01\01\00\00\00\01\01\01\01\01\01\00\01\01\01\02\02\01\01\01\01\01\01\02\02\01\01\01\00\01\01\01\01\01\01\00\00\00\01\01\01\01\00\00\00\00\00\01\01\00\00\00", align 1
@HUE5 = internal unnamed_addr constant [8 x [3 x i8]] [[3 x i8] c"\1F\00\00", [3 x i8] c"\1F\10\00", [3 x i8] c"\1F\1F\00", [3 x i8] c"\00\1F\00", [3 x i8] c"\00\1F\1F", [3 x i8] c"\00\08\1F", [3 x i8] c"\14\00\1F", [3 x i8] c"\1F\00\18"], align 1
@SPRITE_VT = internal constant %struct.DrawableVT { ptr @_sprite_reserve, ptr @_sprite_emit }, align 1
@TITLE_VT = internal constant %struct.DrawableVT { ptr @_title_reserve, ptr @_title_emit }, align 1
@FONT8 = internal unnamed_addr constant [512 x i16] [i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 32, i16 32, i16 32, i16 32, i16 32, i16 0, i16 32, i16 0, i16 80, i16 80, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 80, i16 80, i16 248, i16 80, i16 248, i16 80, i16 80, i16 0, i16 32, i16 120, i16 160, i16 112, i16 40, i16 240, i16 32, i16 0, i16 196, i16 200, i16 16, i16 32, i16 64, i16 152, i16 12, i16 0, i16 96, i16 144, i16 160, i16 64, i16 168, i16 144, i16 104, i16 0, i16 32, i16 32, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 16, i16 32, i16 64, i16 64, i16 64, i16 32, i16 16, i16 0, i16 64, i16 32, i16 16, i16 16, i16 16, i16 32, i16 64, i16 0, i16 0, i16 32, i16 168, i16 112, i16 168, i16 32, i16 0, i16 0, i16 0, i16 32, i16 32, i16 248, i16 32, i16 32, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 96, i16 96, i16 64, i16 0, i16 0, i16 0, i16 248, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 96, i16 96, i16 0, i16 8, i16 8, i16 16, i16 32, i16 64, i16 128, i16 128, i16 0, i16 112, i16 136, i16 152, i16 168, i16 200, i16 136, i16 112, i16 0, i16 32, i16 96, i16 32, i16 32, i16 32, i16 32, i16 112, i16 0, i16 112, i16 136, i16 8, i16 16, i16 32, i16 64, i16 248, i16 0, i16 112, i16 136, i16 8, i16 48, i16 8, i16 136, i16 112, i16 0, i16 16, i16 48, i16 80, i16 144, i16 248, i16 16, i16 16, i16 0, i16 248, i16 128, i16 240, i16 8, i16 8, i16 136, i16 112, i16 0, i16 112, i16 136, i16 128, i16 240, i16 136, i16 136, i16 112, i16 0, i16 248, i16 8, i16 16, i16 32, i16 64, i16 64, i16 64, i16 0, i16 112, i16 136, i16 136, i16 112, i16 136, i16 136, i16 112, i16 0, i16 112, i16 136, i16 136, i16 120, i16 8, i16 136, i16 112, i16 0, i16 0, i16 32, i16 32, i16 0, i16 32, i16 32, i16 0, i16 0, i16 0, i16 32, i16 32, i16 0, i16 32, i16 32, i16 64, i16 0, i16 16, i16 32, i16 64, i16 128, i16 64, i16 32, i16 16, i16 0, i16 0, i16 0, i16 248, i16 0, i16 248, i16 0, i16 0, i16 0, i16 128, i16 64, i16 32, i16 16, i16 32, i16 64, i16 128, i16 0, i16 112, i16 136, i16 8, i16 16, i16 32, i16 0, i16 32, i16 0, i16 112, i16 136, i16 184, i16 168, i16 184, i16 128, i16 112, i16 0, i16 112, i16 136, i16 136, i16 248, i16 136, i16 136, i16 136, i16 0, i16 240, i16 136, i16 136, i16 240, i16 136, i16 136, i16 240, i16 0, i16 112, i16 136, i16 128, i16 128, i16 128, i16 136, i16 112, i16 0, i16 224, i16 144, i16 136, i16 136, i16 136, i16 144, i16 224, i16 0, i16 248, i16 128, i16 128, i16 240, i16 128, i16 128, i16 248, i16 0, i16 248, i16 128, i16 128, i16 240, i16 128, i16 128, i16 128, i16 0, i16 112, i16 136, i16 128, i16 176, i16 136, i16 136, i16 112, i16 0, i16 136, i16 136, i16 136, i16 248, i16 136, i16 136, i16 136, i16 0, i16 112, i16 32, i16 32, i16 32, i16 32, i16 32, i16 112, i16 0, i16 56, i16 16, i16 16, i16 16, i16 144, i16 144, i16 96, i16 0, i16 136, i16 144, i16 160, i16 192, i16 160, i16 144, i16 136, i16 0, i16 128, i16 128, i16 128, i16 128, i16 128, i16 128, i16 248, i16 0, i16 136, i16 216, i16 168, i16 136, i16 136, i16 136, i16 136, i16 0, i16 136, i16 200, i16 168, i16 152, i16 136, i16 136, i16 136, i16 0, i16 112, i16 136, i16 136, i16 136, i16 136, i16 136, i16 112, i16 0, i16 240, i16 136, i16 136, i16 240, i16 128, i16 128, i16 128, i16 0, i16 112, i16 136, i16 136, i16 136, i16 168, i16 144, i16 104, i16 0, i16 240, i16 136, i16 136, i16 240, i16 160, i16 144, i16 136, i16 0, i16 112, i16 136, i16 128, i16 112, i16 8, i16 136, i16 112, i16 0, i16 248, i16 32, i16 32, i16 32, i16 32, i16 32, i16 32, i16 0, i16 136, i16 136, i16 136, i16 136, i16 136, i16 136, i16 112, i16 0, i16 136, i16 136, i16 136, i16 136, i16 136, i16 80, i16 32, i16 0, i16 136, i16 136, i16 136, i16 168, i16 168, i16 216, i16 136, i16 0, i16 136, i16 136, i16 80, i16 32, i16 80, i16 136, i16 136, i16 0, i16 136, i16 136, i16 80, i16 32, i16 32, i16 32, i16 32, i16 0, i16 248, i16 8, i16 16, i16 32, i16 64, i16 128, i16 248, i16 0, i16 48, i16 32, i16 32, i16 32, i16 32, i16 32, i16 48, i16 0, i16 128, i16 128, i16 64, i16 32, i16 16, i16 8, i16 8, i16 0, i16 48, i16 16, i16 16, i16 16, i16 16, i16 16, i16 48, i16 0, i16 32, i16 80, i16 136, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 248], align 1
@FONT16 = internal unnamed_addr constant [2048 x i16] [i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 15, i16 15, i16 15, i16 15, i16 15, i16 192, i16 192, i16 12480, i16 12480, i16 12480, i16 12480, i16 12480, i16 12480, i16 15, i16 768, i16 768, i16 15, i16 15, i16 15, i16 768, i16 768, i16 12480, i16 -4096, i16 -4096, i16 192, i16 192, i16 12480, i16 -4096, i16 -4096, i16 60, i16 60, i16 828, i16 828, i16 3840, i16 3840, i16 0, i16 0, i16 240, i16 240, i16 3312, i16 3312, i16 15360, i16 15360, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 28, i16 28, i16 796, i16 127, i16 127, i16 796, i16 796, i16 127, i16 112, i16 112, i16 3184, i16 252, i16 252, i16 -28816, i16 -28816, i16 252, i16 127, i16 796, i16 796, i16 796, i16 1792, i16 1792, i16 0, i16 0, i16 252, i16 -28816, i16 -28816, i16 3184, i16 7168, i16 7168, i16 0, i16 0, i16 3, i16 63, i16 123, i16 1147, i16 63, i16 4111, i16 3075, i16 123, i16 192, i16 248, i16 8414, i16 16064, i16 2040, i16 248, i16 8414, i16 8414, i16 63, i16 7171, i16 3840, i16 0, i16 0, i16 0, i16 0, i16 0, i16 2040, i16 14272, i16 -512, i16 -4096, i16 0, i16 0, i16 0, i16 0, i16 60, i16 60, i16 828, i16 828, i16 3840, i16 3585, i16 3, i16 7, i16 28, i16 56, i16 1904, i16 3808, i16 7392, i16 14528, i16 14464, i16 28672, i16 14, i16 284, i16 824, i16 1792, i16 3584, i16 0, i16 0, i16 0, i16 -8162, i16 -16354, i16 -32482, i16 286, i16 1792, i16 1792, i16 0, i16 0, i16 15, i16 31, i16 828, i16 828, i16 573, i16 31, i16 31, i16 63, i16 192, i16 224, i16 240, i16 2288, i16 7392, i16 15488, i16 30720, i16 -32648, i16 382, i16 3060, i16 3825, i16 1275, i16 127, i16 63, i16 7936, i16 3840, i16 248, i16 3824, i16 7904, i16 7392, i16 4332, i16 12492, i16 -1280, i16 -3328, i16 15, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 -16384, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 3, i16 7, i16 15, i16 15, i16 15, i16 15, i16 15, i16 240, i16 192, i16 15488, i16 -4096, i16 -8192, i16 -16384, i16 -16384, i16 -16384, i16 15, i16 7, i16 3, i16 256, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 16512, i16 192, i16 240, i16 -4096, i16 15360, i16 0, i16 0, i16 15, i16 3, i16 513, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 192, i16 224, i16 240, i16 2288, i16 3312, i16 3312, i16 3312, i16 0, i16 1, i16 3, i16 15, i16 0, i16 768, i16 0, i16 0, i16 3312, i16 7392, i16 15552, i16 30720, i16 -4096, i16 -16384, i16 0, i16 0, i16 0, i16 0, i16 3, i16 3, i16 51, i16 31, i16 15, i16 1027, i16 0, i16 0, i16 192, i16 192, i16 12492, i16 252, i16 1016, i16 16320, i16 15, i16 31, i16 51, i16 1027, i16 3072, i16 0, i16 0, i16 0, i16 1784, i16 252, i16 13004, i16 16320, i16 -3328, i16 -4096, i16 0, i16 0, i16 0, i16 0, i16 0, i16 3, i16 3, i16 3, i16 63, i16 63, i16 0, i16 0, i16 0, i16 192, i16 192, i16 12480, i16 248, i16 248, i16 63, i16 3075, i16 3075, i16 3, i16 0, i16 0, i16 0, i16 0, i16 1784, i16 16064, i16 16064, i16 12480, i16 -4096, i16 -4096, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 15, i16 286, i16 828, i16 0, i16 0, i16 192, i16 192, i16 12480, i16 28800, i16 -4096, i16 -8192, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 63, i16 63, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 248, i16 248, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 0, i16 0, i16 0, i16 1784, i16 -512, i16 -512, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 192, i16 192, i16 12480, i16 -4096, i16 -4096, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 1, i16 3, i16 7, i16 14, i16 284, i16 824, i16 1904, i16 3808, i16 7360, i16 14464, i16 7, i16 14, i16 284, i16 824, i16 1904, i16 3808, i16 7168, i16 14336, i16 28672, i16 -8192, i16 -16384, i16 -32768, i16 0, i16 0, i16 0, i16 0, i16 15, i16 31, i16 318, i16 828, i16 828, i16 828, i16 828, i16 828, i16 252, i16 254, i16 -8161, i16 -4081, i16 -32753, i16 15, i16 15, i16 15, i16 828, i16 828, i16 828, i16 318, i16 31, i16 15, i16 1792, i16 768, i16 15, i16 15, i16 15, i16 31, i16 510, i16 1020, i16 -256, i16 -256, i16 1, i16 3, i16 15, i16 15, i16 513, i16 513, i16 1, i16 1, i16 240, i16 240, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 1, i16 1, i16 1, i16 1, i16 1, i16 1, i16 0, i16 0, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 31744, i16 31744, i16 15, i16 31, i16 318, i16 828, i16 3840, i16 3840, i16 3, i16 15, i16 252, i16 254, i16 -8161, i16 -4081, i16 -32753, i16 63, i16 510, i16 4080, i16 31, i16 318, i16 318, i16 318, i16 63, i16 63, i16 3840, i16 3840, i16 32640, i16 -1024, i16 -8192, i16 -32768, i16 255, i16 255, i16 -256, i16 -256, i16 15, i16 63, i16 824, i16 3840, i16 2055, i16 7, i16 256, i16 256, i16 252, i16 254, i16 -8161, i16 -4081, i16 510, i16 1020, i16 -7906, i16 -4081, i16 0, i16 0, i16 56, i16 60, i16 63, i16 31, i16 3840, i16 1792, i16 15, i16 15, i16 15, i16 31, i16 510, i16 1020, i16 -256, i16 -256, i16 0, i16 0, i16 0, i16 1, i16 3, i16 7, i16 15, i16 286, i16 62, i16 126, i16 510, i16 510, i16 8670, i16 24990, i16 -7906, i16 -7906, i16 828, i16 828, i16 63, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 -16098, i16 -32482, i16 255, i16 255, i16 -7906, i16 -7906, i16 1792, i16 1792, i16 31, i16 63, i16 828, i16 828, i16 63, i16 31, i16 3840, i16 1792, i16 254, i16 254, i16 -256, i16 -256, i16 252, i16 254, i16 -8161, i16 -4081, i16 0, i16 0, i16 60, i16 62, i16 31, i16 15, i16 1792, i16 768, i16 15, i16 15, i16 15, i16 31, i16 510, i16 1020, i16 -256, i16 -256, i16 15, i16 31, i16 318, i16 828, i16 63, i16 63, i16 318, i16 828, i16 254, i16 255, i16 -2041, i16 -256, i16 508, i16 254, i16 -4081, i16 -2041, i16 828, i16 828, i16 828, i16 318, i16 31, i16 15, i16 1792, i16 768, i16 -32761, i16 7, i16 7, i16 15, i16 510, i16 1020, i16 -256, i16 -256, i16 63, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 0, i16 0, i16 255, i16 255, i16 -4081, i16 -4081, i16 15, i16 31, i16 318, i16 892, i16 0, i16 1, i16 3, i16 7, i16 7, i16 7, i16 256, i16 256, i16 2040, i16 4080, i16 7904, i16 15552, i16 30848, i16 28800, i16 -8192, i16 -8192, i16 15, i16 31, i16 828, i16 828, i16 828, i16 31, i16 15, i16 796, i16 252, i16 254, i16 -4081, i16 -4081, i16 15, i16 510, i16 1020, i16 -3826, i16 828, i16 828, i16 828, i16 828, i16 31, i16 15, i16 1792, i16 768, i16 -4081, i16 15, i16 15, i16 15, i16 510, i16 1020, i16 -256, i16 -256, i16 15, i16 31, i16 318, i16 828, i16 828, i16 828, i16 828, i16 318, i16 252, i16 254, i16 -8161, i16 -4081, i16 -32753, i16 15, i16 15, i16 31, i16 31, i16 15, i16 1792, i16 768, i16 0, i16 0, i16 0, i16 0, i16 255, i16 255, i16 -4081, i16 -4081, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 0, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 0, i16 0, i16 0, i16 0, i16 0, i16 15, i16 15, i16 15, i16 768, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 0, i16 15, i16 15, i16 15, i16 270, i16 796, i16 824, i16 1792, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 -16384, i16 -32768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 3, i16 15, i16 60, i16 828, i16 0, i16 0, i16 60, i16 240, i16 4032, i16 15360, i16 -4096, i16 -16384, i16 15, i16 3075, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 192, i16 240, i16 -16324, i16 15360, i16 3840, i16 0, i16 0, i16 0, i16 0, i16 0, i16 63, i16 63, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 0, i16 240, i16 240, i16 3312, i16 -1024, i16 -1024, i16 63, i16 63, i16 63, i16 3840, i16 3840, i16 0, i16 0, i16 0, i16 240, i16 240, i16 3312, i16 -1024, i16 -1024, i16 0, i16 0, i16 0, i16 0, i16 0, i16 60, i16 15, i16 3075, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 192, i16 240, i16 -16324, i16 60, i16 0, i16 3, i16 15, i16 60, i16 768, i16 3840, i16 0, i16 0, i16 4080, i16 4032, i16 15360, i16 -4096, i16 -16384, i16 0, i16 0, i16 0, i16 31, i16 63, i16 828, i16 3840, i16 3840, i16 7, i16 7, i16 7, i16 240, i16 248, i16 -32644, i16 -32132, i16 2040, i16 4080, i16 16064, i16 31872, i16 256, i16 256, i16 7, i16 7, i16 7, i16 256, i16 256, i16 0, i16 -4096, i16 -8192, i16 128, i16 128, i16 24704, i16 -8192, i16 -8192, i16 0, i16 31, i16 63, i16 828, i16 573, i16 573, i16 573, i16 573, i16 573, i16 248, i16 252, i16 -15812, i16 4590, i16 494, i16 4590, i16 1020, i16 1016, i16 828, i16 63, i16 31, i16 3840, i16 1792, i16 0, i16 0, i16 0, i16 32512, i16 764, i16 248, i16 -256, i16 -512, i16 0, i16 0, i16 0, i16 15, i16 31, i16 318, i16 892, i16 1020, i16 1020, i16 255, i16 255, i16 224, i16 240, i16 -32648, i16 -16324, i16 -32196, i16 828, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 -15556, i16 -15556, i16 828, i16 828, i16 828, i16 828, i16 3840, i16 3840, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 240, i16 248, i16 -16324, i16 -7652, i16 796, i16 1848, i16 2032, i16 1784, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 -16324, i16 -7652, i16 796, i16 828, i16 2040, i16 4080, i16 -512, i16 -1024, i16 63, i16 127, i16 510, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 240, i16 248, i16 -16324, i16 -7652, i16 -28928, i16 1792, i16 0, i16 0, i16 1020, i16 1020, i16 1020, i16 510, i16 127, i16 63, i16 7936, i16 3840, i16 0, i16 0, i16 28, i16 60, i16 2040, i16 4080, i16 -512, i16 -1024, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 240, i16 248, i16 -16324, i16 -7652, i16 796, i16 796, i16 796, i16 796, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 796, i16 796, i16 796, i16 828, i16 2040, i16 4080, i16 -512, i16 -1024, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 252, i16 252, i16 -256, i16 -256, i16 0, i16 0, i16 240, i16 240, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 -1024, i16 -1024, i16 0, i16 0, i16 252, i16 252, i16 -256, i16 -256, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 252, i16 252, i16 -256, i16 -256, i16 0, i16 0, i16 240, i16 240, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 -1024, i16 -1024, i16 0, i16 0, i16 0, i16 0, i16 -16384, i16 -16384, i16 63, i16 127, i16 510, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 240, i16 248, i16 -8164, i16 -3572, i16 -30976, i16 768, i16 252, i16 252, i16 1020, i16 1020, i16 1020, i16 510, i16 127, i16 63, i16 7936, i16 3840, i16 8988, i16 8988, i16 796, i16 828, i16 2040, i16 4080, i16 -512, i16 -1024, i16 252, i16 252, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 60, i16 60, i16 828, i16 828, i16 828, i16 828, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 -15556, i16 -15556, i16 828, i16 828, i16 828, i16 828, i16 3840, i16 3840, i16 255, i16 255, i16 12303, i16 12303, i16 15, i16 15, i16 15, i16 15, i16 252, i16 252, i16 16320, i16 16320, i16 12480, i16 12480, i16 12480, i16 12480, i16 15, i16 15, i16 15, i16 15, i16 255, i16 255, i16 16128, i16 16128, i16 12480, i16 12480, i16 12480, i16 12480, i16 252, i16 252, i16 -256, i16 -256, i16 63, i16 63, i16 3075, i16 3075, i16 3, i16 3, i16 51, i16 51, i16 252, i16 252, i16 4080, i16 4080, i16 3312, i16 3312, i16 3312, i16 3312, i16 3123, i16 3123, i16 63, i16 63, i16 31, i16 15, i16 1792, i16 768, i16 3312, i16 3312, i16 3312, i16 3312, i16 7392, i16 15552, i16 -2048, i16 -4096, i16 252, i16 252, i16 1020, i16 1020, i16 765, i16 255, i16 255, i16 255, i16 28, i16 60, i16 1912, i16 4080, i16 7904, i16 15552, i16 30848, i16 12480, i16 255, i16 765, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 224, i16 240, i16 248, i16 124, i16 572, i16 828, i16 3840, i16 3840, i16 252, i16 252, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 16128, i16 16128, i16 0, i16 0, i16 0, i16 0, i16 252, i16 252, i16 -256, i16 -256, i16 248, i16 252, i16 254, i16 2295, i16 3315, i16 3315, i16 3315, i16 3315, i16 60, i16 124, i16 1020, i16 988, i16 9116, i16 25500, i16 25500, i16 25500, i16 3315, i16 3315, i16 3315, i16 3315, i16 3315, i16 3315, i16 15360, i16 15360, i16 25500, i16 25500, i16 25500, i16 25500, i16 25500, i16 25500, i16 -6400, i16 -6400, i16 240, i16 248, i16 252, i16 254, i16 255, i16 255, i16 2295, i16 3315, i16 60, i16 60, i16 828, i16 828, i16 828, i16 956, i16 1020, i16 1020, i16 3313, i16 3312, i16 3312, i16 3312, i16 3312, i16 3312, i16 15360, i16 15360, i16 1020, i16 1020, i16 892, i16 828, i16 828, i16 828, i16 3840, i16 3840, i16 63, i16 127, i16 510, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 240, i16 248, i16 -16324, i16 -7652, i16 -31972, i16 796, i16 796, i16 796, i16 1020, i16 1020, i16 1020, i16 510, i16 127, i16 63, i16 7936, i16 3840, i16 796, i16 796, i16 796, i16 828, i16 2040, i16 4080, i16 -512, i16 -1024, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 240, i16 248, i16 -16324, i16 -7652, i16 796, i16 828, i16 2040, i16 4080, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 -512, i16 -1024, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 63, i16 127, i16 510, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 224, i16 240, i16 -32648, i16 -15304, i16 -31176, i16 1592, i16 1592, i16 1592, i16 765, i16 765, i16 1020, i16 510, i16 127, i16 63, i16 7936, i16 3840, i16 1784, i16 1784, i16 17976, i16 1656, i16 764, i16 764, i16 -256, i16 -256, i16 255, i16 255, i16 1020, i16 1020, i16 1020, i16 1020, i16 255, i16 255, i16 240, i16 248, i16 -16324, i16 -7652, i16 796, i16 1848, i16 2032, i16 1784, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 16128, i16 16128, i16 -16324, i16 -7652, i16 796, i16 796, i16 796, i16 796, i16 1792, i16 1792, i16 63, i16 127, i16 2040, i16 4080, i16 1784, i16 255, i16 127, i16 63, i16 248, i16 252, i16 -15812, i16 -256, i16 3840, i16 240, i16 248, i16 252, i16 7936, i16 3840, i16 224, i16 255, i16 255, i16 127, i16 16128, i16 7936, i16 -32132, i16 -15556, i16 892, i16 1020, i16 2040, i16 4080, i16 -512, i16 -1024, i16 255, i16 255, i16 12303, i16 12303, i16 15, i16 15, i16 15, i16 15, i16 252, i16 252, i16 16320, i16 16320, i16 12480, i16 12480, i16 12480, i16 12480, i16 15, i16 15, i16 15, i16 15, i16 15, i16 15, i16 768, i16 768, i16 12480, i16 12480, i16 12480, i16 12480, i16 12480, i16 12480, i16 -4096, i16 -4096, i16 252, i16 252, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 1020, i16 28, i16 28, i16 796, i16 796, i16 796, i16 796, i16 796, i16 796, i16 1020, i16 1020, i16 510, i16 255, i16 127, i16 63, i16 7936, i16 3840, i16 796, i16 796, i16 828, i16 1020, i16 2040, i16 4080, i16 -512, i16 -1024, i16 248, i16 248, i16 1656, i16 1656, i16 1656, i16 1656, i16 1656, i16 1656, i16 124, i16 124, i16 1912, i16 1912, i16 1656, i16 1656, i16 1656, i16 1656, i16 1656, i16 572, i16 63, i16 31, i16 15, i16 7, i16 768, i16 256, i16 1656, i16 3824, i16 3824, i16 7392, i16 15552, i16 30848, i16 -4096, i16 -8192, i16 243, i16 243, i16 3315, i16 3315, i16 3315, i16 3315, i16 3315, i16 3315, i16 156, i16 156, i16 25500, i16 25500, i16 25500, i16 25500, i16 25500, i16 25500, i16 3315, i16 3315, i16 2295, i16 255, i16 510, i16 892, i16 16128, i16 7936, i16 25500, i16 25500, i16 9180, i16 1020, i16 1020, i16 -30856, i16 -16640, i16 7680, i16 240, i16 240, i16 1272, i16 124, i16 63, i16 31, i16 15, i16 15, i16 60, i16 60, i16 892, i16 2040, i16 4080, i16 7904, i16 15552, i16 14528, i16 31, i16 63, i16 892, i16 2040, i16 4080, i16 3824, i16 15360, i16 15360, i16 4320, i16 240, i16 248, i16 -32644, i16 572, i16 828, i16 3840, i16 3840, i16 240, i16 240, i16 1272, i16 124, i16 63, i16 31, i16 15, i16 7, i16 60, i16 60, i16 892, i16 2040, i16 4080, i16 7904, i16 15552, i16 30848, i16 7, i16 7, i16 7, i16 7, i16 7, i16 7, i16 256, i16 256, i16 28800, i16 24704, i16 24704, i16 24704, i16 24704, i16 24704, i16 -8192, i16 -8192, i16 127, i16 127, i16 127, i16 7936, i16 7936, i16 1, i16 3, i16 7, i16 252, i16 252, i16 1020, i16 -31876, i16 2040, i16 4080, i16 7904, i16 15552, i16 15, i16 31, i16 318, i16 127, i16 127, i16 127, i16 7936, i16 7936, i16 30848, i16 -4096, i16 -8192, i16 252, i16 252, i16 1020, i16 -256, i16 -256, i16 31, i16 31, i16 286, i16 286, i16 286, i16 286, i16 286, i16 286, i16 224, i16 224, i16 -2048, i16 -2048, i16 -32768, i16 -32768, i16 -32768, i16 -32768, i16 286, i16 286, i16 286, i16 31, i16 31, i16 1792, i16 1792, i16 0, i16 -32768, i16 -32768, i16 -32768, i16 224, i16 224, i16 -2048, i16 -2048, i16 0, i16 224, i16 112, i16 56, i16 28, i16 14, i16 7, i16 3, i16 1, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 128, i16 192, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 224, i16 112, i16 56, i16 28, i16 14, i16 7, i16 768, i16 256, i16 31, i16 31, i16 1792, i16 1792, i16 0, i16 0, i16 0, i16 0, i16 224, i16 224, i16 2288, i16 2288, i16 3312, i16 3312, i16 3312, i16 3312, i16 0, i16 0, i16 0, i16 31, i16 31, i16 1792, i16 1792, i16 0, i16 3312, i16 3312, i16 3312, i16 7392, i16 7392, i16 -2048, i16 -2048, i16 0, i16 3, i16 7, i16 14, i16 284, i16 824, i16 1840, i16 3584, i16 3072, i16 192, i16 224, i16 -32656, i16 -16328, i16 -32740, i16 524, i16 1792, i16 768, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0, i16 127, i16 127, i16 7936, i16 0, i16 0, i16 0, i16 0, i16 0, i16 248, i16 248, i16 -512], align 1
@boids_gate_crc.gf = internal global [8 x %struct.Boid] zeroinitializer, align 1
@title_end._title_bg_black = internal constant i16 0, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = alloca [4 x i16], align 1
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
  store ptr @SPRITE_VT, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 196), align 1, !tbaa !15
  store i8 16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 198), align 1, !tbaa !19
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 745), align 1, !tbaa !20
  store i16 16384, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 743), align 1, !tbaa !21
  br label %10

10:                                               ; preds = %10, %9
  %11 = phi i16 [ 0, %9 ], [ %16, %10 ]
  %12 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 199), i16 %11
  store i8 0, ptr %12, align 1, !tbaa !6
  %13 = getelementptr inbounds nuw i8, ptr %12, i16 1
  store i8 -32, ptr %13, align 1, !tbaa !6
  %14 = getelementptr inbounds nuw i8, ptr %12, i16 2
  store i8 0, ptr %14, align 1, !tbaa !6
  %15 = getelementptr inbounds nuw i8, ptr %12, i16 3
  store i8 0, ptr %15, align 1, !tbaa !6
  %16 = add nuw nsw i16 %11, 4
  %17 = icmp samesign ult i16 %11, 508
  br i1 %17, label %10, label %18, !llvm.loop !22

18:                                               ; preds = %10
  tail call void @llvm.memset.p0.i16(ptr noundef nonnull align 1 dereferenceable(32) getelementptr inbounds nuw (i8, ptr @main.a, i16 711), i8 0, i16 32, i1 false), !tbaa !6
  %19 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %20 = icmp eq i8 %19, 0
  br i1 %20, label %22, label %21

21:                                               ; preds = %18
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !24
  br label %22

22:                                               ; preds = %21, %18
  %23 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %24 = icmp ult i8 %23, 4
  br i1 %24, label %25, label %29

25:                                               ; preds = %22
  %26 = zext nneg i8 %23 to i16
  %27 = add nuw nsw i8 %23, 1
  store i8 %27, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %28 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %26
  store ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 196), ptr %28, align 1, !tbaa !26
  br label %29

29:                                               ; preds = %25, %22
  %30 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 745), align 1, !tbaa !20
  %31 = zext i8 %30 to i16
  %32 = shl nuw nsw i16 %31, 5
  %33 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 743), align 1, !tbaa !21
  %34 = lshr i16 %33, 13
  %35 = or disjoint i16 %32, %34
  %36 = trunc i16 %35 to i8
  store volatile i8 %36, ptr inttoptr (i16 8449 to ptr), align 1, !tbaa !6
  %37 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  %38 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 198), align 1, !tbaa !29
  %39 = or i8 %38, %37
  store i8 %39, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  store volatile i8 %39, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  br label %40

40:                                               ; preds = %45, %29
  %41 = phi i8 [ %62, %45 ], [ 0, %29 ]
  %42 = phi ptr [ %59, %45 ], [ @BOID_PIX, %29 ]
  %43 = phi i8 [ %61, %45 ], [ 0, %29 ]
  %44 = phi i8 [ %57, %45 ], [ 0, %29 ]
  br label %63

45:                                               ; preds = %96
  %46 = zext i8 %79 to i16
  %47 = zext i8 %85 to i16
  %48 = shl nuw i16 %47, 8
  %49 = or disjoint i16 %48, %46
  %50 = zext nneg i8 %43 to i16
  %51 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1002), i16 %50
  store i16 %49, ptr %51, align 1, !tbaa !2
  %52 = zext i8 %91 to i16
  %53 = zext i8 %97 to i16
  %54 = shl nuw i16 %53, 8
  %55 = or disjoint i16 %54, %52
  %56 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1018), i16 %50
  store i16 %55, ptr %56, align 1, !tbaa !2
  %57 = add nuw nsw i8 %44, 1
  %58 = zext nneg i8 %41 to i16
  %59 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @BOID_PIX, i16 8), i16 %58
  %60 = icmp eq i8 %57, 8
  %61 = add nuw nsw i8 %43, 2
  %62 = add nuw nsw i8 %41, 8
  br i1 %60, label %100, label %40, !llvm.loop !30

63:                                               ; preds = %96, %40
  %64 = phi i8 [ 0, %40 ], [ %98, %96 ]
  %65 = phi i8 [ 0, %40 ], [ %97, %96 ]
  %66 = phi i8 [ 0, %40 ], [ %91, %96 ]
  %67 = phi i8 [ 0, %40 ], [ %85, %96 ]
  %68 = phi i8 [ 0, %40 ], [ %79, %96 ]
  %69 = zext nneg i8 %64 to i16
  %70 = getelementptr i8, ptr %42, i16 %69
  %71 = load i8, ptr %70, align 1, !tbaa !6
  %72 = lshr exact i8 -128, %64
  %73 = zext i8 %71 to i16
  %74 = and i16 %73, 1
  %75 = icmp eq i16 %74, 0
  br i1 %75, label %78, label %76

76:                                               ; preds = %63
  %77 = or i8 %68, %72
  br label %78

78:                                               ; preds = %76, %63
  %79 = phi i8 [ %77, %76 ], [ %68, %63 ]
  %80 = and i16 %73, 2
  %81 = icmp eq i16 %80, 0
  br i1 %81, label %84, label %82

82:                                               ; preds = %78
  %83 = or i8 %67, %72
  br label %84

84:                                               ; preds = %82, %78
  %85 = phi i8 [ %83, %82 ], [ %67, %78 ]
  %86 = and i16 %73, 4
  %87 = icmp eq i16 %86, 0
  br i1 %87, label %90, label %88

88:                                               ; preds = %84
  %89 = or i8 %66, %72
  br label %90

90:                                               ; preds = %88, %84
  %91 = phi i8 [ %89, %88 ], [ %66, %84 ]
  %92 = and i16 %73, 8
  %93 = icmp eq i16 %92, 0
  br i1 %93, label %96, label %94

94:                                               ; preds = %90
  %95 = or i8 %72, %65
  br label %96

96:                                               ; preds = %94, %90
  %97 = phi i8 [ %95, %94 ], [ %65, %90 ]
  %98 = add nuw nsw i8 %64, 1
  %99 = icmp eq i8 %98, 8
  br i1 %99, label %45, label %63, !llvm.loop !31

100:                                              ; preds = %45
  %101 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %102 = icmp ugt i8 %101, 15
  br i1 %102, label %114, label %103

103:                                              ; preds = %100
  %104 = zext nneg i8 %101 to i16
  %105 = add nuw nsw i8 %101, 1
  store i8 %105, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %106 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %104
  %107 = getelementptr inbounds nuw i8, ptr %106, i16 10
  store i8 0, ptr %107, align 1, !tbaa !33
  store i16 16384, ptr %106, align 1, !tbaa !35
  %108 = getelementptr inbounds nuw i8, ptr %106, i16 9
  store i8 -128, ptr %108, align 1, !tbaa !36
  %109 = getelementptr inbounds nuw i8, ptr %106, i16 7
  store i8 24, ptr %109, align 1, !tbaa !37
  %110 = getelementptr inbounds nuw i8, ptr %106, i16 8
  store i8 1, ptr %110, align 1, !tbaa !38
  %111 = getelementptr inbounds nuw i8, ptr %106, i16 2
  store i16 ptrtoint (ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1002) to i16), ptr %111, align 1, !tbaa !39
  %112 = getelementptr inbounds nuw i8, ptr %106, i16 6
  store i8 0, ptr %112, align 1, !tbaa !40
  %113 = getelementptr inbounds nuw i8, ptr %106, i16 4
  store i16 32, ptr %113, align 1, !tbaa !41
  br label %114

114:                                              ; preds = %103, %100
  %115 = phi i8 [ %101, %100 ], [ %105, %103 ]
  br label %116

116:                                              ; preds = %114, %158
  %117 = phi i8 [ %163, %158 ], [ 0, %114 ]
  %118 = phi i8 [ %162, %158 ], [ 0, %114 ]
  %119 = phi i8 [ %160, %158 ], [ 0, %114 ]
  %120 = phi i8 [ %159, %158 ], [ %115, %114 ]
  %121 = zext nneg i8 %118 to i16
  %122 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1034), i16 %121
  store i16 0, ptr %122, align 1, !tbaa !2
  %123 = zext nneg i8 %117 to i16
  %124 = getelementptr i8, ptr @HUE5, i16 %123
  %125 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @HUE5, i16 2), i16 %123
  %126 = load i8, ptr %125, align 1, !tbaa !6
  %127 = and i8 %126, 31
  %128 = zext nneg i8 %127 to i16
  %129 = shl nuw nsw i16 %128, 10
  %130 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @HUE5, i16 1), i16 %123
  %131 = load i8, ptr %130, align 1, !tbaa !6
  %132 = and i8 %131, 31
  %133 = zext nneg i8 %132 to i16
  %134 = shl nuw nsw i16 %133, 5
  %135 = or disjoint i16 %134, %129
  %136 = load i8, ptr %124, align 1, !tbaa !6
  %137 = and i8 %136, 31
  %138 = zext nneg i8 %137 to i16
  %139 = or disjoint i16 %135, %138
  %140 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1036), i16 %121
  store i16 %139, ptr %140, align 1, !tbaa !2
  %141 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1038), i16 %121
  store i16 32767, ptr %141, align 1, !tbaa !2
  %142 = icmp ugt i8 %120, 15
  br i1 %142, label %158, label %143

143:                                              ; preds = %116
  %144 = shl nuw nsw i8 %119, 4
  %145 = or disjoint i8 %144, -128
  %146 = zext nneg i8 %120 to i16
  %147 = add nuw nsw i8 %120, 1
  store i8 %147, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %148 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %146
  %149 = getelementptr inbounds nuw i8, ptr %148, i16 10
  store i8 1, ptr %149, align 1, !tbaa !33
  %150 = zext i8 %145 to i16
  store i16 %150, ptr %148, align 1, !tbaa !35
  %151 = getelementptr inbounds nuw i8, ptr %148, i16 9
  store i8 0, ptr %151, align 1, !tbaa !36
  %152 = getelementptr inbounds nuw i8, ptr %148, i16 7
  store i8 34, ptr %152, align 1, !tbaa !37
  %153 = getelementptr inbounds nuw i8, ptr %148, i16 8
  store i8 0, ptr %153, align 1, !tbaa !38
  %154 = ptrtoint ptr %122 to i16
  %155 = getelementptr inbounds nuw i8, ptr %148, i16 2
  store i16 %154, ptr %155, align 1, !tbaa !39
  %156 = getelementptr inbounds nuw i8, ptr %148, i16 6
  store i8 0, ptr %156, align 1, !tbaa !40
  %157 = getelementptr inbounds nuw i8, ptr %148, i16 4
  store i16 6, ptr %157, align 1, !tbaa !41
  br label %158

158:                                              ; preds = %143, %116
  %159 = phi i8 [ %120, %116 ], [ %147, %143 ]
  %160 = add nuw nsw i8 %119, 1
  %161 = icmp eq i8 %160, 8
  %162 = add nuw nsw i8 %118, 6
  %163 = add nuw nsw i8 %117, 3
  br i1 %161, label %164, label %116, !llvm.loop !42

164:                                              ; preds = %158, %164
  %165 = phi i8 [ %207, %164 ], [ 0, %158 ]
  %166 = phi i8 [ %205, %164 ], [ 0, %158 ]
  %167 = phi i16 [ %201, %164 ], [ 2829, %158 ]
  %168 = shl i16 %167, 7
  %169 = xor i16 %168, %167
  %170 = lshr i16 %169, 9
  %171 = xor i16 %170, %169
  %172 = shl i16 %171, 8
  %173 = xor i16 %172, %171
  %174 = and i16 %173, 1023
  %175 = add nuw nsw i16 %174, 1536
  %176 = zext i8 %165 to i16
  %177 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 746), i16 %176
  store i16 %175, ptr %177, align 1, !tbaa !43
  %178 = shl i16 %173, 7
  %179 = xor i16 %178, %173
  %180 = lshr i16 %179, 9
  %181 = xor i16 %180, %179
  %182 = shl i16 %181, 8
  %183 = xor i16 %182, %181
  %184 = and i16 %183, 1023
  %185 = add nuw nsw i16 %184, 1280
  %186 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 748), i16 %176
  store i16 %185, ptr %186, align 1, !tbaa !45
  %187 = shl i16 %183, 7
  %188 = xor i16 %187, %183
  %189 = lshr i16 %188, 9
  %190 = xor i16 %189, %188
  %191 = shl i16 %190, 8
  %192 = xor i16 %191, %190
  %193 = and i16 %190, 63
  %194 = add nsw i16 %193, -32
  %195 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 750), i16 %176
  store i16 %194, ptr %195, align 1, !tbaa !46
  %196 = shl i16 %192, 7
  %197 = xor i16 %196, %192
  %198 = lshr i16 %197, 9
  %199 = xor i16 %198, %197
  %200 = shl i16 %199, 8
  %201 = xor i16 %200, %199
  %202 = and i16 %199, 63
  %203 = add nsw i16 %202, -32
  %204 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 752), i16 %176
  store i16 %203, ptr %204, align 1, !tbaa !47
  %205 = add nuw nsw i8 %166, 1
  %206 = icmp eq i8 %205, 32
  %207 = add i8 %165, 8
  br i1 %206, label %208, label %164, !llvm.loop !48

208:                                              ; preds = %164
  store ptr @TITLE_VT, ptr @main.title, align 1, !tbaa !49
  store i8 2, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !53
  store ptr @.str, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 3), align 1, !tbaa !54
  store ptr @.str.1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 5), align 1, !tbaa !55
  store ptr @.str.1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 7), align 1, !tbaa !56
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 11), align 1, !tbaa !57
  store ptr null, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 9), align 1, !tbaa !58
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 12), align 1, !tbaa !59
  store i16 96, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 13), align 1, !tbaa !60
  store i16 112, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 15), align 1, !tbaa !61
  store i16 16, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 17), align 1, !tbaa !62
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 28), align 1, !tbaa !63
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 29), align 1, !tbaa !64
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !65
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 32), align 1, !tbaa !66
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !67
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !68
  store i16 32767, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 34), align 1, !tbaa !69
  store i16 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 36), align 1, !tbaa !70
  %209 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  %210 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %211 = icmp eq i8 %210, 0
  br i1 %211, label %213, label %212

212:                                              ; preds = %208
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !24
  br label %213

213:                                              ; preds = %212, %208
  %214 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %215 = icmp ult i8 %214, 4
  br i1 %215, label %216, label %220

216:                                              ; preds = %213
  %217 = zext nneg i8 %214 to i16
  %218 = add nuw nsw i8 %214, 1
  store i8 %218, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %219 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %217
  store ptr @main.title, ptr %219, align 1, !tbaa !26
  br label %220

220:                                              ; preds = %216, %213
  tail call void @_title_reserve(ptr noundef nonnull @main.title, ptr nonnull poison) #12, !inline_history !71
  %221 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  %222 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !29
  %223 = or i8 %222, %221
  store volatile i8 %223, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store i8 %209, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 33), align 1, !tbaa !72
  store i8 2, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  store volatile i8 2, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store volatile i8 24, ptr inttoptr (i16 16908 to ptr), align 4, !tbaa !6
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  br label %224

224:                                              ; preds = %252, %220
  %225 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %226 = icmp eq i8 %225, 0
  br i1 %226, label %238, label %227

227:                                              ; preds = %224, %227
  %228 = phi i8 [ %235, %227 ], [ 0, %224 ]
  %229 = zext i8 %228 to i16
  %230 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %229
  %231 = load ptr, ptr %230, align 1, !tbaa !26
  %232 = load ptr, ptr %231, align 1, !tbaa !73
  %233 = getelementptr inbounds nuw i8, ptr %232, i16 2
  %234 = load ptr, ptr %233, align 1, !tbaa !74
  tail call void %234(ptr noundef nonnull %231, ptr noundef nonnull @main.a) #12, !inline_history !76
  %235 = add nuw i8 %228, 1
  %236 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %237 = icmp ult i8 %235, %236
  br i1 %237, label %227, label %238, !llvm.loop !77

238:                                              ; preds = %227, %224
  %239 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %240

240:                                              ; preds = %240, %238
  %241 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %242 = icmp sgt i8 %241, -1
  br i1 %242, label %240, label %243, !llvm.loop !78

243:                                              ; preds = %240
  tail call fastcc void @upq_flush() #13
  %244 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %245 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %246 = icmp ult i8 %244, %245
  br i1 %246, label %249, label %247

247:                                              ; preds = %243
  %248 = icmp ugt i8 %244, %245
  br i1 %248, label %249, label %252

249:                                              ; preds = %247, %243
  %250 = phi i8 [ 1, %243 ], [ -1, %247 ]
  %251 = add i8 %250, %244
  store i8 %251, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %252

252:                                              ; preds = %249, %247
  %253 = phi i8 [ %244, %247 ], [ %251, %249 ]
  %254 = and i8 %253, 15
  store volatile i8 %254, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %255 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %256 = icmp eq i8 %255, 15
  br i1 %256, label %257, label %224, !llvm.loop !79

257:                                              ; preds = %252
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !67
  %258 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !68
  %259 = icmp eq i8 %258, -1
  br i1 %259, label %297, label %260

260:                                              ; preds = %257, %289
  %261 = phi i8 [ %292, %289 ], [ 0, %257 ]
  %262 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %263 = icmp eq i8 %262, 0
  br i1 %263, label %275, label %264

264:                                              ; preds = %260, %264
  %265 = phi i8 [ %272, %264 ], [ 0, %260 ]
  %266 = zext i8 %265 to i16
  %267 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %266
  %268 = load ptr, ptr %267, align 1, !tbaa !26
  %269 = load ptr, ptr %268, align 1, !tbaa !73
  %270 = getelementptr inbounds nuw i8, ptr %269, i16 2
  %271 = load ptr, ptr %270, align 1, !tbaa !74
  tail call void %271(ptr noundef nonnull %268, ptr noundef nonnull @main.a) #12, !inline_history !80
  %272 = add nuw i8 %265, 1
  %273 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %274 = icmp ult i8 %272, %273
  br i1 %274, label %264, label %275, !llvm.loop !77

275:                                              ; preds = %264, %260
  %276 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %277

277:                                              ; preds = %277, %275
  %278 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %279 = icmp sgt i8 %278, -1
  br i1 %279, label %277, label %280, !llvm.loop !78

280:                                              ; preds = %277
  tail call fastcc void @upq_flush() #13
  %281 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %282 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %283 = icmp ult i8 %281, %282
  br i1 %283, label %286, label %284

284:                                              ; preds = %280
  %285 = icmp ugt i8 %281, %282
  br i1 %285, label %286, label %289

286:                                              ; preds = %284, %280
  %287 = phi i8 [ 1, %280 ], [ -1, %284 ]
  %288 = add i8 %287, %281
  store i8 %288, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %289

289:                                              ; preds = %286, %284
  %290 = phi i8 [ %281, %284 ], [ %288, %286 ]
  %291 = and i8 %290, 15
  store volatile i8 %291, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %292 = add nuw i8 %261, 1
  %293 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !68
  %294 = icmp ne i8 %293, -1
  %295 = icmp ult i8 %261, -57
  %296 = select i1 %294, i1 %295, i1 false
  br i1 %296, label %260, label %297, !llvm.loop !81

297:                                              ; preds = %289, %257
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !67
  store i16 2096, ptr @boids_gate_crc.gf, align 1, !tbaa !43
  store i16 32, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), align 1, !tbaa !45
  store i16 8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), align 1, !tbaa !46
  store i16 30, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), align 1, !tbaa !47
  store i16 1336, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 8), align 1, !tbaa !43
  store i16 364, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 10), align 1, !tbaa !45
  store i16 -11, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 12), align 1, !tbaa !46
  store i16 -13, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 14), align 1, !tbaa !47
  store i16 3656, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 16), align 1, !tbaa !43
  store i16 1893, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 18), align 1, !tbaa !45
  store i16 3, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 20), align 1, !tbaa !46
  store i16 -4, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 22), align 1, !tbaa !47
  store i16 1898, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 24), align 1, !tbaa !43
  store i16 2419, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 26), align 1, !tbaa !45
  store i16 -17, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 28), align 1, !tbaa !46
  store i16 -9, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 30), align 1, !tbaa !47
  store i16 3569, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 32), align 1, !tbaa !43
  store i16 2131, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 34), align 1, !tbaa !45
  store i16 -20, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 36), align 1, !tbaa !46
  store i16 -26, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 38), align 1, !tbaa !47
  store i16 3806, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 40), align 1, !tbaa !43
  store i16 926, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 42), align 1, !tbaa !45
  store i16 22, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 44), align 1, !tbaa !46
  store i16 -8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 46), align 1, !tbaa !47
  store i16 1516, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 48), align 1, !tbaa !43
  store i16 3285, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 50), align 1, !tbaa !45
  store i16 19, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 52), align 1, !tbaa !46
  store i16 -32, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 54), align 1, !tbaa !47
  store i16 1491, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 56), align 1, !tbaa !43
  store i16 797, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 58), align 1, !tbaa !45
  store i16 -6, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 60), align 1, !tbaa !46
  store i16 22, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 62), align 1, !tbaa !47
  br label %298

298:                                              ; preds = %349, %297
  %299 = phi i8 [ 0, %297 ], [ %350, %349 ]
  br label %304

300:                                              ; preds = %349
  %301 = getelementptr inbounds nuw i8, ptr %1, i16 2
  %302 = getelementptr inbounds nuw i8, ptr %1, i16 4
  %303 = getelementptr inbounds nuw i8, ptr %1, i16 6
  br label %352

304:                                              ; preds = %344, %298
  %305 = phi i8 [ %348, %344 ], [ 0, %298 ]
  %306 = phi i8 [ %346, %344 ], [ 0, %298 ]
  %307 = tail call fastcc { i16, i16 } @boid_acc(ptr noundef nonnull @boids_gate_crc.gf, i8 noundef zeroext 8, i8 noundef zeroext %306) #13
  %308 = extractvalue { i16, i16 } %307, 0
  %309 = extractvalue { i16, i16 } %307, 1
  %310 = zext nneg i8 %305 to i16
  %311 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %310
  %312 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %310
  %313 = load i16, ptr %312, align 1
  %314 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %310
  %315 = load i16, ptr %314, align 1
  %316 = tail call fastcc { i16, i16 } @v2_add(i16 %313, i16 %315, i16 %308, i16 %309) #13
  %317 = extractvalue { i16, i16 } %316, 0
  %318 = extractvalue { i16, i16 } %316, 1
  %319 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %317, i16 %318, i16 noundef 40) #13
  %320 = extractvalue { i16, i16 } %319, 0
  %321 = extractvalue { i16, i16 } %319, 1
  store i16 %320, ptr %312, align 1, !tbaa !2
  store i16 %321, ptr %314, align 1, !tbaa !2
  %322 = load i16, ptr %311, align 1
  %323 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %310
  %324 = load i16, ptr %323, align 1
  %325 = tail call fastcc { i16, i16 } @v2_add(i16 %322, i16 %324, i16 %320, i16 %321) #13
  %326 = extractvalue { i16, i16 } %325, 0
  %327 = extractvalue { i16, i16 } %325, 1
  %328 = icmp slt i16 %326, 0
  br i1 %328, label %329, label %331

329:                                              ; preds = %304
  %330 = add nsw i16 %326, 4096
  br label %335

331:                                              ; preds = %304
  %332 = icmp samesign ult i16 %326, 4096
  br i1 %332, label %335, label %333

333:                                              ; preds = %331
  %334 = add nsw i16 %326, -4096
  br label %335

335:                                              ; preds = %333, %331, %329
  %336 = phi i16 [ %330, %329 ], [ %334, %333 ], [ %326, %331 ]
  %337 = icmp slt i16 %327, 0
  br i1 %337, label %338, label %340

338:                                              ; preds = %335
  %339 = add nsw i16 %327, 3584
  br label %344

340:                                              ; preds = %335
  %341 = icmp samesign ult i16 %327, 3584
  br i1 %341, label %344, label %342

342:                                              ; preds = %340
  %343 = add nsw i16 %327, -3584
  br label %344

344:                                              ; preds = %342, %340, %338
  %345 = phi i16 [ %339, %338 ], [ %343, %342 ], [ %327, %340 ]
  store i16 %336, ptr %311, align 1, !tbaa !2
  store i16 %345, ptr %323, align 1, !tbaa !2
  %346 = add nuw nsw i8 %306, 1
  %347 = icmp eq i8 %346, 8
  %348 = add nuw nsw i8 %305, 8
  br i1 %347, label %349, label %304, !llvm.loop !82

349:                                              ; preds = %344
  %350 = add nuw nsw i8 %299, 1
  %351 = icmp eq i8 %350, 12
  br i1 %351, label %300, label %298, !llvm.loop !83

352:                                              ; preds = %365, %300
  %353 = phi i8 [ 0, %300 ], [ %368, %365 ]
  %354 = phi i8 [ 0, %300 ], [ %366, %365 ]
  %355 = phi i16 [ 0, %300 ], [ %377, %365 ]
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #14
  %356 = zext nneg i8 %353 to i16
  %357 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %356
  %358 = load i16, ptr %357, align 1, !tbaa !43
  store i16 %358, ptr %1, align 1, !tbaa !2
  %359 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %356
  %360 = load i16, ptr %359, align 1, !tbaa !45
  store i16 %360, ptr %301, align 1, !tbaa !2
  %361 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %356
  %362 = load i16, ptr %361, align 1, !tbaa !46
  store i16 %362, ptr %302, align 1, !tbaa !2
  %363 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %356
  %364 = load i16, ptr %363, align 1, !tbaa !47
  store i16 %364, ptr %303, align 1, !tbaa !2
  br label %369

365:                                              ; preds = %369
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #14
  %366 = add nuw nsw i8 %354, 1
  %367 = icmp eq i8 %366, 8
  %368 = add nuw nsw i8 %353, 8
  br i1 %367, label %381, label %352, !llvm.loop !84

369:                                              ; preds = %369, %352
  %370 = phi i8 [ 0, %352 ], [ %380, %369 ]
  %371 = phi i8 [ 0, %352 ], [ %378, %369 ]
  %372 = phi i16 [ %355, %352 ], [ %377, %369 ]
  %373 = tail call i16 @llvm.fshl.i16(i16 %372, i16 %372, i16 1)
  %374 = zext nneg i8 %370 to i16
  %375 = getelementptr i8, ptr %1, i16 %374
  %376 = load i16, ptr %375, align 1, !tbaa !2
  %377 = xor i16 %376, %373
  %378 = add nuw nsw i8 %371, 1
  %379 = icmp eq i8 %378, 4
  %380 = add nuw nsw i8 %370, 2
  br i1 %379, label %365, label %369, !llvm.loop !85

381:                                              ; preds = %365
  store volatile i16 %377, ptr @corpus_result, align 1, !tbaa !2
  br label %382

382:                                              ; preds = %412, %381
  %383 = phi i16 [ 110, %381 ], [ %384, %412 ]
  %384 = add nsw i16 %383, -1
  %385 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %386 = icmp eq i8 %385, 0
  br i1 %386, label %398, label %387

387:                                              ; preds = %382, %387
  %388 = phi i8 [ %395, %387 ], [ 0, %382 ]
  %389 = zext i8 %388 to i16
  %390 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %389
  %391 = load ptr, ptr %390, align 1, !tbaa !26
  %392 = load ptr, ptr %391, align 1, !tbaa !73
  %393 = getelementptr inbounds nuw i8, ptr %392, i16 2
  %394 = load ptr, ptr %393, align 1, !tbaa !74
  tail call void %394(ptr noundef nonnull %391, ptr noundef nonnull @main.a) #12, !inline_history !86
  %395 = add nuw i8 %388, 1
  %396 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %397 = icmp ult i8 %395, %396
  br i1 %397, label %387, label %398, !llvm.loop !77

398:                                              ; preds = %387, %382
  %399 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %400

400:                                              ; preds = %400, %398
  %401 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %402 = icmp sgt i8 %401, -1
  br i1 %402, label %400, label %403, !llvm.loop !78

403:                                              ; preds = %400
  tail call fastcc void @upq_flush() #13
  %404 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %405 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %406 = icmp ult i8 %404, %405
  br i1 %406, label %409, label %407

407:                                              ; preds = %403
  %408 = icmp ugt i8 %404, %405
  br i1 %408, label %409, label %412

409:                                              ; preds = %407, %403
  %410 = phi i8 [ 1, %403 ], [ -1, %407 ]
  %411 = add i8 %410, %404
  store i8 %411, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %412

412:                                              ; preds = %409, %407
  %413 = phi i8 [ %404, %407 ], [ %411, %409 ]
  %414 = and i8 %413, 15
  store volatile i8 %414, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %415 = icmp eq i16 %384, 0
  br i1 %415, label %416, label %382, !llvm.loop !87

416:                                              ; preds = %412
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !65
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 32), align 1, !tbaa !66
  br label %420

417:                                              ; preds = %449
  %418 = add nuw nsw i8 %421, 1
  %419 = icmp eq i8 %418, 90
  br i1 %419, label %454, label %420, !llvm.loop !88

420:                                              ; preds = %417, %416
  %421 = phi i8 [ 0, %416 ], [ %418, %417 ]
  %422 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %423 = icmp eq i8 %422, 0
  br i1 %423, label %435, label %424

424:                                              ; preds = %420, %424
  %425 = phi i8 [ %432, %424 ], [ 0, %420 ]
  %426 = zext i8 %425 to i16
  %427 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %426
  %428 = load ptr, ptr %427, align 1, !tbaa !26
  %429 = load ptr, ptr %428, align 1, !tbaa !73
  %430 = getelementptr inbounds nuw i8, ptr %429, i16 2
  %431 = load ptr, ptr %430, align 1, !tbaa !74
  tail call void %431(ptr noundef nonnull %428, ptr noundef nonnull @main.a) #12, !inline_history !89
  %432 = add nuw i8 %425, 1
  %433 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %434 = icmp ult i8 %432, %433
  br i1 %434, label %424, label %435, !llvm.loop !77

435:                                              ; preds = %424, %420
  %436 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %437

437:                                              ; preds = %437, %435
  %438 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %439 = icmp sgt i8 %438, -1
  br i1 %439, label %437, label %440, !llvm.loop !78

440:                                              ; preds = %437
  tail call fastcc void @upq_flush() #13
  %441 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %442 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %443 = icmp ult i8 %441, %442
  br i1 %443, label %446, label %444

444:                                              ; preds = %440
  %445 = icmp ugt i8 %441, %442
  br i1 %445, label %446, label %449

446:                                              ; preds = %444, %440
  %447 = phi i8 [ 1, %440 ], [ -1, %444 ]
  %448 = add i8 %447, %441
  store i8 %448, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %449

449:                                              ; preds = %446, %444
  %450 = phi i8 [ %441, %444 ], [ %448, %446 ]
  %451 = and i8 %450, 15
  store volatile i8 %451, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %452 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 19), align 1, !tbaa !90
  %453 = icmp sgt i16 %452, 3583
  br i1 %453, label %454, label %417

454:                                              ; preds = %449, %417
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !65
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %455 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %456 = icmp eq i8 %455, 0
  br i1 %456, label %490, label %457

457:                                              ; preds = %454, %485
  %458 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %459 = icmp eq i8 %458, 0
  br i1 %459, label %471, label %460

460:                                              ; preds = %457, %460
  %461 = phi i8 [ %468, %460 ], [ 0, %457 ]
  %462 = zext i8 %461 to i16
  %463 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %462
  %464 = load ptr, ptr %463, align 1, !tbaa !26
  %465 = load ptr, ptr %464, align 1, !tbaa !73
  %466 = getelementptr inbounds nuw i8, ptr %465, i16 2
  %467 = load ptr, ptr %466, align 1, !tbaa !74
  tail call void %467(ptr noundef nonnull %464, ptr noundef nonnull @main.a) #12, !inline_history !91
  %468 = add nuw i8 %461, 1
  %469 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %470 = icmp ult i8 %468, %469
  br i1 %470, label %460, label %471, !llvm.loop !77

471:                                              ; preds = %460, %457
  %472 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %473

473:                                              ; preds = %473, %471
  %474 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %475 = icmp sgt i8 %474, -1
  br i1 %475, label %473, label %476, !llvm.loop !78

476:                                              ; preds = %473
  tail call fastcc void @upq_flush() #13
  %477 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %478 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %479 = icmp ult i8 %477, %478
  br i1 %479, label %482, label %480

480:                                              ; preds = %476
  %481 = icmp ugt i8 %477, %478
  br i1 %481, label %482, label %485

482:                                              ; preds = %480, %476
  %483 = phi i8 [ 1, %476 ], [ -1, %480 ]
  %484 = add i8 %483, %477
  store i8 %484, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %485

485:                                              ; preds = %482, %480
  %486 = phi i8 [ %477, %480 ], [ %484, %482 ]
  %487 = and i8 %486, 15
  store volatile i8 %487, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %488 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %489 = icmp eq i8 %488, 0
  br i1 %489, label %490, label %457, !llvm.loop !79

490:                                              ; preds = %485, %454
  %491 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 33), align 1, !tbaa !72
  %492 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  %493 = or i8 %492, %491
  %494 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !29
  %495 = xor i8 %494, -1
  %496 = and i8 %493, %495
  store i8 %496, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  store volatile i8 %496, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 16908 to ptr), align 4, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8463 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8463 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 29), align 1, !tbaa !64
  %497 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %498 = icmp ugt i8 %497, 15
  br i1 %498, label %510, label %499

499:                                              ; preds = %490
  %500 = zext nneg i8 %497 to i16
  %501 = add nuw nsw i8 %497, 1
  store i8 %501, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %502 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %500
  %503 = getelementptr inbounds nuw i8, ptr %502, i16 10
  store i8 1, ptr %503, align 1, !tbaa !33
  store i16 0, ptr %502, align 1, !tbaa !35
  %504 = getelementptr inbounds nuw i8, ptr %502, i16 9
  store i8 0, ptr %504, align 1, !tbaa !36
  %505 = getelementptr inbounds nuw i8, ptr %502, i16 7
  store i8 34, ptr %505, align 1, !tbaa !37
  %506 = getelementptr inbounds nuw i8, ptr %502, i16 8
  store i8 0, ptr %506, align 1, !tbaa !38
  %507 = getelementptr inbounds nuw i8, ptr %502, i16 2
  store i16 ptrtoint (ptr @title_end._title_bg_black to i16), ptr %507, align 1, !tbaa !39
  %508 = getelementptr inbounds nuw i8, ptr %502, i16 6
  store i8 0, ptr %508, align 1, !tbaa !40
  %509 = getelementptr inbounds nuw i8, ptr %502, i16 4
  store i16 2, ptr %509, align 1, !tbaa !41
  br label %510

510:                                              ; preds = %490, %499
  store i16 3855, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1
  br label %511

511:                                              ; preds = %539, %510
  tail call fastcc void @app_frame() #13
  %512 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %513 = icmp eq i8 %512, 0
  br i1 %513, label %525, label %514

514:                                              ; preds = %511, %514
  %515 = phi i8 [ %522, %514 ], [ 0, %511 ]
  %516 = zext i8 %515 to i16
  %517 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %516
  %518 = load ptr, ptr %517, align 1, !tbaa !26
  %519 = load ptr, ptr %518, align 1, !tbaa !73
  %520 = getelementptr inbounds nuw i8, ptr %519, i16 2
  %521 = load ptr, ptr %520, align 1, !tbaa !74
  tail call void %521(ptr noundef nonnull %518, ptr noundef nonnull @main.a) #12, !inline_history !92
  %522 = add nuw i8 %515, 1
  %523 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %524 = icmp ult i8 %522, %523
  br i1 %524, label %514, label %525, !llvm.loop !77

525:                                              ; preds = %514, %511
  %526 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %527

527:                                              ; preds = %527, %525
  %528 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %529 = icmp sgt i8 %528, -1
  br i1 %529, label %527, label %530, !llvm.loop !78

530:                                              ; preds = %527
  tail call fastcc void @upq_flush() #13
  %531 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %532 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %533 = icmp ult i8 %531, %532
  br i1 %533, label %536, label %534

534:                                              ; preds = %530
  %535 = icmp ugt i8 %531, %532
  br i1 %535, label %536, label %539

536:                                              ; preds = %534, %530
  %537 = phi i8 [ 1, %530 ], [ -1, %534 ]
  %538 = add i8 %537, %531
  store i8 %538, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %539

539:                                              ; preds = %534, %536
  %540 = phi i8 [ %531, %534 ], [ %538, %536 ]
  %541 = and i8 %540, 15
  store volatile i8 %541, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  br label %511
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc void @app_frame() unnamed_addr #1 {
  br label %1

1:                                                ; preds = %41, %0
  %2 = phi i8 [ 0, %0 ], [ %45, %41 ]
  %3 = phi i8 [ 0, %0 ], [ %43, %41 ]
  %4 = tail call fastcc { i16, i16 } @boid_acc(ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @main.a, i16 746), i8 noundef zeroext 32, i8 noundef zeroext %3) #13
  %5 = extractvalue { i16, i16 } %4, 0
  %6 = extractvalue { i16, i16 } %4, 1
  %7 = zext i8 %2 to i16
  %8 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 746), i16 %7
  %9 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 750), i16 %7
  %10 = load i16, ptr %9, align 1
  %11 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 752), i16 %7
  %12 = load i16, ptr %11, align 1
  %13 = tail call fastcc { i16, i16 } @v2_add(i16 %10, i16 %12, i16 %5, i16 %6) #13
  %14 = extractvalue { i16, i16 } %13, 0
  %15 = extractvalue { i16, i16 } %13, 1
  %16 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %14, i16 %15, i16 noundef 40) #13
  %17 = extractvalue { i16, i16 } %16, 0
  %18 = extractvalue { i16, i16 } %16, 1
  store i16 %17, ptr %9, align 1, !tbaa !2
  store i16 %18, ptr %11, align 1, !tbaa !2
  %19 = load i16, ptr %8, align 1
  %20 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 748), i16 %7
  %21 = load i16, ptr %20, align 1
  %22 = tail call fastcc { i16, i16 } @v2_add(i16 %19, i16 %21, i16 %17, i16 %18) #13
  %23 = extractvalue { i16, i16 } %22, 0
  %24 = extractvalue { i16, i16 } %22, 1
  %25 = icmp slt i16 %23, 0
  br i1 %25, label %26, label %28

26:                                               ; preds = %1
  %27 = add nsw i16 %23, 4096
  br label %32

28:                                               ; preds = %1
  %29 = icmp samesign ult i16 %23, 4096
  br i1 %29, label %32, label %30

30:                                               ; preds = %28
  %31 = add nsw i16 %23, -4096
  br label %32

32:                                               ; preds = %30, %28, %26
  %33 = phi i16 [ %27, %26 ], [ %31, %30 ], [ %23, %28 ]
  %34 = icmp slt i16 %24, 0
  br i1 %34, label %35, label %37

35:                                               ; preds = %32
  %36 = add nsw i16 %24, 3584
  br label %41

37:                                               ; preds = %32
  %38 = icmp samesign ult i16 %24, 3584
  br i1 %38, label %41, label %39

39:                                               ; preds = %37
  %40 = add nsw i16 %24, -3584
  br label %41

41:                                               ; preds = %39, %37, %35
  %42 = phi i16 [ %36, %35 ], [ %40, %39 ], [ %24, %37 ]
  store i16 %33, ptr %8, align 1, !tbaa !2
  store i16 %42, ptr %20, align 1, !tbaa !2
  %43 = add nuw nsw i8 %3, 1
  %44 = icmp eq i8 %43, 32
  %45 = add i8 %2, 8
  br i1 %44, label %47, label %1, !llvm.loop !82

46:                                               ; preds = %113
  ret void

47:                                               ; preds = %41, %113
  %48 = phi i8 [ %118, %113 ], [ 0, %41 ]
  %49 = phi i8 [ %117, %113 ], [ 0, %41 ]
  %50 = phi i8 [ %115, %113 ], [ 0, %41 ]
  %51 = zext i8 %49 to i16
  %52 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 746), i16 %51
  %53 = load i16, ptr %52, align 1, !tbaa !43
  %54 = lshr i16 %53, 4
  %55 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 748), i16 %51
  %56 = load i16, ptr %55, align 1, !tbaa !45
  %57 = lshr i16 %56, 4
  %58 = trunc i16 %57 to i8
  %59 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 750), i16 %51
  %60 = load i16, ptr %59, align 1
  %61 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 752), i16 %51
  %62 = load i16, ptr %61, align 1
  %63 = icmp slt i16 %60, 0
  br i1 %63, label %64, label %66

64:                                               ; preds = %47
  %65 = sub nsw i16 0, %60
  br label %66

66:                                               ; preds = %64, %47
  %67 = phi i16 [ %65, %64 ], [ %60, %47 ]
  %68 = icmp slt i16 %62, 0
  br i1 %68, label %69, label %71

69:                                               ; preds = %66
  %70 = sub nsw i16 0, %62
  br label %71

71:                                               ; preds = %69, %66
  %72 = phi i16 [ %70, %69 ], [ %62, %66 ]
  %73 = icmp sgt i16 %60, -1
  %74 = icmp sgt i16 %62, -1
  br i1 %73, label %75, label %79

75:                                               ; preds = %71
  br i1 %74, label %76, label %86

76:                                               ; preds = %75
  %77 = icmp samesign ult i16 %67, %72
  %78 = zext i1 %77 to i8
  br label %89

79:                                               ; preds = %71
  br i1 %74, label %80, label %83

80:                                               ; preds = %79
  %81 = icmp samesign ult i16 %72, %67
  %82 = select i1 %81, i8 3, i8 2
  br label %89

83:                                               ; preds = %79
  %84 = icmp samesign ult i16 %67, %72
  %85 = select i1 %84, i8 5, i8 4
  br label %89

86:                                               ; preds = %75
  %87 = icmp samesign ult i16 %72, %67
  %88 = select i1 %87, i8 7, i8 6
  br label %89

89:                                               ; preds = %76, %80, %83, %86
  %90 = phi i8 [ %78, %76 ], [ %82, %80 ], [ %85, %83 ], [ %88, %86 ]
  %91 = shl nuw nsw i8 %90, 1
  %92 = or disjoint i8 %91, 32
  %93 = trunc i16 %54 to i8
  %94 = zext i8 %48 to i16
  %95 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 199), i16 %94
  store i8 %93, ptr %95, align 1, !tbaa !6
  %96 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 200), i16 %94
  store i8 %58, ptr %96, align 1, !tbaa !6
  %97 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 201), i16 %94
  store i8 0, ptr %97, align 1, !tbaa !6
  %98 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 202), i16 %94
  store i8 %92, ptr %98, align 1, !tbaa !6
  %99 = shl nuw nsw i8 %50, 1
  %100 = and i8 %99, 6
  %101 = lshr i8 %50, 2
  %102 = zext nneg i8 %101 to i16
  %103 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 711), i16 %102
  %104 = load i8, ptr %103, align 1, !tbaa !6
  %105 = shl nuw i8 3, %100
  %106 = xor i8 %105, -1
  %107 = and i8 %104, %106
  %108 = and i16 %53, 4096
  %109 = icmp eq i16 %108, 0
  br i1 %109, label %113, label %110

110:                                              ; preds = %89
  %111 = shl nuw nsw i8 1, %100
  %112 = or i8 %107, %111
  br label %113

113:                                              ; preds = %89, %110
  %114 = phi i8 [ %112, %110 ], [ %107, %89 ]
  store i8 %114, ptr %103, align 1, !tbaa !6
  %115 = add nuw nsw i8 %50, 1
  %116 = icmp eq i8 %115, 32
  %117 = add i8 %49, 8
  %118 = add nuw i8 %48, 4
  br i1 %116, label %46, label %47, !llvm.loop !93
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #2

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal void @_sprite_reserve(ptr noundef readonly captures(none) %0, ptr readnone captures(none) %1) #3 {
  %3 = getelementptr inbounds nuw i8, ptr %0, i16 549
  %4 = load i8, ptr %3, align 1, !tbaa !20
  %5 = zext i8 %4 to i16
  %6 = shl nuw nsw i16 %5, 5
  %7 = getelementptr inbounds nuw i8, ptr %0, i16 547
  %8 = load i16, ptr %7, align 1, !tbaa !21
  %9 = lshr i16 %8, 13
  %10 = or disjoint i16 %6, %9
  %11 = trunc i16 %10 to i8
  store volatile i8 %11, ptr inttoptr (i16 8449 to ptr), align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: readwrite)
define internal void @_sprite_emit(ptr noundef %0, ptr noundef captures(none) %1) #4 {
  %3 = getelementptr inbounds nuw i8, ptr %1, i16 176
  %4 = load i8, ptr %3, align 1, !tbaa !32
  %5 = icmp ugt i8 %4, 15
  br i1 %5, label %19, label %6

6:                                                ; preds = %2
  %7 = getelementptr inbounds nuw i8, ptr %0, i16 3
  %8 = zext nneg i8 %4 to i16
  %9 = add nuw nsw i8 %4, 1
  store i8 %9, ptr %3, align 1, !tbaa !32
  %10 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %8
  %11 = getelementptr inbounds nuw i8, ptr %10, i16 10
  store i8 2, ptr %11, align 1, !tbaa !33
  store i16 0, ptr %10, align 1, !tbaa !35
  %12 = getelementptr inbounds nuw i8, ptr %10, i16 9
  store i8 0, ptr %12, align 1, !tbaa !36
  %13 = getelementptr inbounds nuw i8, ptr %10, i16 7
  store i8 4, ptr %13, align 1, !tbaa !37
  %14 = getelementptr inbounds nuw i8, ptr %10, i16 8
  store i8 0, ptr %14, align 1, !tbaa !38
  %15 = ptrtoint ptr %7 to i16
  %16 = getelementptr inbounds nuw i8, ptr %10, i16 2
  store i16 %15, ptr %16, align 1, !tbaa !39
  %17 = getelementptr inbounds nuw i8, ptr %10, i16 6
  store i8 0, ptr %17, align 1, !tbaa !40
  %18 = getelementptr inbounds nuw i8, ptr %10, i16 4
  store i16 544, ptr %18, align 1, !tbaa !41
  br label %19

19:                                               ; preds = %2, %6
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal void @_title_reserve(ptr noundef %0, ptr readnone captures(none) %1) #3 {
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
  br i1 %14, label %20, label %7, !llvm.loop !94

16:                                               ; preds = %20
  %17 = add nuw nsw i16 %5, 1
  %18 = getelementptr i8, ptr %4, i16 16
  %19 = icmp eq i16 %17, 64
  br i1 %19, label %6, label %3, !llvm.loop !95

20:                                               ; preds = %7, %20
  %21 = phi i8 [ %22, %20 ], [ 0, %7 ]
  store volatile i16 0, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %22 = add nuw nsw i8 %21, 1
  %23 = icmp eq i8 %22, 8
  br i1 %23, label %16, label %20, !llvm.loop !96

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
  br i1 %37, label %28, label %24, !llvm.loop !97

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
  br i1 %45, label %53, label %38, !llvm.loop !98

47:                                               ; preds = %53
  %48 = add nuw nsw i8 %32, 1
  %49 = zext nneg i8 %30 to i16
  %50 = getelementptr i8, ptr %25, i16 %49
  %51 = icmp eq i8 %48, 4
  %52 = add nuw nsw i8 %30, 16
  br i1 %51, label %33, label %29, !llvm.loop !99

53:                                               ; preds = %38, %53
  %54 = phi i8 [ %55, %53 ], [ 0, %38 ]
  store volatile i16 0, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %55 = add nuw nsw i8 %54, 1
  %56 = icmp eq i8 %55, 8
  br i1 %56, label %47, label %53, !llvm.loop !100

57:                                               ; preds = %66
  %58 = getelementptr inbounds nuw i8, ptr %0, i16 3
  %59 = load ptr, ptr %58, align 1, !tbaa !54
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
  br i1 %69, label %57, label %66, !llvm.loop !101

70:                                               ; preds = %64, %70
  %71 = phi i8 [ %72, %70 ], [ 0, %64 ]
  %72 = add nuw nsw i8 %71, 1
  %73 = zext nneg i8 %71 to i16
  %74 = getelementptr i8, ptr %65, i16 %73
  %75 = load i8, ptr %74, align 1, !tbaa !6
  %76 = icmp ne i8 %75, 0
  %77 = icmp samesign ult i8 %71, 31
  %78 = select i1 %76, i1 %77, i1 false
  br i1 %78, label %70, label %79, !llvm.loop !102

79:                                               ; preds = %70, %61, %57
  %80 = phi i8 [ 0, %57 ], [ 0, %61 ], [ %72, %70 ]
  %81 = zext nneg i8 %80 to i16
  %82 = sub nuw nsw i16 32, %81
  %83 = lshr i16 %82, 1
  %84 = getelementptr inbounds nuw i8, ptr %0, i16 13
  %85 = load i16, ptr %84, align 1, !tbaa !60
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
  %95 = load ptr, ptr %94, align 1, !tbaa !56
  %96 = getelementptr inbounds nuw i8, ptr %0, i16 11
  %97 = load i8, ptr %96, align 1, !tbaa !57
  %98 = getelementptr inbounds nuw i8, ptr %0, i16 15
  %99 = load i16, ptr %98, align 1, !tbaa !61
  %100 = lshr i16 %99, 3
  %101 = trunc i16 %100 to i8
  tail call fastcc void @_title_write16(ptr noundef %95, i8 noundef zeroext %97, i8 noundef zeroext %101) #13
  %102 = getelementptr inbounds nuw i8, ptr %0, i16 9
  %103 = load ptr, ptr %102, align 1, !tbaa !58
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
  br i1 %131, label %93, label %105, !llvm.loop !103

132:                                              ; preds = %93
  %133 = getelementptr inbounds nuw i8, ptr %0, i16 12
  %134 = load i8, ptr %133, align 1, !tbaa !59
  %135 = load i16, ptr %98, align 1, !tbaa !61
  %136 = lshr i16 %135, 3
  %137 = trunc i16 %136 to i8
  %138 = add i8 %137, 2
  tail call fastcc void @_title_write16(ptr noundef nonnull %103, i8 noundef zeroext %134, i8 noundef zeroext %138) #13
  br label %139

139:                                              ; preds = %132, %93
  %140 = getelementptr inbounds nuw i8, ptr %0, i16 19
  store i16 -128, ptr %140, align 1, !tbaa !90
  %141 = getelementptr inbounds nuw i8, ptr %0, i16 21
  store i16 3584, ptr %141, align 1, !tbaa !104
  %142 = getelementptr inbounds nuw i8, ptr %0, i16 23
  store i16 0, ptr %142, align 1, !tbaa !105
  %143 = load ptr, ptr %58, align 1, !tbaa !54
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
  br i1 %166, label %158, label %150, !llvm.loop !106

167:                                              ; preds = %139, %150
  %168 = phi i16 [ %157, %150 ], [ 0, %139 ]
  %169 = getelementptr inbounds nuw i8, ptr %0, i16 26
  store i16 %168, ptr %169, align 1, !tbaa !107
  store volatile i8 -112, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  %170 = getelementptr inbounds nuw i8, ptr %0, i16 38
  %171 = getelementptr inbounds nuw i8, ptr %0, i16 89
  tail call fastcc void @_title_build(ptr noundef nonnull %0, i16 noundef -8, i16 noundef 224, ptr noundef nonnull %170, ptr noundef nonnull %171) #13
  %172 = getelementptr inbounds nuw i8, ptr %0, i16 88
  store i8 0, ptr %172, align 1, !tbaa !108
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
  store i8 0, ptr %177, align 1, !tbaa !108
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
  store i8 2, ptr %182, align 1, !tbaa !53
  ret void
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal void @_title_emit(ptr noundef %0, ptr noundef captures(none) %1) #5 {
  %3 = getelementptr inbounds nuw i8, ptr %0, i16 29
  %4 = load i8, ptr %3, align 1, !tbaa !64
  %5 = icmp eq i8 %4, 0
  br i1 %5, label %188, label %6

6:                                                ; preds = %2
  %7 = getelementptr inbounds nuw i8, ptr %0, i16 30
  %8 = load i8, ptr %7, align 1, !tbaa !67
  %9 = icmp eq i8 %8, 0
  br i1 %9, label %39, label %10

10:                                               ; preds = %6
  %11 = getelementptr inbounds nuw i8, ptr %0, i16 25
  %12 = load i8, ptr %11, align 1, !tbaa !68
  %13 = icmp ugt i8 %12, -6
  br i1 %13, label %16, label %14

14:                                               ; preds = %10
  %15 = add nuw i8 %12, 4
  br label %16

16:                                               ; preds = %10, %14
  %17 = phi i8 [ %15, %14 ], [ -1, %10 ]
  store i8 %17, ptr %11, align 1, !tbaa !68
  %18 = getelementptr inbounds nuw i8, ptr %0, i16 13
  %19 = load i16, ptr %18, align 1, !tbaa !60
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
  store i16 %29, ptr %30, align 1, !tbaa !90
  %31 = getelementptr inbounds nuw i8, ptr %0, i16 15
  %32 = load i16, ptr %31, align 1, !tbaa !61
  %33 = add nsw i16 %32, -224
  %34 = mul nsw i16 %33, %24
  %35 = ashr i16 %34, 4
  %36 = and i16 %35, -16
  %37 = add nsw i16 %36, 3584
  %38 = getelementptr inbounds nuw i8, ptr %0, i16 21
  store i16 %37, ptr %38, align 1, !tbaa !104
  br label %64

39:                                               ; preds = %6
  %40 = getelementptr inbounds nuw i8, ptr %0, i16 31
  %41 = load i8, ptr %40, align 1, !tbaa !65
  %42 = icmp eq i8 %41, 0
  br i1 %42, label %43, label %48

43:                                               ; preds = %39
  %44 = getelementptr inbounds nuw i8, ptr %0, i16 19
  %45 = load i16, ptr %44, align 1, !tbaa !90
  %46 = getelementptr inbounds nuw i8, ptr %0, i16 21
  %47 = load i16, ptr %46, align 1, !tbaa !104
  br label %64

48:                                               ; preds = %39
  %49 = getelementptr inbounds nuw i8, ptr %0, i16 23
  %50 = load i16, ptr %49, align 1, !tbaa !105
  %51 = add nsw i16 %50, 2
  store i16 %51, ptr %49, align 1, !tbaa !105
  %52 = getelementptr inbounds nuw i8, ptr %0, i16 19
  %53 = load i16, ptr %52, align 1, !tbaa !90
  %54 = add nsw i16 %53, %51
  store i16 %54, ptr %52, align 1, !tbaa !90
  %55 = getelementptr inbounds nuw i8, ptr %0, i16 21
  %56 = load i16, ptr %55, align 1, !tbaa !104
  %57 = add nsw i16 %56, %51
  store i16 %57, ptr %55, align 1, !tbaa !104
  %58 = icmp sgt i16 %54, 4480
  br i1 %58, label %59, label %60

59:                                               ; preds = %48
  store i16 4480, ptr %52, align 1, !tbaa !90
  br label %60

60:                                               ; preds = %59, %48
  %61 = phi i16 [ 4480, %59 ], [ %54, %48 ]
  %62 = icmp sgt i16 %57, 4736
  br i1 %62, label %63, label %64

63:                                               ; preds = %60
  store i16 4736, ptr %55, align 1, !tbaa !104
  br label %64

64:                                               ; preds = %43, %63, %60, %16
  %65 = phi i16 [ %47, %43 ], [ 4736, %63 ], [ %57, %60 ], [ %37, %16 ]
  %66 = phi i16 [ %45, %43 ], [ %61, %63 ], [ %61, %60 ], [ %29, %16 ]
  %67 = ashr i16 %66, 4
  %68 = ashr i16 %65, 4
  %69 = getelementptr inbounds nuw i8, ptr %0, i16 38
  %70 = getelementptr inbounds nuw i8, ptr %0, i16 88
  %71 = load i8, ptr %70, align 1, !tbaa !108
  %72 = xor i8 %71, 1
  %73 = zext i8 %72 to i16
  %74 = getelementptr inbounds nuw [25 x i8], ptr %69, i16 %73
  %75 = getelementptr inbounds nuw i8, ptr %0, i16 89
  %76 = getelementptr inbounds nuw i8, ptr %0, i16 139
  %77 = load i8, ptr %76, align 1, !tbaa !108
  %78 = xor i8 %77, 1
  %79 = zext i8 %78 to i16
  %80 = getelementptr inbounds nuw [25 x i8], ptr %75, i16 %79
  tail call fastcc void @_title_build(ptr noundef nonnull %0, i16 noundef %67, i16 noundef %68, ptr noundef nonnull %74, ptr noundef nonnull %80) #13
  %81 = getelementptr inbounds nuw i8, ptr %1, i16 176
  %82 = load i8, ptr %81, align 1, !tbaa !32
  %83 = icmp ugt i8 %82, 15
  br i1 %83, label %109, label %84

84:                                               ; preds = %64
  %85 = load i8, ptr %70, align 1, !tbaa !108
  %86 = xor i8 %85, 1
  %87 = zext i8 %86 to i16
  %88 = getelementptr inbounds nuw [25 x i8], ptr %69, i16 %87
  %89 = ptrtoint ptr %88 to i16
  %90 = zext nneg i8 %82 to i16
  %91 = add nuw nsw i8 %82, 1
  store i8 %91, ptr %81, align 1, !tbaa !32
  %92 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %90
  %93 = getelementptr inbounds nuw i8, ptr %92, i16 10
  store i8 4, ptr %93, align 1, !tbaa !33
  store i16 17202, ptr %92, align 1, !tbaa !35
  %94 = getelementptr inbounds nuw i8, ptr %92, i16 2
  store i16 %89, ptr %94, align 1, !tbaa !39
  %95 = getelementptr inbounds nuw i8, ptr %92, i16 4
  store i16 0, ptr %95, align 1, !tbaa !41
  store i8 %86, ptr %70, align 1, !tbaa !108
  %96 = icmp eq i8 %82, 15
  br i1 %96, label %109, label %97

97:                                               ; preds = %84
  %98 = load i8, ptr %76, align 1, !tbaa !108
  %99 = xor i8 %98, 1
  %100 = zext i8 %99 to i16
  %101 = getelementptr inbounds nuw [25 x i8], ptr %75, i16 %100
  %102 = ptrtoint ptr %101 to i16
  %103 = zext nneg i8 %91 to i16
  %104 = add nuw nsw i8 %82, 2
  store i8 %104, ptr %81, align 1, !tbaa !32
  %105 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %103
  %106 = getelementptr inbounds nuw i8, ptr %105, i16 10
  store i8 4, ptr %106, align 1, !tbaa !33
  store i16 17218, ptr %105, align 1, !tbaa !35
  %107 = getelementptr inbounds nuw i8, ptr %105, i16 2
  store i16 %102, ptr %107, align 1, !tbaa !39
  %108 = getelementptr inbounds nuw i8, ptr %105, i16 4
  store i16 0, ptr %108, align 1, !tbaa !41
  store i8 %99, ptr %76, align 1, !tbaa !108
  br label %109

109:                                              ; preds = %64, %84, %97
  %110 = phi i8 [ %82, %64 ], [ 16, %84 ], [ %104, %97 ]
  %111 = getelementptr inbounds nuw i8, ptr %0, i16 28
  %112 = load i8, ptr %111, align 1, !tbaa !63
  %113 = add i8 %112, 1
  store i8 %113, ptr %111, align 1, !tbaa !63
  %114 = getelementptr inbounds nuw i8, ptr %0, i16 32
  %115 = load i8, ptr %114, align 1, !tbaa !66
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
  store i16 %127, ptr %128, align 1, !tbaa !69
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
  store i16 29596, ptr %156, align 1, !tbaa !69
  br label %157

157:                                              ; preds = %155, %150
  %158 = phi i16 [ 0, %155 ], [ %154, %150 ]
  %159 = getelementptr inbounds nuw i8, ptr %0, i16 36
  store i16 %158, ptr %159, align 1, !tbaa !70
  %160 = icmp ugt i8 %110, 15
  br i1 %160, label %188, label %161

161:                                              ; preds = %157
  %162 = getelementptr inbounds nuw i8, ptr %0, i16 34
  %163 = zext nneg i8 %110 to i16
  %164 = add nuw nsw i8 %110, 1
  store i8 %164, ptr %81, align 1, !tbaa !32
  %165 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %163
  %166 = getelementptr inbounds nuw i8, ptr %165, i16 10
  store i8 1, ptr %166, align 1, !tbaa !33
  store i16 113, ptr %165, align 1, !tbaa !35
  %167 = getelementptr inbounds nuw i8, ptr %165, i16 9
  store i8 0, ptr %167, align 1, !tbaa !36
  %168 = getelementptr inbounds nuw i8, ptr %165, i16 7
  store i8 34, ptr %168, align 1, !tbaa !37
  %169 = getelementptr inbounds nuw i8, ptr %165, i16 8
  store i8 0, ptr %169, align 1, !tbaa !38
  %170 = ptrtoint ptr %162 to i16
  %171 = getelementptr inbounds nuw i8, ptr %165, i16 2
  store i16 %170, ptr %171, align 1, !tbaa !39
  %172 = getelementptr inbounds nuw i8, ptr %165, i16 6
  store i8 0, ptr %172, align 1, !tbaa !40
  %173 = getelementptr inbounds nuw i8, ptr %165, i16 4
  store i16 2, ptr %173, align 1, !tbaa !41
  %174 = icmp eq i8 %110, 15
  br i1 %174, label %188, label %175

175:                                              ; preds = %161
  %176 = getelementptr inbounds nuw i8, ptr %0, i16 36
  %177 = zext nneg i8 %164 to i16
  %178 = add nuw nsw i8 %110, 2
  store i8 %178, ptr %81, align 1, !tbaa !32
  %179 = getelementptr inbounds nuw [11 x i8], ptr %1, i16 %177
  %180 = getelementptr inbounds nuw i8, ptr %179, i16 10
  store i8 1, ptr %180, align 1, !tbaa !33
  store i16 0, ptr %179, align 1, !tbaa !35
  %181 = getelementptr inbounds nuw i8, ptr %179, i16 9
  store i8 0, ptr %181, align 1, !tbaa !36
  %182 = getelementptr inbounds nuw i8, ptr %179, i16 7
  store i8 34, ptr %182, align 1, !tbaa !37
  %183 = getelementptr inbounds nuw i8, ptr %179, i16 8
  store i8 0, ptr %183, align 1, !tbaa !38
  %184 = ptrtoint ptr %176 to i16
  %185 = getelementptr inbounds nuw i8, ptr %179, i16 2
  store i16 %184, ptr %185, align 1, !tbaa !39
  %186 = getelementptr inbounds nuw i8, ptr %179, i16 6
  store i8 0, ptr %186, align 1, !tbaa !40
  %187 = getelementptr inbounds nuw i8, ptr %179, i16 4
  store i16 2, ptr %187, align 1, !tbaa !41
  br label %188

188:                                              ; preds = %157, %175, %161, %2
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal fastcc void @_title_write16(ptr noundef readonly captures(address_is_null) %0, i8 noundef zeroext %1, i8 noundef zeroext %2) unnamed_addr #3 {
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
  br i1 %16, label %15, label %14, !llvm.loop !109

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
  br i1 %59, label %23, label %24, !llvm.loop !110
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @_title_build(ptr noundef readonly captures(none) %0, i16 noundef range(i16 -2048, 2048) %1, i16 noundef range(i16 -2048, 2048) %2, ptr noundef %3, ptr noundef %4) unnamed_addr #5 {
  %6 = alloca %struct.HScrollW, align 1
  %7 = alloca %struct.HScrollW, align 1
  %8 = alloca i16, align 1
  call void @llvm.lifetime.start.p0(ptr nonnull %6) #14
  call void @llvm.lifetime.start.p0(ptr nonnull %7) #14
  call void @llvm.lifetime.start.p0(ptr nonnull %8) #14
  store i16 0, ptr %8, align 1, !tbaa !2
  store ptr %3, ptr %6, align 1, !tbaa !111
  %9 = getelementptr inbounds nuw i8, ptr %6, i16 2
  store i8 0, ptr %9, align 1, !tbaa !113
  store ptr %4, ptr %7, align 1, !tbaa !111
  %10 = getelementptr inbounds nuw i8, ptr %7, i16 2
  store i8 0, ptr %10, align 1, !tbaa !113
  %11 = getelementptr inbounds nuw i8, ptr %0, i16 13
  %12 = load i16, ptr %11, align 1, !tbaa !60
  %13 = getelementptr inbounds nuw i8, ptr %0, i16 26
  %14 = load i16, ptr %13, align 1, !tbaa !107
  call fastcc void @_title_glyph_band(ptr noundef %6, ptr noundef %7, ptr noundef %8, i16 noundef %1, i16 noundef 8, i16 noundef %12, i16 noundef %14) #13
  %15 = getelementptr inbounds nuw i8, ptr %0, i16 17
  %16 = load i16, ptr %15, align 1, !tbaa !62
  %17 = getelementptr inbounds nuw i8, ptr %0, i16 15
  %18 = load i16, ptr %17, align 1, !tbaa !61
  call fastcc void @_title_glyph_band(ptr noundef %6, ptr noundef %7, ptr noundef %8, i16 noundef %2, i16 noundef %16, i16 noundef %18, i16 noundef 0) #13
  %19 = load i16, ptr %8, align 1, !tbaa !2
  call fastcc void @_title_blank(ptr noundef %6, ptr noundef %7, i16 noundef %19, i16 noundef 224) #13
  %20 = load ptr, ptr %6, align 1, !tbaa !111
  %21 = load i8, ptr %9, align 1, !tbaa !113
  %22 = zext i8 %21 to i16
  %23 = getelementptr inbounds nuw i8, ptr %20, i16 %22
  store i8 0, ptr %23, align 1, !tbaa !6
  %24 = load ptr, ptr %7, align 1, !tbaa !111
  %25 = load i8, ptr %10, align 1, !tbaa !113
  %26 = zext i8 %25 to i16
  %27 = getelementptr inbounds nuw i8, ptr %24, i16 %26
  store i8 0, ptr %27, align 1, !tbaa !6
  call void @llvm.lifetime.end.p0(ptr nonnull %8) #14
  call void @llvm.lifetime.end.p0(ptr nonnull %7) #14
  call void @llvm.lifetime.end.p0(ptr nonnull %6) #14
  ret void
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @_title_glyph_band(ptr noundef nonnull captures(none) %0, ptr noundef nonnull captures(none) %1, ptr noundef nonnull captures(none) %2, i16 noundef range(i16 -2048, 2048) %3, i16 noundef %4, i16 noundef %5, i16 noundef %6) unnamed_addr #5 {
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
  tail call fastcc void @_title_blank(ptr noundef %0, ptr noundef %1, i16 noundef %11, i16 noundef %15) #13
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
  %34 = load i8, ptr %24, align 1, !tbaa !113
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
  %42 = load ptr, ptr %0, align 1, !tbaa !111
  %43 = add nuw nsw i8 %34, 1
  store i8 %43, ptr %24, align 1, !tbaa !113
  %44 = zext nneg i8 %34 to i16
  %45 = getelementptr inbounds nuw i8, ptr %42, i16 %44
  store i8 %41, ptr %45, align 1, !tbaa !6
  %46 = load ptr, ptr %0, align 1, !tbaa !111
  %47 = load i8, ptr %24, align 1, !tbaa !113
  %48 = add i8 %47, 1
  store i8 %48, ptr %24, align 1, !tbaa !113
  %49 = zext i8 %47 to i16
  %50 = getelementptr inbounds nuw i8, ptr %46, i16 %49
  store i8 %29, ptr %50, align 1, !tbaa !6
  %51 = load ptr, ptr %0, align 1, !tbaa !111
  %52 = load i8, ptr %24, align 1, !tbaa !113
  %53 = add i8 %52, 1
  store i8 %53, ptr %24, align 1, !tbaa !113
  %54 = zext i8 %52 to i16
  %55 = getelementptr inbounds nuw i8, ptr %51, i16 %54
  store i8 %31, ptr %55, align 1, !tbaa !6
  %56 = zext nneg i8 %41 to i16
  %57 = sub i16 %33, %56
  %58 = icmp eq i16 %57, 0
  br i1 %58, label %59, label %32, !llvm.loop !114

59:                                               ; preds = %32, %40
  %60 = getelementptr inbounds nuw i8, ptr %1, i16 2
  %61 = trunc i16 %6 to i8
  %62 = lshr i16 %6, 8
  %63 = trunc nuw i16 %62 to i8
  br label %64

64:                                               ; preds = %72, %59
  %65 = phi i16 [ %28, %59 ], [ %89, %72 ]
  %66 = load i8, ptr %60, align 1, !tbaa !113
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
  %74 = load ptr, ptr %1, align 1, !tbaa !111
  %75 = add nuw nsw i8 %66, 1
  store i8 %75, ptr %60, align 1, !tbaa !113
  %76 = zext nneg i8 %66 to i16
  %77 = getelementptr inbounds nuw i8, ptr %74, i16 %76
  store i8 %73, ptr %77, align 1, !tbaa !6
  %78 = load ptr, ptr %1, align 1, !tbaa !111
  %79 = load i8, ptr %60, align 1, !tbaa !113
  %80 = add i8 %79, 1
  store i8 %80, ptr %60, align 1, !tbaa !113
  %81 = zext i8 %79 to i16
  %82 = getelementptr inbounds nuw i8, ptr %78, i16 %81
  store i8 %61, ptr %82, align 1, !tbaa !6
  %83 = load ptr, ptr %1, align 1, !tbaa !111
  %84 = load i8, ptr %60, align 1, !tbaa !113
  %85 = add i8 %84, 1
  store i8 %85, ptr %60, align 1, !tbaa !113
  %86 = zext i8 %84 to i16
  %87 = getelementptr inbounds nuw i8, ptr %83, i16 %86
  store i8 %63, ptr %87, align 1, !tbaa !6
  %88 = zext nneg i8 %73 to i16
  %89 = sub i16 %65, %88
  %90 = icmp eq i16 %89, 0
  br i1 %90, label %91, label %64, !llvm.loop !114

91:                                               ; preds = %64, %72, %21
  store i16 %19, ptr %2, align 1, !tbaa !2
  br label %92

92:                                               ; preds = %18, %91
  ret void
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @_title_blank(ptr noundef nonnull captures(none) %0, ptr noundef nonnull captures(none) %1, i16 noundef %2, i16 noundef range(i16 -2050, 225) %3) unnamed_addr #5 {
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
  %26 = load i8, ptr %7, align 1, !tbaa !113
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
  %34 = load ptr, ptr %0, align 1, !tbaa !111
  %35 = add nuw nsw i8 %26, 1
  store i8 %35, ptr %7, align 1, !tbaa !113
  %36 = zext nneg i8 %26 to i16
  %37 = getelementptr inbounds nuw i8, ptr %34, i16 %36
  store i8 %33, ptr %37, align 1, !tbaa !6
  %38 = load ptr, ptr %0, align 1, !tbaa !111
  %39 = load i8, ptr %7, align 1, !tbaa !113
  %40 = add i8 %39, 1
  store i8 %40, ptr %7, align 1, !tbaa !113
  %41 = zext i8 %39 to i16
  %42 = getelementptr inbounds nuw i8, ptr %38, i16 %41
  store i8 %21, ptr %42, align 1, !tbaa !6
  %43 = load ptr, ptr %0, align 1, !tbaa !111
  %44 = load i8, ptr %7, align 1, !tbaa !113
  %45 = add i8 %44, 1
  store i8 %45, ptr %7, align 1, !tbaa !113
  %46 = zext i8 %44 to i16
  %47 = getelementptr inbounds nuw i8, ptr %43, i16 %46
  store i8 %23, ptr %47, align 1, !tbaa !6
  %48 = zext nneg i8 %33 to i16
  %49 = sub i16 %25, %48
  %50 = icmp eq i16 %49, 0
  br i1 %50, label %51, label %24, !llvm.loop !114

51:                                               ; preds = %24, %32
  br label %52

52:                                               ; preds = %51, %60
  %53 = phi i16 [ %77, %60 ], [ %20, %51 ]
  %54 = load i8, ptr %8, align 1, !tbaa !113
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
  %62 = load ptr, ptr %1, align 1, !tbaa !111
  %63 = add nuw nsw i8 %54, 1
  store i8 %63, ptr %8, align 1, !tbaa !113
  %64 = zext nneg i8 %54 to i16
  %65 = getelementptr inbounds nuw i8, ptr %62, i16 %64
  store i8 %61, ptr %65, align 1, !tbaa !6
  %66 = load ptr, ptr %1, align 1, !tbaa !111
  %67 = load i8, ptr %8, align 1, !tbaa !113
  %68 = add i8 %67, 1
  store i8 %68, ptr %8, align 1, !tbaa !113
  %69 = zext i8 %67 to i16
  %70 = getelementptr inbounds nuw i8, ptr %66, i16 %69
  store i8 0, ptr %70, align 1, !tbaa !6
  %71 = load ptr, ptr %1, align 1, !tbaa !111
  %72 = load i8, ptr %8, align 1, !tbaa !113
  %73 = add i8 %72, 1
  store i8 %73, ptr %8, align 1, !tbaa !113
  %74 = zext i8 %72 to i16
  %75 = getelementptr inbounds nuw i8, ptr %71, i16 %74
  store i8 0, ptr %75, align 1, !tbaa !6
  %76 = zext nneg i8 %61 to i16
  %77 = sub i16 %53, %76
  %78 = icmp eq i16 %77, 0
  br i1 %78, label %79, label %52, !llvm.loop !114

79:                                               ; preds = %52, %60, %13
  %80 = phi i16 [ %11, %13 ], [ %18, %60 ], [ %18, %52 ]
  %81 = add nsw i16 %80, %10
  %82 = icmp sgt i16 %3, %81
  br i1 %82, label %9, label %83, !llvm.loop !115

83:                                               ; preds = %79, %4
  ret void
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(argmem: read)
define internal fastcc { i16, i16 } @boid_acc(ptr noundef readonly captures(none) %0, i8 noundef zeroext range(i8 8, 33) %1, i8 noundef zeroext %2) unnamed_addr #6 {
  %4 = tail call fastcc { i16, i16 } @boid_separation(ptr noundef %0, i8 noundef zeroext %1, i8 noundef zeroext %2) #13
  %5 = extractvalue { i16, i16 } %4, 0
  %6 = extractvalue { i16, i16 } %4, 1
  %7 = tail call fastcc { i16, i16 } @boid_alignment(ptr noundef %0, i8 noundef zeroext %1, i8 noundef zeroext %2) #13
  %8 = extractvalue { i16, i16 } %7, 0
  %9 = extractvalue { i16, i16 } %7, 1
  %10 = tail call fastcc { i16, i16 } @boid_cohesion(ptr noundef %0, i8 noundef zeroext %1, i8 noundef zeroext %2) #13
  %11 = extractvalue { i16, i16 } %10, 0
  %12 = extractvalue { i16, i16 } %10, 1
  %13 = tail call fastcc { i16, i16 } @v2_add(i16 %5, i16 %6, i16 %8, i16 %9) #13
  %14 = extractvalue { i16, i16 } %13, 0
  %15 = extractvalue { i16, i16 } %13, 1
  %16 = tail call fastcc { i16, i16 } @v2_add(i16 %14, i16 %15, i16 %11, i16 %12) #13
  %17 = extractvalue { i16, i16 } %16, 0
  %18 = extractvalue { i16, i16 } %16, 1
  %19 = zext i8 %2 to i16
  %20 = getelementptr inbounds nuw [8 x i8], ptr %0, i16 %19
  %21 = load i16, ptr %20, align 1
  %22 = getelementptr inbounds nuw i8, ptr %20, i16 2
  %23 = load i16, ptr %22, align 1
  %24 = tail call fastcc { i16, i16 } @v2_sub(i16 2048, i16 1792, i16 %21, i16 %23) #13
  %25 = extractvalue { i16, i16 } %24, 0
  %26 = extractvalue { i16, i16 } %24, 1
  %27 = tail call fastcc { i16, i16 } @v2_scale(i16 %25, i16 %26, i16 noundef 256) #13
  %28 = extractvalue { i16, i16 } %27, 0
  %29 = extractvalue { i16, i16 } %27, 1
  %30 = tail call fastcc { i16, i16 } @v2_add(i16 %17, i16 %18, i16 %28, i16 %29) #13
  %31 = extractvalue { i16, i16 } %30, 0
  %32 = extractvalue { i16, i16 } %30, 1
  %33 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %31, i16 %32, i16 noundef 14) #13
  ret { i16, i16 } %33
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_clampbox(i16 %0, i16 %1, i16 noundef range(i16 14, 41) %2) unnamed_addr #7 {
  %4 = icmp sgt i16 %0, %2
  br i1 %4, label %9, label %5

5:                                                ; preds = %3
  %6 = sub nsw i16 0, %2
  %7 = icmp slt i16 %0, %6
  br i1 %7, label %8, label %9

8:                                                ; preds = %5
  br label %9

9:                                                ; preds = %3, %5, %8
  %10 = phi i16 [ %0, %5 ], [ %6, %8 ], [ %2, %3 ]
  %11 = icmp sgt i16 %1, %2
  br i1 %11, label %16, label %12

12:                                               ; preds = %9
  %13 = sub nsw i16 0, %2
  %14 = icmp slt i16 %1, %13
  br i1 %14, label %15, label %16

15:                                               ; preds = %12
  br label %16

16:                                               ; preds = %9, %12, %15
  %17 = phi i16 [ %1, %12 ], [ %13, %15 ], [ %2, %9 ]
  %18 = insertvalue { i16, i16 } poison, i16 %10, 0
  %19 = insertvalue { i16, i16 } %18, i16 %17, 1
  ret { i16, i16 } %19
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_add(i16 %0, i16 %1, i16 range(i16 -2048, 2048) %2, i16 range(i16 -2048, 2048) %3) unnamed_addr #7 {
  %5 = add i16 %2, %0
  %6 = add i16 %3, %1
  %7 = insertvalue { i16, i16 } poison, i16 %5, 0
  %8 = insertvalue { i16, i16 } %7, i16 %6, 1
  ret { i16, i16 } %8
}

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i16(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i16, i1 immarg) #8

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(argmem: read)
define internal fastcc { i16, i16 } @boid_separation(ptr noundef readonly captures(none) %0, i8 noundef zeroext range(i8 8, 33) %1, i8 noundef zeroext %2) unnamed_addr #6 {
  %4 = zext i8 %2 to i16
  %5 = getelementptr inbounds nuw [8 x i8], ptr %0, i16 %4
  %6 = load i16, ptr %5, align 1, !tbaa !2
  %7 = getelementptr inbounds nuw i8, ptr %5, i16 2
  %8 = load i16, ptr %7, align 1, !tbaa !2
  %9 = getelementptr i8, ptr %0, i16 2
  br label %12

10:                                               ; preds = %36
  %11 = tail call fastcc { i16, i16 } @v2_scale(i16 %38, i16 %37, i16 noundef 40) #13
  ret { i16, i16 } %11

12:                                               ; preds = %3, %36
  %13 = phi i8 [ 0, %3 ], [ %41, %36 ]
  %14 = phi i16 [ 0, %3 ], [ %38, %36 ]
  %15 = phi i16 [ 0, %3 ], [ %37, %36 ]
  %16 = phi i8 [ 0, %3 ], [ %39, %36 ]
  %17 = icmp eq i8 %16, %2
  br i1 %17, label %36, label %18

18:                                               ; preds = %12
  %19 = zext i8 %13 to i16
  %20 = getelementptr i8, ptr %0, i16 %19
  %21 = load i16, ptr %20, align 1
  %22 = getelementptr i8, ptr %9, i16 %19
  %23 = load i16, ptr %22, align 1
  %24 = tail call fastcc { i16, i16 } @v2_sub(i16 %6, i16 %8, i16 %21, i16 %23) #13
  %25 = extractvalue { i16, i16 } %24, 0
  %26 = extractvalue { i16, i16 } %24, 1
  %27 = sext i16 %25 to i32
  %28 = mul nsw i32 %27, %27
  %29 = sext i16 %26 to i32
  %30 = mul nsw i32 %29, %29
  %31 = add nuw nsw i32 %30, %28
  %32 = icmp samesign ult i32 %31, 65536
  br i1 %32, label %33, label %36

33:                                               ; preds = %18
  %34 = add i16 %25, %14
  %35 = add i16 %26, %15
  br label %36

36:                                               ; preds = %18, %33, %12
  %37 = phi i16 [ %15, %12 ], [ %35, %33 ], [ %15, %18 ]
  %38 = phi i16 [ %14, %12 ], [ %34, %33 ], [ %14, %18 ]
  %39 = add nuw nsw i8 %16, 1
  %40 = icmp eq i8 %39, %1
  %41 = add i8 %13, 8
  br i1 %40, label %10, label %12, !llvm.loop !116
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(argmem: read)
define internal fastcc { i16, i16 } @boid_alignment(ptr noundef readonly captures(none) %0, i8 noundef zeroext range(i8 8, 33) %1, i8 noundef zeroext %2) unnamed_addr #6 {
  %4 = zext i8 %2 to i16
  %5 = getelementptr inbounds nuw [8 x i8], ptr %0, i16 %4
  %6 = load i16, ptr %5, align 1, !tbaa !2
  %7 = getelementptr inbounds nuw i8, ptr %5, i16 2
  %8 = load i16, ptr %7, align 1, !tbaa !2
  %9 = getelementptr i8, ptr %0, i16 2
  %10 = getelementptr i8, ptr %0, i16 4
  %11 = getelementptr i8, ptr %0, i16 6
  br label %14

12:                                               ; preds = %46
  %13 = icmp eq i16 %47, 0
  br i1 %13, label %69, label %53

14:                                               ; preds = %3, %46
  %15 = phi i8 [ 0, %3 ], [ %52, %46 ]
  %16 = phi i32 [ 0, %3 ], [ %49, %46 ]
  %17 = phi i32 [ 0, %3 ], [ %48, %46 ]
  %18 = phi i16 [ 0, %3 ], [ %47, %46 ]
  %19 = phi i8 [ 0, %3 ], [ %50, %46 ]
  %20 = icmp eq i8 %19, %2
  br i1 %20, label %46, label %21

21:                                               ; preds = %14
  %22 = zext i8 %15 to i16
  %23 = getelementptr i8, ptr %0, i16 %22
  %24 = load i16, ptr %23, align 1
  %25 = getelementptr i8, ptr %9, i16 %22
  %26 = load i16, ptr %25, align 1
  %27 = tail call fastcc { i16, i16 } @v2_sub(i16 %24, i16 %26, i16 %6, i16 %8) #13
  %28 = extractvalue { i16, i16 } %27, 0
  %29 = extractvalue { i16, i16 } %27, 1
  %30 = sext i16 %28 to i32
  %31 = mul nsw i32 %30, %30
  %32 = sext i16 %29 to i32
  %33 = mul nsw i32 %32, %32
  %34 = add nuw nsw i32 %33, %31
  %35 = icmp samesign ult i32 %34, 589824
  br i1 %35, label %36, label %46

36:                                               ; preds = %21
  %37 = getelementptr i8, ptr %10, i16 %22
  %38 = load i16, ptr %37, align 1, !tbaa !46
  %39 = sext i16 %38 to i32
  %40 = add nsw i32 %16, %39
  %41 = getelementptr i8, ptr %11, i16 %22
  %42 = load i16, ptr %41, align 1, !tbaa !47
  %43 = sext i16 %42 to i32
  %44 = add nsw i32 %17, %43
  %45 = add nsw i16 %18, 1
  br label %46

46:                                               ; preds = %21, %36, %14
  %47 = phi i16 [ %18, %14 ], [ %45, %36 ], [ %18, %21 ]
  %48 = phi i32 [ %17, %14 ], [ %44, %36 ], [ %17, %21 ]
  %49 = phi i32 [ %16, %14 ], [ %40, %36 ], [ %16, %21 ]
  %50 = add nuw nsw i8 %19, 1
  %51 = icmp eq i8 %50, %1
  %52 = add i8 %15, 8
  br i1 %51, label %12, label %14, !llvm.loop !117

53:                                               ; preds = %12
  %54 = sext i16 %47 to i32
  %55 = sdiv i32 %49, %54
  %56 = trunc i32 %55 to i16
  %57 = sdiv i32 %48, %54
  %58 = trunc i32 %57 to i16
  %59 = getelementptr inbounds nuw i8, ptr %5, i16 4
  %60 = load i16, ptr %59, align 1
  %61 = getelementptr inbounds nuw i8, ptr %5, i16 6
  %62 = load i16, ptr %61, align 1
  %63 = tail call fastcc { i16, i16 } @v2_sub(i16 %56, i16 %58, i16 %60, i16 %62) #13
  %64 = extractvalue { i16, i16 } %63, 0
  %65 = extractvalue { i16, i16 } %63, 1
  %66 = tail call fastcc { i16, i16 } @v2_scale(i16 %64, i16 %65, i16 noundef 16) #13
  %67 = extractvalue { i16, i16 } %66, 0
  %68 = extractvalue { i16, i16 } %66, 1
  br label %69

69:                                               ; preds = %12, %53
  %70 = phi i16 [ %68, %53 ], [ 0, %12 ]
  %71 = phi i16 [ %67, %53 ], [ 0, %12 ]
  %72 = insertvalue { i16, i16 } poison, i16 %71, 0
  %73 = insertvalue { i16, i16 } %72, i16 %70, 1
  ret { i16, i16 } %73
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(argmem: read)
define internal fastcc { i16, i16 } @boid_cohesion(ptr noundef readonly captures(none) %0, i8 noundef zeroext range(i8 8, 33) %1, i8 noundef zeroext %2) unnamed_addr #6 {
  %4 = zext i8 %2 to i16
  %5 = getelementptr inbounds nuw [8 x i8], ptr %0, i16 %4
  %6 = load i16, ptr %5, align 1, !tbaa !2
  %7 = getelementptr inbounds nuw i8, ptr %5, i16 2
  %8 = load i16, ptr %7, align 1, !tbaa !2
  %9 = getelementptr i8, ptr %0, i16 2
  br label %12

10:                                               ; preds = %40
  %11 = icmp eq i16 %41, 0
  br i1 %11, label %59, label %47

12:                                               ; preds = %3, %40
  %13 = phi i8 [ 0, %3 ], [ %46, %40 ]
  %14 = phi i32 [ 0, %3 ], [ %43, %40 ]
  %15 = phi i32 [ 0, %3 ], [ %42, %40 ]
  %16 = phi i16 [ 0, %3 ], [ %41, %40 ]
  %17 = phi i8 [ 0, %3 ], [ %44, %40 ]
  %18 = icmp eq i8 %17, %2
  br i1 %18, label %40, label %19

19:                                               ; preds = %12
  %20 = zext i8 %13 to i16
  %21 = getelementptr i8, ptr %0, i16 %20
  %22 = load i16, ptr %21, align 1
  %23 = getelementptr i8, ptr %9, i16 %20
  %24 = load i16, ptr %23, align 1
  %25 = tail call fastcc { i16, i16 } @v2_sub(i16 %22, i16 %24, i16 %6, i16 %8) #13
  %26 = extractvalue { i16, i16 } %25, 0
  %27 = extractvalue { i16, i16 } %25, 1
  %28 = sext i16 %26 to i32
  %29 = mul nsw i32 %28, %28
  %30 = sext i16 %27 to i32
  %31 = mul nsw i32 %30, %30
  %32 = add nuw nsw i32 %31, %29
  %33 = icmp samesign ult i32 %32, 589824
  br i1 %33, label %34, label %40

34:                                               ; preds = %19
  %35 = sext i16 %22 to i32
  %36 = add nsw i32 %14, %35
  %37 = sext i16 %24 to i32
  %38 = add nsw i32 %15, %37
  %39 = add nsw i16 %16, 1
  br label %40

40:                                               ; preds = %19, %34, %12
  %41 = phi i16 [ %16, %12 ], [ %39, %34 ], [ %16, %19 ]
  %42 = phi i32 [ %15, %12 ], [ %38, %34 ], [ %15, %19 ]
  %43 = phi i32 [ %14, %12 ], [ %36, %34 ], [ %14, %19 ]
  %44 = add nuw nsw i8 %17, 1
  %45 = icmp eq i8 %44, %1
  %46 = add i8 %13, 8
  br i1 %45, label %10, label %12, !llvm.loop !118

47:                                               ; preds = %10
  %48 = sext i16 %41 to i32
  %49 = sdiv i32 %43, %48
  %50 = trunc i32 %49 to i16
  %51 = sdiv i32 %42, %48
  %52 = trunc i32 %51 to i16
  %53 = tail call fastcc { i16, i16 } @v2_sub(i16 %50, i16 %52, i16 %6, i16 %8) #13
  %54 = extractvalue { i16, i16 } %53, 0
  %55 = extractvalue { i16, i16 } %53, 1
  %56 = tail call fastcc { i16, i16 } @v2_scale(i16 %54, i16 %55, i16 noundef 40) #13
  %57 = extractvalue { i16, i16 } %56, 0
  %58 = extractvalue { i16, i16 } %56, 1
  br label %59

59:                                               ; preds = %10, %47
  %60 = phi i16 [ %58, %47 ], [ 0, %10 ]
  %61 = phi i16 [ %57, %47 ], [ 0, %10 ]
  %62 = insertvalue { i16, i16 } poison, i16 %61, 0
  %63 = insertvalue { i16, i16 } %62, i16 %60, 1
  ret { i16, i16 } %63
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_scale(i16 %0, i16 %1, i16 noundef range(i16 16, 257) %2) unnamed_addr #7 {
  %4 = sdiv i16 %0, %2
  %5 = sdiv i16 %1, %2
  %6 = insertvalue { i16, i16 } poison, i16 %4, 0
  %7 = insertvalue { i16, i16 } %6, i16 %5, 1
  ret { i16, i16 } %7
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_sub(i16 %0, i16 %1, i16 %2, i16 %3) unnamed_addr #7 {
  %5 = sub i16 %0, %2
  %6 = sub i16 %1, %3
  %7 = insertvalue { i16, i16 } poison, i16 %5, 0
  %8 = insertvalue { i16, i16 } %7, i16 %6, 1
  ret { i16, i16 } %8
}

; Function Attrs: nofree noinline norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal fastcc void @upq_flush() unnamed_addr #9 {
  %1 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 177), align 1, !tbaa !119
  %2 = zext i8 %1 to i16
  %3 = shl nuw nsw i16 %2, 4
  %4 = add nuw nsw i16 %3, 17152
  %5 = inttoptr i16 %4 to ptr
  %6 = shl nuw i16 1, %2
  %7 = trunc i16 %6 to i8
  %8 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
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
  %24 = load i8, ptr %23, align 1, !tbaa !33
  switch i8 %24, label %44 [
    i8 3, label %25
    i8 4, label %34
  ]

25:                                               ; preds = %17
  %26 = load i16, ptr %22, align 1, !tbaa !35
  %27 = inttoptr i16 %26 to ptr
  %28 = getelementptr inbounds nuw i8, ptr %22, i16 2
  %29 = load i16, ptr %28, align 1, !tbaa !39
  %30 = trunc i16 %29 to i8
  store volatile i8 %30, ptr %27, align 1, !tbaa !6
  %31 = load i16, ptr %28, align 1, !tbaa !39
  %32 = lshr i16 %31, 8
  %33 = trunc nuw i16 %32 to i8
  store volatile i8 %33, ptr %27, align 1, !tbaa !6
  br label %86

34:                                               ; preds = %17
  %35 = load i16, ptr %22, align 1, !tbaa !35
  %36 = inttoptr i16 %35 to ptr
  %37 = getelementptr inbounds nuw i8, ptr %22, i16 2
  %38 = load i16, ptr %37, align 1, !tbaa !39
  %39 = trunc i16 %38 to i8
  store volatile i8 %39, ptr %36, align 1, !tbaa !6
  %40 = load i16, ptr %37, align 1, !tbaa !39
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
  %48 = load i16, ptr %47, align 1, !tbaa !41
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
  %54 = load i8, ptr %53, align 1, !tbaa !36
  store volatile i8 %54, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  %55 = load i16, ptr %22, align 1, !tbaa !35
  store volatile i16 %55, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %65

56:                                               ; preds = %51
  %57 = load i16, ptr %22, align 1, !tbaa !35
  %58 = trunc i16 %57 to i8
  store volatile i8 %58, ptr inttoptr (i16 8481 to ptr), align 1, !tbaa !6
  br label %65

59:                                               ; preds = %51
  %60 = load i16, ptr %22, align 1, !tbaa !35
  %61 = trunc i16 %60 to i8
  store volatile i8 %61, ptr inttoptr (i16 8450 to ptr), align 2, !tbaa !6
  %62 = load i16, ptr %22, align 1, !tbaa !35
  %63 = lshr i16 %62, 8
  %64 = trunc nuw i16 %63 to i8
  store volatile i8 %64, ptr inttoptr (i16 8451 to ptr), align 1, !tbaa !6
  br label %65

65:                                               ; preds = %56, %59, %52
  %66 = getelementptr inbounds nuw i8, ptr %22, i16 8
  %67 = load i8, ptr %66, align 1, !tbaa !38
  store volatile i8 %67, ptr %5, align 16, !tbaa !6
  %68 = getelementptr inbounds nuw i8, ptr %22, i16 7
  %69 = load i8, ptr %68, align 1, !tbaa !37
  store volatile i8 %69, ptr %11, align 1, !tbaa !6
  %70 = getelementptr inbounds nuw i8, ptr %22, i16 2
  %71 = load i16, ptr %70, align 1, !tbaa !39
  %72 = trunc i16 %71 to i8
  store volatile i8 %72, ptr %12, align 2, !tbaa !6
  %73 = load i16, ptr %70, align 1, !tbaa !39
  %74 = lshr i16 %73, 8
  %75 = trunc nuw i16 %74 to i8
  store volatile i8 %75, ptr %13, align 1, !tbaa !6
  %76 = getelementptr inbounds nuw i8, ptr %22, i16 6
  %77 = load i8, ptr %76, align 1, !tbaa !40
  store volatile i8 %77, ptr %14, align 4, !tbaa !6
  %78 = getelementptr inbounds nuw i8, ptr %22, i16 4
  %79 = load i16, ptr %78, align 1, !tbaa !41
  %80 = trunc i16 %79 to i8
  store volatile i8 %80, ptr %15, align 1, !tbaa !6
  %81 = load i16, ptr %78, align 1, !tbaa !41
  %82 = lshr i16 %81, 8
  %83 = trunc nuw i16 %82 to i8
  store volatile i8 %83, ptr %16, align 2, !tbaa !6
  store volatile i8 %7, ptr inttoptr (i16 16907 to ptr), align 1, !tbaa !6
  %84 = load i16, ptr %78, align 1, !tbaa !41
  %85 = add i16 %84, %19
  br label %86

86:                                               ; preds = %65, %34, %25
  %87 = phi i16 [ %19, %25 ], [ %19, %34 ], [ %85, %65 ]
  %88 = add nuw i8 %20, 1
  %89 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
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
  tail call void @llvm.memcpy.p0.p0.i16(ptr noundef nonnull align 1 dereferenceable(11) %103, ptr noundef nonnull align 1 dereferenceable(11) %105, i16 11, i1 false), !tbaa.struct !120
  %106 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %107 = icmp ult i8 %104, %106
  br i1 %107, label %97, label %108, !llvm.loop !121

108:                                              ; preds = %97, %91, %0
  %109 = phi i8 [ 0, %91 ], [ 0, %0 ], [ %101, %97 ]
  store i8 %109, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  br label %110

110:                                              ; preds = %108, %95
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #10

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #11

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i16(ptr writeonly captures(none), i8, i16, i1 immarg) #11

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #1 = { nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #2 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { nofree norecurse nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #4 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #5 = { nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #6 = { nofree noinline norecurse nosync nounwind optsize memory(argmem: read) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #7 = { mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #8 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #9 = { nofree noinline norecurse nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #10 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #11 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #12 = { nounwind optsize }
attributes #13 = { optsize }
attributes #14 = { nounwind }

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
!16 = !{!"", !17, i64 0, !4, i64 3, !4, i64 515, !3, i64 547, !4, i64 549}
!17 = !{!"Drawable", !18, i64 0, !4, i64 2}
!18 = !{!"any pointer", !4, i64 0}
!19 = !{!16, !4, i64 2}
!20 = !{!16, !4, i64 549}
!21 = !{!16, !3, i64 547}
!22 = distinct !{!22, !8}
!23 = !{!10, !4, i64 192}
!24 = !{!10, !4, i64 193}
!25 = !{!13, !4, i64 8}
!26 = !{!27, !27, i64 0}
!27 = !{!"p1 _ZTS8Drawable", !18, i64 0}
!28 = !{!10, !4, i64 191}
!29 = !{!17, !4, i64 2}
!30 = distinct !{!30, !8}
!31 = distinct !{!31, !8}
!32 = !{!11, !4, i64 176}
!33 = !{!34, !4, i64 10}
!34 = !{!"", !3, i64 0, !3, i64 2, !3, i64 4, !4, i64 6, !4, i64 7, !4, i64 8, !4, i64 9, !4, i64 10}
!35 = !{!34, !3, i64 0}
!36 = !{!34, !4, i64 9}
!37 = !{!34, !4, i64 7}
!38 = !{!34, !4, i64 8}
!39 = !{!34, !3, i64 2}
!40 = !{!34, !4, i64 6}
!41 = !{!34, !3, i64 4}
!42 = distinct !{!42, !8}
!43 = !{!44, !3, i64 0}
!44 = !{!"", !12, i64 0, !12, i64 4}
!45 = !{!44, !3, i64 2}
!46 = !{!44, !3, i64 4}
!47 = !{!44, !3, i64 6}
!48 = distinct !{!48, !8}
!49 = !{!50, !18, i64 0}
!50 = !{!"", !17, i64 0, !51, i64 3, !51, i64 5, !51, i64 7, !51, i64 9, !4, i64 11, !4, i64 12, !3, i64 13, !3, i64 15, !3, i64 17, !3, i64 19, !3, i64 21, !3, i64 23, !4, i64 25, !3, i64 26, !4, i64 28, !4, i64 29, !4, i64 30, !4, i64 31, !4, i64 32, !4, i64 33, !3, i64 34, !3, i64 36, !52, i64 38, !52, i64 89}
!51 = !{!"p1 omnipotent char", !18, i64 0}
!52 = !{!"", !4, i64 0, !4, i64 50}
!53 = !{!50, !4, i64 2}
!54 = !{!50, !51, i64 3}
!55 = !{!50, !51, i64 5}
!56 = !{!50, !51, i64 7}
!57 = !{!50, !4, i64 11}
!58 = !{!50, !51, i64 9}
!59 = !{!50, !4, i64 12}
!60 = !{!50, !3, i64 13}
!61 = !{!50, !3, i64 15}
!62 = !{!50, !3, i64 17}
!63 = !{!50, !4, i64 28}
!64 = !{!50, !4, i64 29}
!65 = !{!50, !4, i64 31}
!66 = !{!50, !4, i64 32}
!67 = !{!50, !4, i64 30}
!68 = !{!50, !4, i64 25}
!69 = !{!50, !3, i64 34}
!70 = !{!50, !3, i64 36}
!71 = distinct !{null, null}
!72 = !{!50, !4, i64 33}
!73 = !{!17, !18, i64 0}
!74 = !{!75, !18, i64 2}
!75 = !{!"", !18, i64 0, !18, i64 2}
!76 = distinct !{null, null, null, null, null}
!77 = distinct !{!77, !8}
!78 = distinct !{!78, !8}
!79 = distinct !{!79, !8}
!80 = distinct !{null, null, null, null}
!81 = distinct !{!81, !8}
!82 = distinct !{!82, !8}
!83 = distinct !{!83, !8}
!84 = distinct !{!84, !8}
!85 = distinct !{!85, !8}
!86 = distinct !{null, null, null, null, null}
!87 = distinct !{!87, !8}
!88 = distinct !{!88, !8}
!89 = distinct !{null, null, null, null}
!90 = !{!50, !3, i64 19}
!91 = distinct !{null, null, null, null, null}
!92 = distinct !{null, null, null}
!93 = distinct !{!93, !8}
!94 = distinct !{!94, !8}
!95 = distinct !{!95, !8}
!96 = distinct !{!96, !8}
!97 = distinct !{!97, !8}
!98 = distinct !{!98, !8}
!99 = distinct !{!99, !8}
!100 = distinct !{!100, !8}
!101 = distinct !{!101, !8}
!102 = distinct !{!102, !8}
!103 = distinct !{!103, !8}
!104 = !{!50, !3, i64 21}
!105 = !{!50, !3, i64 23}
!106 = distinct !{!106, !8}
!107 = !{!50, !3, i64 26}
!108 = !{!52, !4, i64 50}
!109 = distinct !{!109, !8}
!110 = distinct !{!110, !8}
!111 = !{!112, !18, i64 0}
!112 = !{!"", !18, i64 0, !4, i64 2}
!113 = !{!112, !4, i64 2}
!114 = distinct !{!114, !8}
!115 = distinct !{!115, !8}
!116 = distinct !{!116, !8}
!117 = distinct !{!117, !8}
!118 = distinct !{!118, !8}
!119 = !{!11, !4, i64 177}
!120 = !{i64 0, i64 2, !2, i64 2, i64 2, !2, i64 4, i64 2, !2, i64 6, i64 1, !6, i64 7, i64 1, !6, i64 8, i64 1, !6, i64 9, i64 1, !6, i64 10, i64 1, !6}
!121 = distinct !{!121, !8}
