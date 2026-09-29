; ModuleID = 'docs/defects/evidence/2026-09-29-xy16-preserve-x-p-save/boids.xy16.ll'
source_filename = "/work/examples/snes/boids.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
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
  %11 = phi i16 [ 0, %9 ], [ %13, %10 ]
  %12 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 199), i16 %11
  store i8 0, ptr %12, align 1, !tbaa !6
  %scevgep57 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 200), i16 %11
  store i8 -32, ptr %scevgep57, align 1, !tbaa !6
  %scevgep56 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 201), i16 %11
  store i8 0, ptr %scevgep56, align 1, !tbaa !6
  %scevgep55 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 202), i16 %11
  store i8 0, ptr %scevgep55, align 1, !tbaa !6
  %13 = add nuw nsw i16 %11, 4
  %14 = icmp samesign ult i16 %11, 508
  br i1 %14, label %10, label %15, !llvm.loop !22

15:                                               ; preds = %10
  tail call void @llvm.memset.p0.i16(ptr noundef nonnull align 1 dereferenceable(32) getelementptr inbounds nuw (i8, ptr @main.a, i16 711), i8 0, i16 32, i1 false), !tbaa !6
  %16 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %17 = icmp eq i8 %16, 0
  br i1 %17, label %19, label %18

18:                                               ; preds = %15
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !24
  br label %19

19:                                               ; preds = %18, %15
  %20 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %21 = icmp ult i8 %20, 4
  br i1 %21, label %22, label %26

22:                                               ; preds = %19
  %23 = zext nneg i8 %20 to i16
  %24 = add nuw nsw i8 %20, 1
  store i8 %24, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %25 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %23
  store ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 196), ptr %25, align 1, !tbaa !26
  br label %26

26:                                               ; preds = %22, %19
  %27 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 745), align 1, !tbaa !20
  %28 = zext i8 %27 to i16
  %29 = shl nuw nsw i16 %28, 5
  %30 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 743), align 1, !tbaa !21
  %31 = lshr i16 %30, 13
  %32 = or disjoint i16 %29, %31
  %33 = trunc i16 %32 to i8
  store volatile i8 %33, ptr inttoptr (i16 8449 to ptr), align 1, !tbaa !6
  %34 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  %35 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 198), align 1, !tbaa !29
  %36 = or i8 %35, %34
  store i8 %36, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  store volatile i8 %36, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  br label %37

37:                                               ; preds = %40, %26
  %lsr.iv52 = phi ptr [ %scevgep53, %40 ], [ @BOID_PIX, %26 ]
  %38 = phi i8 [ %53, %40 ], [ 0, %26 ]
  %39 = phi i8 [ %52, %40 ], [ 0, %26 ]
  br label %55

40:                                               ; preds = %87
  %41 = zext i8 %70 to i16
  %42 = zext i8 %76 to i16
  %43 = shl nuw i16 %42, 8
  %44 = or disjoint i16 %43, %41
  %45 = zext nneg i8 %38 to i16
  %46 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1002), i16 %45
  store i16 %44, ptr %46, align 1, !tbaa !2
  %47 = zext i8 %82 to i16
  %48 = zext i8 %88 to i16
  %49 = shl nuw i16 %48, 8
  %50 = or disjoint i16 %49, %47
  %51 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1018), i16 %45
  store i16 %50, ptr %51, align 1, !tbaa !2
  %52 = add nuw nsw i8 %39, 1
  %53 = add nuw nsw i8 %38, 2
  %scevgep53 = getelementptr i8, ptr %lsr.iv52, i16 8
  %54 = icmp eq i8 %52, 8
  br i1 %54, label %91, label %37, !llvm.loop !30

55:                                               ; preds = %87, %37
  %56 = phi i8 [ 0, %37 ], [ %89, %87 ]
  %57 = phi i8 [ 0, %37 ], [ %88, %87 ]
  %58 = phi i8 [ 0, %37 ], [ %82, %87 ]
  %59 = phi i8 [ 0, %37 ], [ %76, %87 ]
  %60 = phi i8 [ 0, %37 ], [ %70, %87 ]
  %61 = zext nneg i8 %56 to i16
  %scevgep54 = getelementptr nuw i8, ptr %lsr.iv52, i16 %61
  %62 = load i8, ptr %scevgep54, align 1, !tbaa !6
  %63 = lshr exact i8 -128, %56
  %64 = zext i8 %62 to i16
  %65 = and i16 %64, 1
  %66 = icmp eq i16 %65, 0
  br i1 %66, label %69, label %67

67:                                               ; preds = %55
  %68 = or i8 %60, %63
  br label %69

69:                                               ; preds = %67, %55
  %70 = phi i8 [ %68, %67 ], [ %60, %55 ]
  %71 = and i16 %64, 2
  %72 = icmp eq i16 %71, 0
  br i1 %72, label %75, label %73

73:                                               ; preds = %69
  %74 = or i8 %59, %63
  br label %75

75:                                               ; preds = %73, %69
  %76 = phi i8 [ %74, %73 ], [ %59, %69 ]
  %77 = and i16 %64, 4
  %78 = icmp eq i16 %77, 0
  br i1 %78, label %81, label %79

79:                                               ; preds = %75
  %80 = or i8 %58, %63
  br label %81

81:                                               ; preds = %79, %75
  %82 = phi i8 [ %80, %79 ], [ %58, %75 ]
  %83 = and i16 %64, 8
  %84 = icmp eq i16 %83, 0
  br i1 %84, label %87, label %85

85:                                               ; preds = %81
  %86 = or i8 %63, %57
  br label %87

87:                                               ; preds = %85, %81
  %88 = phi i8 [ %86, %85 ], [ %57, %81 ]
  %89 = add nuw nsw i8 %56, 1
  %90 = icmp eq i8 %89, 8
  br i1 %90, label %40, label %55, !llvm.loop !31

91:                                               ; preds = %40
  %92 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %93 = icmp ugt i8 %92, 15
  br i1 %93, label %105, label %94

94:                                               ; preds = %91
  %95 = zext nneg i8 %92 to i16
  %96 = add nuw nsw i8 %92, 1
  store i8 %96, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %97 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %95
  %98 = getelementptr inbounds nuw i8, ptr %97, i16 10
  store i8 0, ptr %98, align 1, !tbaa !33
  store i16 16384, ptr %97, align 1, !tbaa !35
  %99 = getelementptr inbounds nuw i8, ptr %97, i16 9
  store i8 -128, ptr %99, align 1, !tbaa !36
  %100 = getelementptr inbounds nuw i8, ptr %97, i16 7
  store i8 24, ptr %100, align 1, !tbaa !37
  %101 = getelementptr inbounds nuw i8, ptr %97, i16 8
  store i8 1, ptr %101, align 1, !tbaa !38
  %102 = getelementptr inbounds nuw i8, ptr %97, i16 2
  store i16 ptrtoint (ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 1002) to i16), ptr %102, align 1, !tbaa !39
  %103 = getelementptr inbounds nuw i8, ptr %97, i16 6
  store i8 0, ptr %103, align 1, !tbaa !40
  %104 = getelementptr inbounds nuw i8, ptr %97, i16 4
  store i16 32, ptr %104, align 1, !tbaa !41
  br label %105

105:                                              ; preds = %94, %91
  %106 = phi i8 [ %92, %91 ], [ %96, %94 ]
  br label %107

107:                                              ; preds = %139, %105
  %lsr.iv38 = phi i16 [ %lsr.iv.next39, %139 ], [ 0, %105 ]
  %lsr.iv36 = phi i8 [ %lsr.iv.next37, %139 ], [ -128, %105 ]
  %108 = phi i8 [ %141, %139 ], [ 0, %105 ]
  %109 = phi i8 [ %140, %139 ], [ %106, %105 ]
  %scevgep50 = getelementptr nuw i8, ptr @main.a, i16 %lsr.iv38
  %scevgep51 = getelementptr nuw i8, ptr %scevgep50, i16 1034
  store i16 0, ptr %scevgep51, align 1, !tbaa !2
  %110 = zext nneg i8 %108 to i16
  %scevgep41 = getelementptr nuw i8, ptr @HUE5, i16 %110
  %111 = zext nneg i8 %108 to i16
  %scevgep44 = getelementptr nuw i8, ptr @HUE5, i16 %111
  %scevgep45 = getelementptr nuw i8, ptr %scevgep44, i16 2
  %112 = load i8, ptr %scevgep45, align 1, !tbaa !6
  %113 = and i8 %112, 31
  %114 = zext nneg i8 %113 to i16
  %115 = shl nuw nsw i16 %114, 10
  %116 = zext nneg i8 %108 to i16
  %scevgep42 = getelementptr nuw i8, ptr @HUE5, i16 %116
  %scevgep43 = getelementptr nuw i8, ptr %scevgep42, i16 1
  %117 = load i8, ptr %scevgep43, align 1, !tbaa !6
  %118 = and i8 %117, 31
  %119 = zext nneg i8 %118 to i16
  %120 = shl nuw nsw i16 %119, 5
  %121 = or disjoint i16 %120, %115
  %122 = load i8, ptr %scevgep41, align 1, !tbaa !6
  %123 = and i8 %122, 31
  %124 = zext nneg i8 %123 to i16
  %125 = or disjoint i16 %121, %124
  %scevgep48 = getelementptr nuw i8, ptr @main.a, i16 %lsr.iv38
  %scevgep49 = getelementptr nuw i8, ptr %scevgep48, i16 1036
  store i16 %125, ptr %scevgep49, align 1, !tbaa !2
  %scevgep46 = getelementptr nuw i8, ptr @main.a, i16 %lsr.iv38
  %scevgep47 = getelementptr nuw i8, ptr %scevgep46, i16 1038
  store i16 32767, ptr %scevgep47, align 1, !tbaa !2
  %126 = icmp ugt i8 %109, 15
  br i1 %126, label %139, label %127

127:                                              ; preds = %107
  %128 = zext nneg i8 %109 to i16
  %129 = add nuw nsw i8 %109, 1
  store i8 %129, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %130 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %128
  %131 = getelementptr inbounds nuw i8, ptr %130, i16 10
  store i8 1, ptr %131, align 1, !tbaa !33
  %tmp = zext i8 %lsr.iv36 to i16
  store i16 %tmp, ptr %130, align 1, !tbaa !35
  %132 = getelementptr inbounds nuw i8, ptr %130, i16 9
  store i8 0, ptr %132, align 1, !tbaa !36
  %133 = getelementptr inbounds nuw i8, ptr %130, i16 7
  store i8 34, ptr %133, align 1, !tbaa !37
  %134 = getelementptr inbounds nuw i8, ptr %130, i16 8
  store i8 0, ptr %134, align 1, !tbaa !38
  %135 = ptrtoint ptr %scevgep51 to i16
  %136 = getelementptr inbounds nuw i8, ptr %130, i16 2
  store i16 %135, ptr %136, align 1, !tbaa !39
  %137 = getelementptr inbounds nuw i8, ptr %130, i16 6
  store i8 0, ptr %137, align 1, !tbaa !40
  %138 = getelementptr inbounds nuw i8, ptr %130, i16 4
  store i16 6, ptr %138, align 1, !tbaa !41
  br label %139

139:                                              ; preds = %127, %107
  %140 = phi i8 [ %109, %107 ], [ %129, %127 ]
  %141 = add nuw nsw i8 %108, 3
  %lsr.iv.next37 = add nsw i8 %lsr.iv36, 16
  %lsr.iv.next39 = add nuw nsw i16 %lsr.iv38, 6
  %tmp40 = trunc i16 %lsr.iv.next39 to i8
  %142 = icmp eq i8 %tmp40, 48
  br i1 %142, label %.preheader15, label %107, !llvm.loop !42

.preheader15:                                     ; preds = %139
  br label %143

143:                                              ; preds = %.preheader15, %143
  %lsr.iv35 = phi i8 [ 32, %.preheader15 ], [ %lsr.iv.next, %143 ]
  %144 = phi i8 [ %182, %143 ], [ 0, %.preheader15 ]
  %145 = phi i16 [ %178, %143 ], [ 2829, %.preheader15 ]
  %146 = shl i16 %145, 7
  %147 = xor i16 %146, %145
  %148 = lshr i16 %147, 9
  %149 = xor i16 %148, %147
  %150 = shl i16 %149, 8
  %151 = xor i16 %150, %149
  %152 = and i16 %151, 1023
  %153 = add nuw nsw i16 %152, 1536
  %154 = zext i8 %144 to i16
  %scevgep34 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 746), i16 %154
  store i16 %153, ptr %scevgep34, align 1, !tbaa !43
  %155 = shl i16 %151, 7
  %156 = xor i16 %155, %151
  %157 = lshr i16 %156, 9
  %158 = xor i16 %157, %156
  %159 = shl i16 %158, 8
  %160 = xor i16 %159, %158
  %161 = and i16 %160, 1023
  %162 = add nuw nsw i16 %161, 1280
  %163 = zext i8 %144 to i16
  %scevgep33 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 748), i16 %163
  store i16 %162, ptr %scevgep33, align 1, !tbaa !45
  %164 = shl i16 %160, 7
  %165 = xor i16 %164, %160
  %166 = lshr i16 %165, 9
  %167 = xor i16 %166, %165
  %168 = shl i16 %167, 8
  %169 = xor i16 %168, %167
  %170 = and i16 %167, 63
  %171 = add nsw i16 %170, -32
  %172 = zext i8 %144 to i16
  %scevgep32 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 750), i16 %172
  store i16 %171, ptr %scevgep32, align 1, !tbaa !46
  %173 = shl i16 %169, 7
  %174 = xor i16 %173, %169
  %175 = lshr i16 %174, 9
  %176 = xor i16 %175, %174
  %177 = shl i16 %176, 8
  %178 = xor i16 %177, %176
  %179 = and i16 %176, 63
  %180 = add nsw i16 %179, -32
  %181 = zext i8 %144 to i16
  %scevgep31 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 752), i16 %181
  store i16 %180, ptr %scevgep31, align 1, !tbaa !47
  %182 = add i8 %144, 8
  %lsr.iv.next = add nsw i8 %lsr.iv35, -1
  %183 = icmp eq i8 %lsr.iv.next, 0
  br i1 %183, label %184, label %143, !llvm.loop !48

184:                                              ; preds = %143
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
  %185 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  %186 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %187 = icmp eq i8 %186, 0
  br i1 %187, label %189, label %188

188:                                              ; preds = %184
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 193), align 1, !tbaa !24
  br label %189

189:                                              ; preds = %188, %184
  %190 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %191 = icmp ult i8 %190, 4
  br i1 %191, label %192, label %196

192:                                              ; preds = %189
  %193 = zext nneg i8 %190 to i16
  %194 = add nuw nsw i8 %190, 1
  store i8 %194, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %195 = getelementptr inbounds nuw [2 x i8], ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 182), i16 %193
  store ptr @main.title, ptr %195, align 1, !tbaa !26
  br label %196

196:                                              ; preds = %192, %189
  tail call void @_title_reserve(ptr noundef nonnull @main.title, ptr nonnull poison) #11, !inline_history !71
  %197 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  %198 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !29
  %199 = or i8 %198, %197
  store volatile i8 %199, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store i8 %185, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 33), align 1, !tbaa !72
  store i8 2, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  store volatile i8 2, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store volatile i8 24, ptr inttoptr (i16 16908 to ptr), align 4, !tbaa !6
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  store i8 15, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  br label %200

200:                                              ; preds = %226, %196
  %201 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %202 = icmp eq i8 %201, 0
  br i1 %202, label %212, label %.preheader13

.preheader13:                                     ; preds = %200
  br label %203

203:                                              ; preds = %.preheader13, %203
  %lsr.iv29 = phi ptr [ getelementptr inbounds nuw (i8, ptr @main.a, i16 182), %.preheader13 ], [ %scevgep30, %203 ]
  %204 = phi i8 [ %209, %203 ], [ 0, %.preheader13 ]
  %205 = load ptr, ptr %lsr.iv29, align 1, !tbaa !26
  %206 = load ptr, ptr %205, align 1, !tbaa !73
  %207 = getelementptr inbounds nuw i8, ptr %206, i16 2
  %208 = load ptr, ptr %207, align 1, !tbaa !74
  tail call void %208(ptr noundef nonnull %205, ptr noundef nonnull @main.a) #11, !inline_history !76
  %209 = add nuw i8 %204, 1
  %210 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %scevgep30 = getelementptr nuw i8, ptr %lsr.iv29, i16 2
  %211 = icmp ult i8 %209, %210
  br i1 %211, label %203, label %.loopexit14, !llvm.loop !77

.loopexit14:                                      ; preds = %203
  br label %212

212:                                              ; preds = %.loopexit14, %200
  %213 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %214

214:                                              ; preds = %214, %212
  %215 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %216 = icmp sgt i8 %215, -1
  br i1 %216, label %214, label %217, !llvm.loop !78

217:                                              ; preds = %214
  tail call fastcc void @upq_flush() #12
  %218 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %219 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %220 = icmp ult i8 %218, %219
  br i1 %220, label %223, label %221

221:                                              ; preds = %217
  %222 = icmp ugt i8 %218, %219
  br i1 %222, label %223, label %226

223:                                              ; preds = %221, %217
  %224 = phi i8 [ 1, %217 ], [ -1, %221 ]
  %225 = add i8 %224, %218
  store i8 %225, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %226

226:                                              ; preds = %223, %221
  %227 = phi i8 [ %218, %221 ], [ %225, %223 ]
  %228 = and i8 %227, 15
  store volatile i8 %228, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %229 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %230 = icmp eq i8 %229, 15
  br i1 %230, label %231, label %200, !llvm.loop !79

231:                                              ; preds = %226
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 30), align 1, !tbaa !67
  %232 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !68
  %233 = icmp eq i8 %232, -1
  br i1 %233, label %269, label %.preheader11

.preheader11:                                     ; preds = %231
  br label %234

234:                                              ; preds = %.preheader11, %261
  %235 = phi i8 [ %264, %261 ], [ 0, %.preheader11 ]
  %236 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %237 = icmp eq i8 %236, 0
  br i1 %237, label %247, label %.preheader9

.preheader9:                                      ; preds = %234
  br label %238

238:                                              ; preds = %.preheader9, %238
  %lsr.iv27 = phi ptr [ getelementptr inbounds nuw (i8, ptr @main.a, i16 182), %.preheader9 ], [ %scevgep28, %238 ]
  %239 = phi i8 [ %244, %238 ], [ 0, %.preheader9 ]
  %240 = load ptr, ptr %lsr.iv27, align 1, !tbaa !26
  %241 = load ptr, ptr %240, align 1, !tbaa !73
  %242 = getelementptr inbounds nuw i8, ptr %241, i16 2
  %243 = load ptr, ptr %242, align 1, !tbaa !74
  tail call void %243(ptr noundef nonnull %240, ptr noundef nonnull @main.a) #11, !inline_history !80
  %244 = add nuw i8 %239, 1
  %245 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %scevgep28 = getelementptr nuw i8, ptr %lsr.iv27, i16 2
  %246 = icmp ult i8 %244, %245
  br i1 %246, label %238, label %.loopexit10, !llvm.loop !77

.loopexit10:                                      ; preds = %238
  br label %247

247:                                              ; preds = %.loopexit10, %234
  %248 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %249

249:                                              ; preds = %249, %247
  %250 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %251 = icmp sgt i8 %250, -1
  br i1 %251, label %249, label %252, !llvm.loop !78

252:                                              ; preds = %249
  tail call fastcc void @upq_flush() #12
  %253 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %254 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %255 = icmp ult i8 %253, %254
  br i1 %255, label %258, label %256

256:                                              ; preds = %252
  %257 = icmp ugt i8 %253, %254
  br i1 %257, label %258, label %261

258:                                              ; preds = %256, %252
  %259 = phi i8 [ 1, %252 ], [ -1, %256 ]
  %260 = add i8 %259, %253
  store i8 %260, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %261

261:                                              ; preds = %258, %256
  %262 = phi i8 [ %253, %256 ], [ %260, %258 ]
  %263 = and i8 %262, 15
  store volatile i8 %263, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %264 = add nuw i8 %235, 1
  %265 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 25), align 1, !tbaa !68
  %266 = icmp ne i8 %265, -1
  %267 = icmp ult i8 %235, -57
  %268 = select i1 %266, i1 %267, i1 false
  br i1 %268, label %234, label %.loopexit12, !llvm.loop !81

.loopexit12:                                      ; preds = %261
  br label %269

269:                                              ; preds = %.loopexit12, %231
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
  br label %270

270:                                              ; preds = %320, %269
  %271 = phi i8 [ 0, %269 ], [ %321, %320 ]
  br label %276

272:                                              ; preds = %320
  %273 = getelementptr inbounds nuw i8, ptr %1, i16 2
  %274 = getelementptr inbounds nuw i8, ptr %1, i16 4
  %275 = getelementptr inbounds nuw i8, ptr %1, i16 6
  br label %323

276:                                              ; preds = %315, %270
  %277 = phi i8 [ %318, %315 ], [ 0, %270 ]
  %278 = phi i8 [ %317, %315 ], [ 0, %270 ]
  %279 = tail call fastcc { i16, i16 } @boid_acc(ptr noundef nonnull @boids_gate_crc.gf, i8 noundef zeroext 8, i8 noundef zeroext %278) #12
  %280 = extractvalue { i16, i16 } %279, 0
  %281 = extractvalue { i16, i16 } %279, 1
  %282 = zext nneg i8 %277 to i16
  %scevgep26 = getelementptr nuw i8, ptr @boids_gate_crc.gf, i16 %282
  %283 = zext nneg i8 %277 to i16
  %scevgep25 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %283
  %284 = load i16, ptr %scevgep25, align 1
  %285 = zext nneg i8 %277 to i16
  %scevgep24 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %285
  %286 = load i16, ptr %scevgep24, align 1
  %287 = tail call fastcc { i16, i16 } @v2_add(i16 %284, i16 %286, i16 %280, i16 %281) #12
  %288 = extractvalue { i16, i16 } %287, 0
  %289 = extractvalue { i16, i16 } %287, 1
  %290 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %288, i16 %289, i16 noundef 40) #12
  %291 = extractvalue { i16, i16 } %290, 0
  %292 = extractvalue { i16, i16 } %290, 1
  store i16 %291, ptr %scevgep25, align 1, !tbaa !2
  store i16 %292, ptr %scevgep24, align 1, !tbaa !2
  %293 = load i16, ptr %scevgep26, align 1
  %294 = zext nneg i8 %277 to i16
  %scevgep23 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %294
  %295 = load i16, ptr %scevgep23, align 1
  %296 = tail call fastcc { i16, i16 } @v2_add(i16 %293, i16 %295, i16 %291, i16 %292) #12
  %297 = extractvalue { i16, i16 } %296, 0
  %298 = extractvalue { i16, i16 } %296, 1
  %299 = icmp slt i16 %297, 0
  br i1 %299, label %300, label %302

300:                                              ; preds = %276
  %301 = add nsw i16 %297, 4096
  br label %306

302:                                              ; preds = %276
  %303 = icmp samesign ult i16 %297, 4096
  br i1 %303, label %306, label %304

304:                                              ; preds = %302
  %305 = add nsw i16 %297, -4096
  br label %306

306:                                              ; preds = %304, %302, %300
  %307 = phi i16 [ %301, %300 ], [ %305, %304 ], [ %297, %302 ]
  %308 = icmp slt i16 %298, 0
  br i1 %308, label %309, label %311

309:                                              ; preds = %306
  %310 = add nsw i16 %298, 3584
  br label %315

311:                                              ; preds = %306
  %312 = icmp samesign ult i16 %298, 3584
  br i1 %312, label %315, label %313

313:                                              ; preds = %311
  %314 = add nsw i16 %298, -3584
  br label %315

315:                                              ; preds = %313, %311, %309
  %316 = phi i16 [ %310, %309 ], [ %314, %313 ], [ %298, %311 ]
  store i16 %307, ptr %scevgep26, align 1, !tbaa !2
  store i16 %316, ptr %scevgep23, align 1, !tbaa !2
  %317 = add nuw nsw i8 %278, 1
  %318 = add nuw nsw i8 %277, 8
  %319 = icmp eq i8 %318, 64
  br i1 %319, label %320, label %276, !llvm.loop !82

320:                                              ; preds = %315
  %321 = add nuw nsw i8 %271, 1
  %322 = icmp eq i8 %321, 12
  br i1 %322, label %272, label %270, !llvm.loop !83

323:                                              ; preds = %336, %272
  %324 = phi i8 [ 0, %272 ], [ %338, %336 ]
  %325 = phi i8 [ 0, %272 ], [ %337, %336 ]
  %326 = phi i16 [ 0, %272 ], [ %346, %336 ]
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #13
  %327 = zext nneg i8 %324 to i16
  %328 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %327
  %329 = load i16, ptr %328, align 1, !tbaa !43
  store i16 %329, ptr %1, align 1, !tbaa !2
  %330 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %327
  %331 = load i16, ptr %330, align 1, !tbaa !45
  store i16 %331, ptr %273, align 1, !tbaa !2
  %332 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %327
  %333 = load i16, ptr %332, align 1, !tbaa !46
  store i16 %333, ptr %274, align 1, !tbaa !2
  %334 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %327
  %335 = load i16, ptr %334, align 1, !tbaa !47
  store i16 %335, ptr %275, align 1, !tbaa !2
  br label %340

336:                                              ; preds = %340
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #13
  %337 = add nuw nsw i8 %325, 1
  %338 = add nuw nsw i8 %324, 8
  %339 = icmp eq i8 %337, 8
  br i1 %339, label %349, label %323, !llvm.loop !84

340:                                              ; preds = %340, %323
  %341 = phi i8 [ 0, %323 ], [ %347, %340 ]
  %342 = phi i16 [ %326, %323 ], [ %346, %340 ]
  %343 = tail call i16 @llvm.fshl.i16(i16 %342, i16 %342, i16 1)
  %344 = zext nneg i8 %341 to i16
  %scevgep22 = getelementptr nuw i8, ptr %1, i16 %344
  %345 = load i16, ptr %scevgep22, align 1, !tbaa !2
  %346 = xor i16 %345, %343
  %347 = add nuw nsw i8 %341, 2
  %348 = icmp eq i8 %347, 8
  br i1 %348, label %336, label %340, !llvm.loop !85

349:                                              ; preds = %336
  store volatile i16 %346, ptr @corpus_result, align 1, !tbaa !2
  br label %350

350:                                              ; preds = %378, %349
  %351 = phi i16 [ 110, %349 ], [ %352, %378 ]
  %352 = add nsw i16 %351, -1
  %353 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %354 = icmp eq i8 %353, 0
  br i1 %354, label %364, label %.preheader7

.preheader7:                                      ; preds = %350
  br label %355

355:                                              ; preds = %.preheader7, %355
  %lsr.iv20 = phi ptr [ getelementptr inbounds nuw (i8, ptr @main.a, i16 182), %.preheader7 ], [ %scevgep21, %355 ]
  %356 = phi i8 [ %361, %355 ], [ 0, %.preheader7 ]
  %357 = load ptr, ptr %lsr.iv20, align 1, !tbaa !26
  %358 = load ptr, ptr %357, align 1, !tbaa !73
  %359 = getelementptr inbounds nuw i8, ptr %358, i16 2
  %360 = load ptr, ptr %359, align 1, !tbaa !74
  tail call void %360(ptr noundef nonnull %357, ptr noundef nonnull @main.a) #11, !inline_history !86
  %361 = add nuw i8 %356, 1
  %362 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %scevgep21 = getelementptr nuw i8, ptr %lsr.iv20, i16 2
  %363 = icmp ult i8 %361, %362
  br i1 %363, label %355, label %.loopexit8, !llvm.loop !77

.loopexit8:                                       ; preds = %355
  br label %364

364:                                              ; preds = %.loopexit8, %350
  %365 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %366

366:                                              ; preds = %366, %364
  %367 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %368 = icmp sgt i8 %367, -1
  br i1 %368, label %366, label %369, !llvm.loop !78

369:                                              ; preds = %366
  tail call fastcc void @upq_flush() #12
  %370 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %371 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %372 = icmp ult i8 %370, %371
  br i1 %372, label %375, label %373

373:                                              ; preds = %369
  %374 = icmp ugt i8 %370, %371
  br i1 %374, label %375, label %378

375:                                              ; preds = %373, %369
  %376 = phi i8 [ 1, %369 ], [ -1, %373 ]
  %377 = add i8 %376, %370
  store i8 %377, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %378

378:                                              ; preds = %375, %373
  %379 = phi i8 [ %370, %373 ], [ %377, %375 ]
  %380 = and i8 %379, 15
  store volatile i8 %380, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %381 = icmp eq i16 %352, 0
  br i1 %381, label %382, label %350, !llvm.loop !87

382:                                              ; preds = %378
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !65
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 32), align 1, !tbaa !66
  br label %386

383:                                              ; preds = %413
  %384 = add nuw nsw i8 %387, 1
  %385 = icmp eq i8 %384, 90
  br i1 %385, label %418, label %386, !llvm.loop !88

386:                                              ; preds = %383, %382
  %387 = phi i8 [ 0, %382 ], [ %384, %383 ]
  %388 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %389 = icmp eq i8 %388, 0
  br i1 %389, label %399, label %.preheader5

.preheader5:                                      ; preds = %386
  br label %390

390:                                              ; preds = %.preheader5, %390
  %lsr.iv18 = phi ptr [ getelementptr inbounds nuw (i8, ptr @main.a, i16 182), %.preheader5 ], [ %scevgep19, %390 ]
  %391 = phi i8 [ %396, %390 ], [ 0, %.preheader5 ]
  %392 = load ptr, ptr %lsr.iv18, align 1, !tbaa !26
  %393 = load ptr, ptr %392, align 1, !tbaa !73
  %394 = getelementptr inbounds nuw i8, ptr %393, i16 2
  %395 = load ptr, ptr %394, align 1, !tbaa !74
  tail call void %395(ptr noundef nonnull %392, ptr noundef nonnull @main.a) #11, !inline_history !89
  %396 = add nuw i8 %391, 1
  %397 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %scevgep19 = getelementptr nuw i8, ptr %lsr.iv18, i16 2
  %398 = icmp ult i8 %396, %397
  br i1 %398, label %390, label %.loopexit6, !llvm.loop !77

.loopexit6:                                       ; preds = %390
  br label %399

399:                                              ; preds = %.loopexit6, %386
  %400 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %401

401:                                              ; preds = %401, %399
  %402 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %403 = icmp sgt i8 %402, -1
  br i1 %403, label %401, label %404, !llvm.loop !78

404:                                              ; preds = %401
  tail call fastcc void @upq_flush() #12
  %405 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %406 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %407 = icmp ult i8 %405, %406
  br i1 %407, label %410, label %408

408:                                              ; preds = %404
  %409 = icmp ugt i8 %405, %406
  br i1 %409, label %410, label %413

410:                                              ; preds = %408, %404
  %411 = phi i8 [ 1, %404 ], [ -1, %408 ]
  %412 = add i8 %411, %405
  store i8 %412, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %413

413:                                              ; preds = %410, %408
  %414 = phi i8 [ %405, %408 ], [ %412, %410 ]
  %415 = and i8 %414, 15
  store volatile i8 %415, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %416 = load i16, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 19), align 1, !tbaa !90
  %417 = icmp sgt i16 %416, 3583
  br i1 %417, label %418, label %383

418:                                              ; preds = %413, %383
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 31), align 1, !tbaa !65
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %419 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %420 = icmp eq i8 %419, 0
  br i1 %420, label %452, label %.preheader3

.preheader3:                                      ; preds = %418
  br label %421

421:                                              ; preds = %.preheader3, %447
  %422 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %423 = icmp eq i8 %422, 0
  br i1 %423, label %433, label %.preheader1

.preheader1:                                      ; preds = %421
  br label %424

424:                                              ; preds = %.preheader1, %424
  %lsr.iv16 = phi ptr [ getelementptr inbounds nuw (i8, ptr @main.a, i16 182), %.preheader1 ], [ %scevgep17, %424 ]
  %425 = phi i8 [ %430, %424 ], [ 0, %.preheader1 ]
  %426 = load ptr, ptr %lsr.iv16, align 1, !tbaa !26
  %427 = load ptr, ptr %426, align 1, !tbaa !73
  %428 = getelementptr inbounds nuw i8, ptr %427, i16 2
  %429 = load ptr, ptr %428, align 1, !tbaa !74
  tail call void %429(ptr noundef nonnull %426, ptr noundef nonnull @main.a) #11, !inline_history !91
  %430 = add nuw i8 %425, 1
  %431 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %scevgep17 = getelementptr nuw i8, ptr %lsr.iv16, i16 2
  %432 = icmp ult i8 %430, %431
  br i1 %432, label %424, label %.loopexit2, !llvm.loop !77

.loopexit2:                                       ; preds = %424
  br label %433

433:                                              ; preds = %.loopexit2, %421
  %434 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %435

435:                                              ; preds = %435, %433
  %436 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %437 = icmp sgt i8 %436, -1
  br i1 %437, label %435, label %438, !llvm.loop !78

438:                                              ; preds = %435
  tail call fastcc void @upq_flush() #12
  %439 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %440 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %441 = icmp ult i8 %439, %440
  br i1 %441, label %444, label %442

442:                                              ; preds = %438
  %443 = icmp ugt i8 %439, %440
  br i1 %443, label %444, label %447

444:                                              ; preds = %442, %438
  %445 = phi i8 [ 1, %438 ], [ -1, %442 ]
  %446 = add i8 %445, %439
  store i8 %446, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %447

447:                                              ; preds = %444, %442
  %448 = phi i8 [ %439, %442 ], [ %446, %444 ]
  %449 = and i8 %448, 15
  store volatile i8 %449, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  %450 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %451 = icmp eq i8 %450, 0
  br i1 %451, label %.loopexit4, label %421, !llvm.loop !79

.loopexit4:                                       ; preds = %447
  br label %452

452:                                              ; preds = %.loopexit4, %418
  %453 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 33), align 1, !tbaa !72
  %454 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  %455 = or i8 %454, %453
  %456 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 2), align 1, !tbaa !29
  %457 = xor i8 %456, -1
  %458 = and i8 %455, %457
  store i8 %458, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 191), align 1, !tbaa !28
  store volatile i8 %458, ptr inttoptr (i16 8492 to ptr), align 4, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 16908 to ptr), align 4, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8463 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8463 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store i8 0, ptr getelementptr inbounds nuw (i8, ptr @main.title, i16 29), align 1, !tbaa !64
  %459 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %460 = icmp ugt i8 %459, 15
  br i1 %460, label %472, label %461

461:                                              ; preds = %452
  %462 = zext nneg i8 %459 to i16
  %463 = add nuw nsw i8 %459, 1
  store i8 %463, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %464 = getelementptr inbounds nuw [11 x i8], ptr @main.a, i16 %462
  %465 = getelementptr inbounds nuw i8, ptr %464, i16 10
  store i8 1, ptr %465, align 1, !tbaa !33
  store i16 0, ptr %464, align 1, !tbaa !35
  %466 = getelementptr inbounds nuw i8, ptr %464, i16 9
  store i8 0, ptr %466, align 1, !tbaa !36
  %467 = getelementptr inbounds nuw i8, ptr %464, i16 7
  store i8 34, ptr %467, align 1, !tbaa !37
  %468 = getelementptr inbounds nuw i8, ptr %464, i16 8
  store i8 0, ptr %468, align 1, !tbaa !38
  %469 = getelementptr inbounds nuw i8, ptr %464, i16 2
  store i16 ptrtoint (ptr @title_end._title_bg_black to i16), ptr %469, align 1, !tbaa !39
  %470 = getelementptr inbounds nuw i8, ptr %464, i16 6
  store i8 0, ptr %470, align 1, !tbaa !40
  %471 = getelementptr inbounds nuw i8, ptr %464, i16 4
  store i16 2, ptr %471, align 1, !tbaa !41
  br label %472

472:                                              ; preds = %461, %452
  store i16 3855, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1
  br label %473

473:                                              ; preds = %499, %472
  tail call fastcc void @app_frame() #12
  %474 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %475 = icmp eq i8 %474, 0
  br i1 %475, label %485, label %.preheader

.preheader:                                       ; preds = %473
  br label %476

476:                                              ; preds = %.preheader, %476
  %lsr.iv = phi ptr [ getelementptr inbounds nuw (i8, ptr @main.a, i16 182), %.preheader ], [ %scevgep, %476 ]
  %477 = phi i8 [ %482, %476 ], [ 0, %.preheader ]
  %478 = load ptr, ptr %lsr.iv, align 1, !tbaa !26
  %479 = load ptr, ptr %478, align 1, !tbaa !73
  %480 = getelementptr inbounds nuw i8, ptr %479, i16 2
  %481 = load ptr, ptr %480, align 1, !tbaa !74
  tail call void %481(ptr noundef nonnull %478, ptr noundef nonnull @main.a) #11, !inline_history !92
  %482 = add nuw i8 %477, 1
  %483 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 190), align 1, !tbaa !25
  %scevgep = getelementptr nuw i8, ptr %lsr.iv, i16 2
  %484 = icmp ult i8 %482, %483
  br i1 %484, label %476, label %.loopexit, !llvm.loop !77

.loopexit:                                        ; preds = %476
  br label %485

485:                                              ; preds = %.loopexit, %473
  %486 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  br label %487

487:                                              ; preds = %487, %485
  %488 = load volatile i8, ptr inttoptr (i16 16912 to ptr), align 16, !tbaa !6
  %489 = icmp sgt i8 %488, -1
  br i1 %489, label %487, label %490, !llvm.loop !78

490:                                              ; preds = %487
  tail call fastcc void @upq_flush() #12
  %491 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  %492 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 195), align 1, !tbaa !14
  %493 = icmp ult i8 %491, %492
  br i1 %493, label %496, label %494

494:                                              ; preds = %490
  %495 = icmp ugt i8 %491, %492
  br i1 %495, label %496, label %499

496:                                              ; preds = %494, %490
  %497 = phi i8 [ 1, %490 ], [ -1, %494 ]
  %498 = add i8 %497, %491
  store i8 %498, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 194), align 1, !tbaa !9
  br label %499

499:                                              ; preds = %496, %494
  %500 = phi i8 [ %491, %494 ], [ %498, %496 ]
  %501 = and i8 %500, 15
  store volatile i8 %501, ptr inttoptr (i16 8448 to ptr), align 256, !tbaa !6
  store i8 1, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 192), align 1, !tbaa !23
  br label %473
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc void @app_frame() unnamed_addr #1 {
  br label %1

1:                                                ; preds = %40, %0
  %2 = phi i8 [ 0, %0 ], [ %43, %40 ]
  %3 = phi i8 [ 0, %0 ], [ %42, %40 ]
  %4 = tail call fastcc { i16, i16 } @boid_acc(ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @main.a, i16 746), i8 noundef zeroext 32, i8 noundef zeroext %3) #12
  %5 = extractvalue { i16, i16 } %4, 0
  %6 = extractvalue { i16, i16 } %4, 1
  %7 = zext i8 %2 to i16
  %scevgep22 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 746), i16 %7
  %8 = zext i8 %2 to i16
  %scevgep21 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 750), i16 %8
  %9 = load i16, ptr %scevgep21, align 1
  %10 = zext i8 %2 to i16
  %scevgep20 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 752), i16 %10
  %11 = load i16, ptr %scevgep20, align 1
  %12 = tail call fastcc { i16, i16 } @v2_add(i16 %9, i16 %11, i16 %5, i16 %6) #12
  %13 = extractvalue { i16, i16 } %12, 0
  %14 = extractvalue { i16, i16 } %12, 1
  %15 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %13, i16 %14, i16 noundef 40) #12
  %16 = extractvalue { i16, i16 } %15, 0
  %17 = extractvalue { i16, i16 } %15, 1
  store i16 %16, ptr %scevgep21, align 1, !tbaa !2
  store i16 %17, ptr %scevgep20, align 1, !tbaa !2
  %18 = load i16, ptr %scevgep22, align 1
  %19 = zext i8 %2 to i16
  %scevgep19 = getelementptr nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 748), i16 %19
  %20 = load i16, ptr %scevgep19, align 1
  %21 = tail call fastcc { i16, i16 } @v2_add(i16 %18, i16 %20, i16 %16, i16 %17) #12
  %22 = extractvalue { i16, i16 } %21, 0
  %23 = extractvalue { i16, i16 } %21, 1
  %24 = icmp slt i16 %22, 0
  br i1 %24, label %25, label %27

25:                                               ; preds = %1
  %26 = add nsw i16 %22, 4096
  br label %31

27:                                               ; preds = %1
  %28 = icmp samesign ult i16 %22, 4096
  br i1 %28, label %31, label %29

29:                                               ; preds = %27
  %30 = add nsw i16 %22, -4096
  br label %31

31:                                               ; preds = %29, %27, %25
  %32 = phi i16 [ %26, %25 ], [ %30, %29 ], [ %22, %27 ]
  %33 = icmp slt i16 %23, 0
  br i1 %33, label %34, label %36

34:                                               ; preds = %31
  %35 = add nsw i16 %23, 3584
  br label %40

36:                                               ; preds = %31
  %37 = icmp samesign ult i16 %23, 3584
  br i1 %37, label %40, label %38

38:                                               ; preds = %36
  %39 = add nsw i16 %23, -3584
  br label %40

40:                                               ; preds = %38, %36, %34
  %41 = phi i16 [ %35, %34 ], [ %39, %38 ], [ %23, %36 ]
  store i16 %32, ptr %scevgep22, align 1, !tbaa !2
  store i16 %41, ptr %scevgep19, align 1, !tbaa !2
  %42 = add nuw nsw i8 %3, 1
  %43 = add i8 %2, 8
  %44 = icmp eq i8 %42, 32
  br i1 %44, label %.preheader, label %1, !llvm.loop !82

.preheader:                                       ; preds = %40
  br label %46

45:                                               ; preds = %99
  ret void

46:                                               ; preds = %.preheader, %99
  %lsr.iv16 = phi i16 [ 746, %.preheader ], [ %lsr.iv.next17, %99 ]
  %lsr.iv13 = phi i16 [ 748, %.preheader ], [ %lsr.iv.next14, %99 ]
  %lsr.iv10 = phi i16 [ 750, %.preheader ], [ %lsr.iv.next11, %99 ]
  %lsr.iv7 = phi i16 [ 752, %.preheader ], [ %lsr.iv.next8, %99 ]
  %lsr.iv1 = phi i16 [ 199, %.preheader ], [ %lsr.iv.next2, %99 ]
  %lsr.iv = phi i8 [ 0, %.preheader ], [ %lsr.iv.next, %99 ]
  %47 = phi i8 [ %101, %99 ], [ 0, %.preheader ]
  %scevgep18 = getelementptr i8, ptr @main.a, i16 %lsr.iv16
  %48 = load i16, ptr %scevgep18, align 1, !tbaa !43
  %49 = lshr i16 %48, 4
  %scevgep15 = getelementptr i8, ptr @main.a, i16 %lsr.iv13
  %50 = load i16, ptr %scevgep15, align 1, !tbaa !45
  %51 = lshr i16 %50, 4
  %52 = trunc i16 %51 to i8
  %scevgep12 = getelementptr i8, ptr @main.a, i16 %lsr.iv10
  %53 = load i16, ptr %scevgep12, align 1
  %scevgep9 = getelementptr i8, ptr @main.a, i16 %lsr.iv7
  %54 = load i16, ptr %scevgep9, align 1
  %55 = icmp slt i16 %53, 0
  br i1 %55, label %56, label %58

56:                                               ; preds = %46
  %57 = sub nsw i16 0, %53
  br label %58

58:                                               ; preds = %56, %46
  %59 = phi i16 [ %57, %56 ], [ %53, %46 ]
  %60 = icmp slt i16 %54, 0
  br i1 %60, label %61, label %63

61:                                               ; preds = %58
  %62 = sub nsw i16 0, %54
  br label %63

63:                                               ; preds = %61, %58
  %64 = phi i16 [ %62, %61 ], [ %54, %58 ]
  %65 = icmp sgt i16 %53, -1
  %66 = icmp sgt i16 %54, -1
  br i1 %65, label %67, label %71

67:                                               ; preds = %63
  br i1 %66, label %68, label %78

68:                                               ; preds = %67
  %69 = icmp samesign ult i16 %59, %64
  %70 = zext i1 %69 to i8
  br label %81

71:                                               ; preds = %63
  br i1 %66, label %72, label %75

72:                                               ; preds = %71
  %73 = icmp samesign ult i16 %64, %59
  %74 = select i1 %73, i8 3, i8 2
  br label %81

75:                                               ; preds = %71
  %76 = icmp samesign ult i16 %59, %64
  %77 = select i1 %76, i8 5, i8 4
  br label %81

78:                                               ; preds = %67
  %79 = icmp samesign ult i16 %64, %59
  %80 = select i1 %79, i8 7, i8 6
  br label %81

81:                                               ; preds = %78, %75, %72, %68
  %82 = phi i8 [ %70, %68 ], [ %74, %72 ], [ %77, %75 ], [ %80, %78 ]
  %83 = shl nuw nsw i8 %82, 1
  %84 = or disjoint i8 %83, 32
  %85 = trunc i16 %49 to i8
  %scevgep = getelementptr i8, ptr @main.a, i16 %lsr.iv1
  store i8 %85, ptr %scevgep, align 1, !tbaa !6
  %scevgep6 = getelementptr nuw i8, ptr %scevgep, i16 1
  store i8 %52, ptr %scevgep6, align 1, !tbaa !6
  %scevgep5 = getelementptr nuw i8, ptr %scevgep, i16 2
  store i8 0, ptr %scevgep5, align 1, !tbaa !6
  %scevgep3 = getelementptr i8, ptr @main.a, i16 %lsr.iv1
  %scevgep4 = getelementptr nuw i8, ptr %scevgep3, i16 3
  store i8 %84, ptr %scevgep4, align 1, !tbaa !6
  %86 = and i8 %lsr.iv, 6
  %87 = lshr i8 %47, 2
  %88 = zext nneg i8 %87 to i16
  %89 = getelementptr inbounds nuw i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 711), i16 %88
  %90 = load i8, ptr %89, align 1, !tbaa !6
  %91 = shl nuw i8 3, %86
  %92 = xor i8 %91, -1
  %93 = and i8 %90, %92
  %94 = and i16 %48, 4096
  %95 = icmp eq i16 %94, 0
  br i1 %95, label %99, label %96

96:                                               ; preds = %81
  %97 = shl nuw nsw i8 1, %86
  %98 = or i8 %93, %97
  br label %99

99:                                               ; preds = %96, %81
  %100 = phi i8 [ %98, %96 ], [ %93, %81 ]
  store i8 %100, ptr %89, align 1, !tbaa !6
  %101 = add nuw nsw i8 %47, 1
  %lsr.iv.next = add nuw nsw i8 %lsr.iv, 2
  %lsr.iv.next2 = add nuw nsw i16 %lsr.iv1, 4
  %lsr.iv.next8 = add nuw nsw i16 %lsr.iv7, 8
  %lsr.iv.next11 = add nuw nsw i16 %lsr.iv10, 8
  %lsr.iv.next14 = add nuw nsw i16 %lsr.iv13, 8
  %lsr.iv.next17 = add nuw nsw i16 %lsr.iv16, 8
  %102 = icmp eq i8 %101, 32
  br i1 %102, label %45, label %46, !llvm.loop !93
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
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

19:                                               ; preds = %6, %2
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

3:                                                ; preds = %13, %2
  %4 = phi ptr [ @FONT8, %2 ], [ %15, %13 ]
  %5 = phi i16 [ 0, %2 ], [ %14, %13 ]
  br label %7

6:                                                ; preds = %13
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 5120, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %19

7:                                                ; preds = %7, %3
  %8 = phi i8 [ 0, %3 ], [ %11, %7 ]
  %9 = zext nneg i8 %8 to i16
  %scevgep11 = getelementptr nuw i8, ptr %4, i16 %9
  %10 = load i16, ptr %scevgep11, align 1, !tbaa !2
  store volatile i16 %10, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %11 = add nuw nsw i8 %8, 2
  %12 = icmp eq i8 %11, 16
  br i1 %12, label %.preheader2, label %7, !llvm.loop !94

.preheader2:                                      ; preds = %7
  br label %17

13:                                               ; preds = %17
  %14 = add nuw nsw i16 %5, 1
  %15 = getelementptr i8, ptr %4, i16 16
  %16 = icmp eq i16 %14, 64
  br i1 %16, label %6, label %3, !llvm.loop !95

17:                                               ; preds = %.preheader2, %17
  %lsr.iv12 = phi i8 [ 8, %.preheader2 ], [ %lsr.iv.next13, %17 ]
  store volatile i16 0, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %lsr.iv.next13 = add nsw i8 %lsr.iv12, -1
  %18 = icmp eq i8 %lsr.iv.next13, 0
  br i1 %18, label %13, label %17, !llvm.loop !96

19:                                               ; preds = %25, %6
  %20 = phi ptr [ @FONT16, %6 ], [ %27, %25 ]
  %21 = phi i16 [ 0, %6 ], [ %26, %25 ]
  br label %23

22:                                               ; preds = %25
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 20480, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %49

23:                                               ; preds = %35, %19
  %lsr.iv6 = phi ptr [ %scevgep7, %35 ], [ %20, %19 ]
  %24 = phi i8 [ 0, %19 ], [ %36, %35 ]
  br label %29

25:                                               ; preds = %35
  %26 = add nuw nsw i16 %21, 1
  %27 = getelementptr i8, ptr %20, i16 64
  %28 = icmp eq i16 %26, 64
  br i1 %28, label %22, label %19, !llvm.loop !97

29:                                               ; preds = %29, %23
  %30 = phi i8 [ 0, %23 ], [ %33, %29 ]
  %31 = zext nneg i8 %30 to i16
  %scevgep8 = getelementptr nuw i8, ptr %lsr.iv6, i16 %31
  %32 = load i16, ptr %scevgep8, align 1, !tbaa !2
  store volatile i16 %32, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %33 = add nuw nsw i8 %30, 2
  %34 = icmp eq i8 %33, 16
  br i1 %34, label %.preheader, label %29, !llvm.loop !98

.preheader:                                       ; preds = %29
  br label %38

35:                                               ; preds = %38
  %36 = add nuw nsw i8 %24, 1
  %scevgep7 = getelementptr i8, ptr %lsr.iv6, i16 16
  %37 = icmp eq i8 %36, 4
  br i1 %37, label %25, label %23, !llvm.loop !99

38:                                               ; preds = %.preheader, %38
  %lsr.iv9 = phi i8 [ 8, %.preheader ], [ %lsr.iv.next10, %38 ]
  store volatile i16 0, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %lsr.iv.next10 = add nsw i8 %lsr.iv9, -1
  %39 = icmp eq i8 %lsr.iv.next10, 0
  br i1 %39, label %35, label %38, !llvm.loop !100

40:                                               ; preds = %49
  %41 = getelementptr inbounds nuw i8, ptr %0, i16 3
  %42 = load ptr, ptr %41, align 1, !tbaa !54
  %43 = icmp eq ptr %42, null
  br i1 %43, label %59, label %44

44:                                               ; preds = %40
  %45 = load i8, ptr %42, align 1, !tbaa !6
  %46 = icmp eq i8 %45, 0
  br i1 %46, label %59, label %47

47:                                               ; preds = %44
  %48 = getelementptr i8, ptr %42, i16 1
  br label %51

49:                                               ; preds = %49, %22
  %lsr.iv = phi i16 [ %lsr.iv.next, %49 ], [ 1024, %22 ]
  store volatile i16 7168, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %lsr.iv.next = add nsw i16 %lsr.iv, -1
  %50 = icmp eq i16 %lsr.iv.next, 0
  br i1 %50, label %40, label %49, !llvm.loop !101

51:                                               ; preds = %51, %47
  %52 = phi i8 [ %53, %51 ], [ 0, %47 ]
  %53 = add nuw nsw i8 %52, 1
  %54 = zext nneg i8 %52 to i16
  %scevgep4 = getelementptr i8, ptr %48, i16 %54
  %55 = load i8, ptr %scevgep4, align 1, !tbaa !6
  %56 = icmp ne i8 %55, 0
  %57 = icmp samesign ult i8 %52, 31
  %58 = select i1 %56, i1 %57, i1 false
  br i1 %58, label %51, label %.loopexit1, !llvm.loop !102

.loopexit1:                                       ; preds = %51
  %.lcssa5 = phi i8 [ %53, %51 ]
  br label %59

59:                                               ; preds = %.loopexit1, %44, %40
  %60 = phi i8 [ 0, %40 ], [ 0, %44 ], [ %.lcssa5, %.loopexit1 ]
  %61 = zext i8 %60 to i16
  %62 = sub i16 32, %61
  %63 = lshr i16 %62, 1
  %64 = getelementptr inbounds nuw i8, ptr %0, i16 13
  %65 = load i16, ptr %64, align 1, !tbaa !60
  %66 = shl i16 %65, 2
  %67 = and i16 %66, -32
  %68 = add i16 %67, 20480
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 %68, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  %69 = trunc nuw nsw i16 %63 to i8
  %70 = add nuw nsw i8 %60, %69
  %71 = sub i16 0, %63
  %72 = getelementptr i8, ptr %42, i16 %71
  br label %85

73:                                               ; preds = %107
  %74 = getelementptr inbounds nuw i8, ptr %0, i16 7
  %75 = load ptr, ptr %74, align 1, !tbaa !56
  %76 = getelementptr inbounds nuw i8, ptr %0, i16 11
  %77 = load i8, ptr %76, align 1, !tbaa !57
  %78 = getelementptr inbounds nuw i8, ptr %0, i16 15
  %79 = load i16, ptr %78, align 1, !tbaa !61
  %80 = lshr i16 %79, 3
  %81 = trunc i16 %80 to i8
  tail call fastcc void @_title_write16(ptr noundef %75, i8 noundef zeroext %77, i8 noundef zeroext %81) #12
  %82 = getelementptr inbounds nuw i8, ptr %0, i16 9
  %83 = load ptr, ptr %82, align 1, !tbaa !58
  %84 = icmp eq ptr %83, null
  br i1 %84, label %118, label %111

85:                                               ; preds = %107, %59
  %86 = phi i8 [ 0, %59 ], [ %109, %107 ]
  br i1 %43, label %107, label %87

87:                                               ; preds = %85
  %tmp = zext i8 %86 to i16
  %88 = icmp samesign ugt i16 %63, %tmp
  br i1 %88, label %107, label %89

89:                                               ; preds = %87
  %90 = icmp ult i8 %86, %70
  br i1 %90, label %91, label %107

91:                                               ; preds = %89
  %92 = zext nneg i8 %86 to i16
  %scevgep3 = getelementptr i8, ptr %72, i16 %92
  %93 = load i8, ptr %scevgep3, align 1, !tbaa !6
  %94 = icmp ugt i8 %93, 96
  br i1 %94, label %95, label %99

95:                                               ; preds = %91
  %96 = icmp ult i8 %93, 123
  br i1 %96, label %97, label %107

97:                                               ; preds = %95
  %98 = add nsw i8 %93, -32
  br label %103

99:                                               ; preds = %91
  %100 = icmp samesign ugt i8 %93, 31
  br i1 %100, label %101, label %107

101:                                              ; preds = %99
  %102 = icmp eq i8 %93, 96
  br i1 %102, label %107, label %103

103:                                              ; preds = %101, %97
  %104 = phi i8 [ %98, %97 ], [ %93, %101 ]
  %105 = zext nneg i8 %104 to i16
  %106 = add nuw nsw i16 %105, 7136
  br label %107

107:                                              ; preds = %103, %101, %99, %95, %89, %87, %85
  %108 = phi i16 [ 7168, %85 ], [ 7168, %89 ], [ 7168, %87 ], [ %106, %103 ], [ 7168, %101 ], [ 7168, %99 ], [ 7168, %95 ]
  store volatile i16 %108, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %109 = add nuw nsw i8 %86, 1
  %110 = icmp eq i8 %109, 32
  br i1 %110, label %73, label %85, !llvm.loop !103

111:                                              ; preds = %73
  %112 = getelementptr inbounds nuw i8, ptr %0, i16 12
  %113 = load i8, ptr %112, align 1, !tbaa !59
  %114 = load i16, ptr %78, align 1, !tbaa !61
  %115 = lshr i16 %114, 3
  %116 = trunc i16 %115 to i8
  %117 = add i8 %116, 2
  tail call fastcc void @_title_write16(ptr noundef nonnull %83, i8 noundef zeroext %113, i8 noundef zeroext %117) #12
  br label %118

118:                                              ; preds = %111, %73
  %119 = getelementptr inbounds nuw i8, ptr %0, i16 19
  store i16 -128, ptr %119, align 1, !tbaa !90
  %120 = getelementptr inbounds nuw i8, ptr %0, i16 21
  store i16 3584, ptr %120, align 1, !tbaa !104
  %121 = getelementptr inbounds nuw i8, ptr %0, i16 23
  store i16 0, ptr %121, align 1, !tbaa !105
  %122 = load ptr, ptr %41, align 1, !tbaa !54
  %123 = icmp eq ptr %122, null
  br i1 %123, label %145, label %124

124:                                              ; preds = %118
  %125 = load i8, ptr %122, align 1, !tbaa !6
  %126 = icmp eq i8 %125, 0
  br i1 %126, label %129, label %127

127:                                              ; preds = %124
  %128 = getelementptr i8, ptr %122, i16 1
  br label %137

.loopexit:                                        ; preds = %137
  %.lcssa = phi i8 [ %139, %137 ]
  br label %129

129:                                              ; preds = %.loopexit, %124
  %130 = phi i8 [ 0, %124 ], [ %.lcssa, %.loopexit ]
  %131 = zext nneg i8 %130 to i16
  %132 = shl nuw nsw i16 %131, 2
  %133 = sub nuw nsw i16 128, %132
  %134 = and i16 %133, 248
  %135 = add nsw i16 %132, -128
  %136 = add nsw i16 %135, %134
  br label %145

137:                                              ; preds = %137, %127
  %138 = phi i8 [ %139, %137 ], [ 0, %127 ]
  %139 = add nuw nsw i8 %138, 1
  %140 = zext nneg i8 %138 to i16
  %scevgep = getelementptr i8, ptr %128, i16 %140
  %141 = load i8, ptr %scevgep, align 1, !tbaa !6
  %142 = icmp ne i8 %141, 0
  %143 = icmp samesign ult i8 %138, 31
  %144 = select i1 %142, i1 %143, i1 false
  br i1 %144, label %137, label %.loopexit, !llvm.loop !106

145:                                              ; preds = %129, %118
  %146 = phi i16 [ %136, %129 ], [ 0, %118 ]
  %147 = getelementptr inbounds nuw i8, ptr %0, i16 26
  store i16 %146, ptr %147, align 1, !tbaa !107
  store volatile i8 -112, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 8464 to ptr), align 16, !tbaa !6
  %148 = getelementptr inbounds nuw i8, ptr %0, i16 38
  %149 = getelementptr inbounds nuw i8, ptr %0, i16 89
  tail call fastcc void @_title_build(ptr noundef nonnull %0, i16 noundef -8, i16 noundef 224, ptr noundef nonnull %148, ptr noundef nonnull %149) #12
  %150 = getelementptr inbounds nuw i8, ptr %0, i16 88
  store i8 0, ptr %150, align 1, !tbaa !108
  store volatile i8 2, ptr inttoptr (i16 17200 to ptr), align 16, !tbaa !6
  store volatile i8 16, ptr inttoptr (i16 17201 to ptr), align 1, !tbaa !6
  %151 = ptrtoint ptr %148 to i16
  %152 = trunc i16 %151 to i8
  store volatile i8 %152, ptr inttoptr (i16 17202 to ptr), align 2, !tbaa !6
  %153 = lshr i16 %151, 8
  %154 = trunc nuw i16 %153 to i8
  store volatile i8 %154, ptr inttoptr (i16 17203 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 17204 to ptr), align 4, !tbaa !6
  %155 = getelementptr inbounds nuw i8, ptr %0, i16 139
  store i8 0, ptr %155, align 1, !tbaa !108
  store volatile i8 2, ptr inttoptr (i16 17216 to ptr), align 64, !tbaa !6
  store volatile i8 15, ptr inttoptr (i16 17217 to ptr), align 1, !tbaa !6
  %156 = ptrtoint ptr %149 to i16
  %157 = trunc i16 %156 to i8
  store volatile i8 %157, ptr inttoptr (i16 17218 to ptr), align 2, !tbaa !6
  %158 = lshr i16 %156, 8
  %159 = trunc nuw i16 %158 to i8
  store volatile i8 %159, ptr inttoptr (i16 17219 to ptr), align 1, !tbaa !6
  store volatile i8 0, ptr inttoptr (i16 17220 to ptr), align 4, !tbaa !6
  %160 = getelementptr inbounds nuw i8, ptr %0, i16 2
  store i8 2, ptr %160, align 1, !tbaa !53
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

16:                                               ; preds = %14, %10
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

64:                                               ; preds = %63, %60, %43, %16
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
  tail call fastcc void @_title_build(ptr noundef nonnull %0, i16 noundef %67, i16 noundef %68, ptr noundef nonnull %74, ptr noundef nonnull %80) #12
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

109:                                              ; preds = %97, %84, %64
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

122:                                              ; preds = %120, %117
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

133:                                              ; preds = %131, %122
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

142:                                              ; preds = %140, %133
  %143 = phi i8 [ %141, %140 ], [ %138, %133 ]
  %144 = lshr i8 %143, 2
  %145 = zext nneg i8 %144 to i16
  %146 = shl nuw nsw i16 %145, 5
  %147 = add nuw nsw i16 %146, %137
  br i1 %119, label %150, label %148

148:                                              ; preds = %142
  %149 = xor i8 %118, -1
  br label %150

150:                                              ; preds = %148, %142
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

188:                                              ; preds = %175, %161, %157, %2
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define internal fastcc void @_title_write16(ptr noundef readonly captures(address_is_null) %0, i8 noundef zeroext %1, i8 noundef zeroext %2) unnamed_addr #3 {
  %4 = zext i8 %1 to i16
  %5 = shl nuw nsw i16 %4, 1
  %6 = and i16 %5, 254
  %7 = sub i16 32, %6
  %8 = lshr i16 %7, 1
  %9 = zext i8 %2 to i16
  %10 = icmp eq ptr %0, null
  %11 = and i16 %8, 255
  %12 = add nuw i16 %8, %5
  %13 = and i16 %12, 255
  %14 = sub i16 0, %11
  br label %16

15:                                               ; preds = %24
  ret void

16:                                               ; preds = %24, %3
  %17 = phi i1 [ true, %3 ], [ false, %24 ]
  %18 = phi i8 [ 0, %3 ], [ 1, %24 ]
  %19 = zext nneg i8 %18 to i16
  %20 = add nuw nsw i16 %19, %9
  %21 = shl nuw nsw i16 %20, 5
  %22 = add nuw nsw i16 %21, 20480
  store volatile i8 -128, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  store volatile i16 %22, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  %23 = select i1 %17, i16 7168, i16 7170
  br label %25

24:                                               ; preds = %57
  br i1 %17, label %16, label %15, !llvm.loop !109

25:                                               ; preds = %57, %16
  %26 = phi i8 [ 0, %16 ], [ %59, %57 ]
  br i1 %10, label %57, label %27

27:                                               ; preds = %25
  %tmp1 = zext i8 %26 to i16
  %28 = icmp samesign ugt i16 %11, %tmp1
  br i1 %28, label %57, label %29

29:                                               ; preds = %27
  %tmp = zext i8 %26 to i16
  %30 = icmp samesign ugt i16 %13, %tmp
  br i1 %30, label %31, label %57

31:                                               ; preds = %29
  %32 = zext nneg i8 %26 to i16
  %33 = add i16 %14, %32
  %34 = lshr i16 %33, 1
  %35 = and i16 %34, 255
  %36 = getelementptr inbounds nuw i8, ptr %0, i16 %35
  %37 = load i8, ptr %36, align 1, !tbaa !6
  %38 = icmp ugt i8 %37, 96
  br i1 %38, label %39, label %43

39:                                               ; preds = %31
  %40 = icmp ult i8 %37, 123
  br i1 %40, label %41, label %52

41:                                               ; preds = %39
  %42 = add nsw i8 %37, -32
  br label %47

43:                                               ; preds = %31
  %44 = icmp samesign ugt i8 %37, 31
  br i1 %44, label %45, label %52

45:                                               ; preds = %43
  %46 = icmp eq i8 %37, 96
  br i1 %46, label %52, label %47

47:                                               ; preds = %45, %41
  %48 = phi i8 [ %42, %41 ], [ %37, %45 ]
  %49 = zext nneg i8 %48 to i16
  %50 = shl nuw nsw i16 %49, 2
  %51 = add nsw i16 %50, -64
  br label %52

52:                                               ; preds = %47, %45, %43, %39
  %53 = phi i16 [ %51, %47 ], [ 64, %45 ], [ 64, %43 ], [ 64, %39 ]
  %54 = and i16 %33, 1
  %55 = or disjoint i16 %23, %54
  %56 = or disjoint i16 %55, %53
  br label %57

57:                                               ; preds = %52, %29, %27, %25
  %58 = phi i16 [ %56, %52 ], [ 7168, %29 ], [ 7168, %27 ], [ 7168, %25 ]
  store volatile i16 %58, ptr inttoptr (i16 8472 to ptr), align 8, !tbaa !2
  %59 = add nuw nsw i8 %26, 1
  %60 = icmp eq i8 %59, 32
  br i1 %60, label %24, label %25, !llvm.loop !110
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define internal fastcc void @_title_build(ptr noundef readonly captures(none) %0, i16 noundef range(i16 -2048, 2048) %1, i16 noundef range(i16 -2048, 2048) %2, ptr noundef %3, ptr noundef %4) unnamed_addr #5 {
  %6 = alloca %struct.HScrollW, align 1
  %7 = alloca %struct.HScrollW, align 1
  %8 = alloca i16, align 1
  call void @llvm.lifetime.start.p0(ptr nonnull %6) #13
  call void @llvm.lifetime.start.p0(ptr nonnull %7) #13
  call void @llvm.lifetime.start.p0(ptr nonnull %8) #13
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
  call fastcc void @_title_glyph_band(ptr noundef %6, ptr noundef %7, ptr noundef %8, i16 noundef %1, i16 noundef 8, i16 noundef %12, i16 noundef %14) #12
  %15 = getelementptr inbounds nuw i8, ptr %0, i16 17
  %16 = load i16, ptr %15, align 1, !tbaa !62
  %17 = getelementptr inbounds nuw i8, ptr %0, i16 15
  %18 = load i16, ptr %17, align 1, !tbaa !61
  call fastcc void @_title_glyph_band(ptr noundef %6, ptr noundef %7, ptr noundef %8, i16 noundef %2, i16 noundef %16, i16 noundef %18, i16 noundef 0) #12
  %19 = load i16, ptr %8, align 1, !tbaa !2
  call fastcc void @_title_blank(ptr noundef %6, ptr noundef %7, i16 noundef %19, i16 noundef 224) #12
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
  call void @llvm.lifetime.end.p0(ptr nonnull %8) #13
  call void @llvm.lifetime.end.p0(ptr nonnull %7) #13
  call void @llvm.lifetime.end.p0(ptr nonnull %6) #13
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
  tail call fastcc void @_title_blank(ptr noundef %0, ptr noundef %1, i16 noundef %11, i16 noundef %15) #12
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

59:                                               ; preds = %40, %32
  %60 = getelementptr inbounds nuw i8, ptr %1, i16 2
  %61 = trunc i16 %6 to i8
  %62 = lshr i16 %6, 8
  %63 = trunc nuw i16 %62 to i8
  br label %64

64:                                               ; preds = %72, %59
  %65 = phi i16 [ %28, %59 ], [ %89, %72 ]
  %66 = load i8, ptr %60, align 1, !tbaa !113
  %67 = icmp ult i8 %66, 22
  br i1 %67, label %68, label %.loopexit

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
  br i1 %90, label %.loopexit, label %64, !llvm.loop !114

.loopexit:                                        ; preds = %64, %72
  br label %91

91:                                               ; preds = %.loopexit, %21
  store i16 %19, ptr %2, align 1, !tbaa !2
  br label %92

92:                                               ; preds = %91, %18
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

9:                                                ; preds = %79, %6
  %10 = phi i16 [ %2, %6 ], [ %81, %79 ]
  %11 = sub nsw i16 %3, %10
  %12 = icmp sgt i16 %11, 112
  br i1 %12, label %16, label %13

13:                                               ; preds = %9
  %14 = trunc i16 %11 to i8
  %15 = icmp eq i8 %14, 0
  br i1 %15, label %79, label %16

16:                                               ; preds = %13, %9
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

51:                                               ; preds = %32, %24
  br label %52

52:                                               ; preds = %60, %51
  %53 = phi i16 [ %77, %60 ], [ %20, %51 ]
  %54 = load i8, ptr %8, align 1, !tbaa !113
  %55 = icmp ult i8 %54, 22
  br i1 %55, label %56, label %.loopexit

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
  br i1 %78, label %.loopexit, label %52, !llvm.loop !114

.loopexit:                                        ; preds = %52, %60
  br label %79

79:                                               ; preds = %.loopexit, %13
  %80 = phi i16 [ %11, %13 ], [ %18, %.loopexit ]
  %81 = add nsw i16 %80, %10
  %82 = icmp sgt i16 %3, %81
  br i1 %82, label %9, label %.loopexit1, !llvm.loop !115

.loopexit1:                                       ; preds = %79
  br label %83

83:                                               ; preds = %.loopexit1, %4
  ret void
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(argmem: read)
define internal fastcc { i16, i16 } @boid_acc(ptr noundef readonly captures(none) %0, i8 noundef zeroext range(i8 8, 33) %1, i8 noundef zeroext %2) unnamed_addr #6 {
  %4 = tail call fastcc { i16, i16 } @boid_separation(ptr noundef %0, i8 noundef zeroext %1, i8 noundef zeroext %2) #12
  %5 = extractvalue { i16, i16 } %4, 0
  %6 = extractvalue { i16, i16 } %4, 1
  %7 = tail call fastcc { i16, i16 } @boid_alignment(ptr noundef %0, i8 noundef zeroext %1, i8 noundef zeroext %2) #12
  %8 = extractvalue { i16, i16 } %7, 0
  %9 = extractvalue { i16, i16 } %7, 1
  %10 = tail call fastcc { i16, i16 } @boid_cohesion(ptr noundef %0, i8 noundef zeroext %1, i8 noundef zeroext %2) #12
  %11 = extractvalue { i16, i16 } %10, 0
  %12 = extractvalue { i16, i16 } %10, 1
  %13 = tail call fastcc { i16, i16 } @v2_add(i16 %5, i16 %6, i16 %8, i16 %9) #12
  %14 = extractvalue { i16, i16 } %13, 0
  %15 = extractvalue { i16, i16 } %13, 1
  %16 = tail call fastcc { i16, i16 } @v2_add(i16 %14, i16 %15, i16 %11, i16 %12) #12
  %17 = extractvalue { i16, i16 } %16, 0
  %18 = extractvalue { i16, i16 } %16, 1
  %19 = zext i8 %2 to i16
  %20 = getelementptr inbounds nuw [8 x i8], ptr %0, i16 %19
  %21 = load i16, ptr %20, align 1
  %22 = getelementptr inbounds nuw i8, ptr %20, i16 2
  %23 = load i16, ptr %22, align 1
  %24 = tail call fastcc { i16, i16 } @v2_sub(i16 2048, i16 1792, i16 %21, i16 %23) #12
  %25 = extractvalue { i16, i16 } %24, 0
  %26 = extractvalue { i16, i16 } %24, 1
  %27 = tail call fastcc { i16, i16 } @v2_scale(i16 %25, i16 %26, i16 noundef 256) #12
  %28 = extractvalue { i16, i16 } %27, 0
  %29 = extractvalue { i16, i16 } %27, 1
  %30 = tail call fastcc { i16, i16 } @v2_add(i16 %17, i16 %18, i16 %28, i16 %29) #12
  %31 = extractvalue { i16, i16 } %30, 0
  %32 = extractvalue { i16, i16 } %30, 1
  %33 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %31, i16 %32, i16 noundef 14) #12
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

9:                                                ; preds = %8, %5, %3
  %10 = phi i16 [ %0, %5 ], [ %6, %8 ], [ %2, %3 ]
  %11 = icmp sgt i16 %1, %2
  br i1 %11, label %16, label %12

12:                                               ; preds = %9
  %13 = sub nsw i16 0, %2
  %14 = icmp slt i16 %1, %13
  br i1 %14, label %15, label %16

15:                                               ; preds = %12
  br label %16

16:                                               ; preds = %15, %12, %9
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

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i16(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i16, i1 immarg) #2

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(argmem: read)
define internal fastcc { i16, i16 } @boid_separation(ptr noundef readonly captures(none) %0, i8 noundef zeroext range(i8 8, 33) %1, i8 noundef zeroext %2) unnamed_addr #6 {
  %4 = zext i8 %2 to i16
  %5 = getelementptr inbounds nuw [8 x i8], ptr %0, i16 %4
  %6 = load i16, ptr %5, align 1, !tbaa !2
  %7 = getelementptr inbounds nuw i8, ptr %5, i16 2
  %8 = load i16, ptr %7, align 1, !tbaa !2
  %9 = getelementptr i8, ptr %0, i16 2
  br label %12

10:                                               ; preds = %34
  %11 = tail call fastcc { i16, i16 } @v2_scale(i16 %36, i16 %35, i16 noundef 40) #12
  ret { i16, i16 } %11

12:                                               ; preds = %34, %3
  %lsr.iv2 = phi i8 [ %lsr.iv.next3, %34 ], [ %2, %3 ]
  %lsr.iv = phi i8 [ %lsr.iv.next, %34 ], [ %1, %3 ]
  %13 = phi i8 [ 0, %3 ], [ %37, %34 ]
  %14 = phi i16 [ 0, %3 ], [ %36, %34 ]
  %15 = phi i16 [ 0, %3 ], [ %35, %34 ]
  %16 = icmp eq i8 %lsr.iv2, 0
  br i1 %16, label %34, label %17

17:                                               ; preds = %12
  %18 = zext i8 %13 to i16
  %scevgep1 = getelementptr i8, ptr %0, i16 %18
  %19 = load i16, ptr %scevgep1, align 1
  %20 = zext i8 %13 to i16
  %scevgep = getelementptr i8, ptr %9, i16 %20
  %21 = load i16, ptr %scevgep, align 1
  %22 = tail call fastcc { i16, i16 } @v2_sub(i16 %6, i16 %8, i16 %19, i16 %21) #12
  %23 = extractvalue { i16, i16 } %22, 0
  %24 = extractvalue { i16, i16 } %22, 1
  %25 = sext i16 %23 to i32
  %26 = mul nsw i32 %25, %25
  %27 = sext i16 %24 to i32
  %28 = mul nsw i32 %27, %27
  %29 = add nuw nsw i32 %28, %26
  %30 = icmp samesign ult i32 %29, 65536
  br i1 %30, label %31, label %34

31:                                               ; preds = %17
  %32 = add i16 %23, %14
  %33 = add i16 %24, %15
  br label %34

34:                                               ; preds = %31, %17, %12
  %35 = phi i16 [ %15, %12 ], [ %33, %31 ], [ %15, %17 ]
  %36 = phi i16 [ %14, %12 ], [ %32, %31 ], [ %14, %17 ]
  %37 = add i8 %13, 8
  %lsr.iv.next = add nsw i8 %lsr.iv, -1
  %lsr.iv.next3 = add i8 %lsr.iv2, -1
  %38 = icmp eq i8 %lsr.iv.next, 0
  br i1 %38, label %10, label %12, !llvm.loop !116
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

12:                                               ; preds = %44
  %13 = icmp eq i16 %45, 0
  br i1 %13, label %66, label %50

14:                                               ; preds = %44, %3
  %lsr.iv4 = phi i8 [ %lsr.iv.next5, %44 ], [ %2, %3 ]
  %lsr.iv = phi i8 [ %lsr.iv.next, %44 ], [ %1, %3 ]
  %15 = phi i8 [ 0, %3 ], [ %48, %44 ]
  %16 = phi i32 [ 0, %3 ], [ %47, %44 ]
  %17 = phi i32 [ 0, %3 ], [ %46, %44 ]
  %18 = phi i16 [ 0, %3 ], [ %45, %44 ]
  %19 = icmp eq i8 %lsr.iv4, 0
  br i1 %19, label %44, label %20

20:                                               ; preds = %14
  %21 = zext i8 %15 to i16
  %scevgep3 = getelementptr i8, ptr %0, i16 %21
  %22 = load i16, ptr %scevgep3, align 1
  %23 = zext i8 %15 to i16
  %scevgep2 = getelementptr i8, ptr %9, i16 %23
  %24 = load i16, ptr %scevgep2, align 1
  %25 = tail call fastcc { i16, i16 } @v2_sub(i16 %22, i16 %24, i16 %6, i16 %8) #12
  %26 = extractvalue { i16, i16 } %25, 0
  %27 = extractvalue { i16, i16 } %25, 1
  %28 = sext i16 %26 to i32
  %29 = mul nsw i32 %28, %28
  %30 = sext i16 %27 to i32
  %31 = mul nsw i32 %30, %30
  %32 = add nuw nsw i32 %31, %29
  %33 = icmp samesign ult i32 %32, 589824
  br i1 %33, label %34, label %44

34:                                               ; preds = %20
  %35 = zext i8 %15 to i16
  %scevgep1 = getelementptr i8, ptr %10, i16 %35
  %36 = load i16, ptr %scevgep1, align 1, !tbaa !46
  %37 = sext i16 %36 to i32
  %38 = add nsw i32 %16, %37
  %39 = zext i8 %15 to i16
  %scevgep = getelementptr i8, ptr %11, i16 %39
  %40 = load i16, ptr %scevgep, align 1, !tbaa !47
  %41 = sext i16 %40 to i32
  %42 = add nsw i32 %17, %41
  %43 = add nsw i16 %18, 1
  br label %44

44:                                               ; preds = %34, %20, %14
  %45 = phi i16 [ %18, %14 ], [ %43, %34 ], [ %18, %20 ]
  %46 = phi i32 [ %17, %14 ], [ %42, %34 ], [ %17, %20 ]
  %47 = phi i32 [ %16, %14 ], [ %38, %34 ], [ %16, %20 ]
  %48 = add i8 %15, 8
  %lsr.iv.next = add nsw i8 %lsr.iv, -1
  %lsr.iv.next5 = add i8 %lsr.iv4, -1
  %49 = icmp eq i8 %lsr.iv.next, 0
  br i1 %49, label %12, label %14, !llvm.loop !117

50:                                               ; preds = %12
  %51 = sext i16 %45 to i32
  %52 = sdiv i32 %47, %51
  %53 = trunc i32 %52 to i16
  %54 = sdiv i32 %46, %51
  %55 = trunc i32 %54 to i16
  %56 = getelementptr inbounds nuw i8, ptr %5, i16 4
  %57 = load i16, ptr %56, align 1
  %58 = getelementptr inbounds nuw i8, ptr %5, i16 6
  %59 = load i16, ptr %58, align 1
  %60 = tail call fastcc { i16, i16 } @v2_sub(i16 %53, i16 %55, i16 %57, i16 %59) #12
  %61 = extractvalue { i16, i16 } %60, 0
  %62 = extractvalue { i16, i16 } %60, 1
  %63 = tail call fastcc { i16, i16 } @v2_scale(i16 %61, i16 %62, i16 noundef 16) #12
  %64 = extractvalue { i16, i16 } %63, 0
  %65 = extractvalue { i16, i16 } %63, 1
  br label %66

66:                                               ; preds = %50, %12
  %67 = phi i16 [ %65, %50 ], [ 0, %12 ]
  %68 = phi i16 [ %64, %50 ], [ 0, %12 ]
  %69 = insertvalue { i16, i16 } poison, i16 %68, 0
  %70 = insertvalue { i16, i16 } %69, i16 %67, 1
  ret { i16, i16 } %70
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

10:                                               ; preds = %38
  %11 = icmp eq i16 %39, 0
  br i1 %11, label %56, label %44

12:                                               ; preds = %38, %3
  %lsr.iv2 = phi i8 [ %lsr.iv.next3, %38 ], [ %2, %3 ]
  %lsr.iv = phi i8 [ %lsr.iv.next, %38 ], [ %1, %3 ]
  %13 = phi i8 [ 0, %3 ], [ %42, %38 ]
  %14 = phi i32 [ 0, %3 ], [ %41, %38 ]
  %15 = phi i32 [ 0, %3 ], [ %40, %38 ]
  %16 = phi i16 [ 0, %3 ], [ %39, %38 ]
  %17 = icmp eq i8 %lsr.iv2, 0
  br i1 %17, label %38, label %18

18:                                               ; preds = %12
  %19 = zext i8 %13 to i16
  %scevgep1 = getelementptr i8, ptr %0, i16 %19
  %20 = load i16, ptr %scevgep1, align 1
  %21 = zext i8 %13 to i16
  %scevgep = getelementptr i8, ptr %9, i16 %21
  %22 = load i16, ptr %scevgep, align 1
  %23 = tail call fastcc { i16, i16 } @v2_sub(i16 %20, i16 %22, i16 %6, i16 %8) #12
  %24 = extractvalue { i16, i16 } %23, 0
  %25 = extractvalue { i16, i16 } %23, 1
  %26 = sext i16 %24 to i32
  %27 = mul nsw i32 %26, %26
  %28 = sext i16 %25 to i32
  %29 = mul nsw i32 %28, %28
  %30 = add nuw nsw i32 %29, %27
  %31 = icmp samesign ult i32 %30, 589824
  br i1 %31, label %32, label %38

32:                                               ; preds = %18
  %33 = sext i16 %20 to i32
  %34 = add nsw i32 %14, %33
  %35 = sext i16 %22 to i32
  %36 = add nsw i32 %15, %35
  %37 = add nsw i16 %16, 1
  br label %38

38:                                               ; preds = %32, %18, %12
  %39 = phi i16 [ %16, %12 ], [ %37, %32 ], [ %16, %18 ]
  %40 = phi i32 [ %15, %12 ], [ %36, %32 ], [ %15, %18 ]
  %41 = phi i32 [ %14, %12 ], [ %34, %32 ], [ %14, %18 ]
  %42 = add i8 %13, 8
  %lsr.iv.next = add nsw i8 %lsr.iv, -1
  %lsr.iv.next3 = add i8 %lsr.iv2, -1
  %43 = icmp eq i8 %lsr.iv.next, 0
  br i1 %43, label %10, label %12, !llvm.loop !118

44:                                               ; preds = %10
  %45 = sext i16 %39 to i32
  %46 = sdiv i32 %41, %45
  %47 = trunc i32 %46 to i16
  %48 = sdiv i32 %40, %45
  %49 = trunc i32 %48 to i16
  %50 = tail call fastcc { i16, i16 } @v2_sub(i16 %47, i16 %49, i16 %6, i16 %8) #12
  %51 = extractvalue { i16, i16 } %50, 0
  %52 = extractvalue { i16, i16 } %50, 1
  %53 = tail call fastcc { i16, i16 } @v2_scale(i16 %51, i16 %52, i16 noundef 40) #12
  %54 = extractvalue { i16, i16 } %53, 0
  %55 = extractvalue { i16, i16 } %53, 1
  br label %56

56:                                               ; preds = %44, %10
  %57 = phi i16 [ %55, %44 ], [ 0, %10 ]
  %58 = phi i16 [ %54, %44 ], [ 0, %10 ]
  %59 = insertvalue { i16, i16 } poison, i16 %58, 0
  %60 = insertvalue { i16, i16 } %59, i16 %57, 1
  ret { i16, i16 } %60
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
define internal fastcc void @upq_flush() unnamed_addr #8 {
  %1 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 177), align 1, !tbaa !119
  %2 = zext i8 %1 to i16
  %3 = shl nuw nsw i16 %2, 4
  %4 = add nuw nsw i16 %3, 17152
  %5 = inttoptr i16 %4 to ptr
  %6 = shl nuw i16 1, %2
  %7 = trunc i16 %6 to i8
  %8 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %9 = icmp eq i8 %8, 0
  br i1 %9, label %93, label %10

10:                                               ; preds = %0
  %11 = getelementptr inbounds nuw i8, ptr %5, i16 1
  %12 = getelementptr inbounds nuw i8, ptr %5, i16 2
  %13 = getelementptr inbounds nuw i8, ptr %5, i16 3
  %14 = getelementptr inbounds nuw i8, ptr %5, i16 4
  %15 = getelementptr inbounds nuw i8, ptr %5, i16 5
  %16 = getelementptr inbounds nuw i8, ptr %5, i16 6
  br label %17

17:                                               ; preds = %74, %10
  %lsr.iv2 = phi ptr [ %scevgep3, %74 ], [ @main.a, %10 ]
  %18 = phi i8 [ %8, %10 ], [ %77, %74 ]
  %19 = phi i16 [ 0, %10 ], [ %75, %74 ]
  %20 = phi i8 [ 0, %10 ], [ %76, %74 ]
  %scevgep10 = getelementptr i8, ptr %lsr.iv2, i16 10
  %21 = load i8, ptr %scevgep10, align 1, !tbaa !33
  switch i8 %21, label %39 [
    i8 3, label %22
    i8 4, label %30
  ]

22:                                               ; preds = %17
  %23 = load i16, ptr %lsr.iv2, align 1, !tbaa !35
  %24 = inttoptr i16 %23 to ptr
  %scevgep8 = getelementptr i8, ptr %lsr.iv2, i16 2
  %25 = load i16, ptr %scevgep8, align 1, !tbaa !39
  %26 = trunc i16 %25 to i8
  store volatile i8 %26, ptr %24, align 1, !tbaa !6
  %27 = load i16, ptr %scevgep8, align 1, !tbaa !39
  %28 = lshr i16 %27, 8
  %29 = trunc nuw i16 %28 to i8
  store volatile i8 %29, ptr %24, align 1, !tbaa !6
  br label %74

30:                                               ; preds = %17
  %31 = load i16, ptr %lsr.iv2, align 1, !tbaa !35
  %32 = inttoptr i16 %31 to ptr
  %scevgep7 = getelementptr i8, ptr %lsr.iv2, i16 2
  %33 = load i16, ptr %scevgep7, align 1, !tbaa !39
  %34 = trunc i16 %33 to i8
  store volatile i8 %34, ptr %32, align 1, !tbaa !6
  %35 = load i16, ptr %scevgep7, align 1, !tbaa !39
  %36 = lshr i16 %35, 8
  %37 = trunc nuw i16 %36 to i8
  %38 = getelementptr inbounds nuw i8, ptr %32, i16 1
  store volatile i8 %37, ptr %38, align 1, !tbaa !6
  br label %74

39:                                               ; preds = %17
  %40 = icmp eq i16 %19, 0
  br i1 %40, label %45, label %41

41:                                               ; preds = %39
  %scevgep5 = getelementptr i8, ptr %lsr.iv2, i16 4
  %42 = load i16, ptr %scevgep5, align 1, !tbaa !41
  %43 = add i16 %42, %19
  %44 = icmp ugt i16 %43, 5100
  br i1 %44, label %._crit_edge, label %45

45:                                               ; preds = %41, %39
  switch i8 %21, label %52 [
    i8 0, label %46
    i8 1, label %49
  ]

46:                                               ; preds = %45
  %scevgep11 = getelementptr i8, ptr %lsr.iv2, i16 9
  %47 = load i8, ptr %scevgep11, align 1, !tbaa !36
  store volatile i8 %47, ptr inttoptr (i16 8469 to ptr), align 1, !tbaa !6
  %48 = load i16, ptr %lsr.iv2, align 1, !tbaa !35
  store volatile i16 %48, ptr inttoptr (i16 8470 to ptr), align 2, !tbaa !2
  br label %58

49:                                               ; preds = %45
  %50 = load i16, ptr %lsr.iv2, align 1, !tbaa !35
  %51 = trunc i16 %50 to i8
  store volatile i8 %51, ptr inttoptr (i16 8481 to ptr), align 1, !tbaa !6
  br label %58

52:                                               ; preds = %45
  %53 = load i16, ptr %lsr.iv2, align 1, !tbaa !35
  %54 = trunc i16 %53 to i8
  store volatile i8 %54, ptr inttoptr (i16 8450 to ptr), align 2, !tbaa !6
  %55 = load i16, ptr %lsr.iv2, align 1, !tbaa !35
  %56 = lshr i16 %55, 8
  %57 = trunc nuw i16 %56 to i8
  store volatile i8 %57, ptr inttoptr (i16 8451 to ptr), align 1, !tbaa !6
  br label %58

58:                                               ; preds = %52, %49, %46
  %scevgep12 = getelementptr i8, ptr %lsr.iv2, i16 8
  %59 = load i8, ptr %scevgep12, align 1, !tbaa !38
  store volatile i8 %59, ptr %5, align 16, !tbaa !6
  %scevgep13 = getelementptr i8, ptr %lsr.iv2, i16 7
  %60 = load i8, ptr %scevgep13, align 1, !tbaa !37
  store volatile i8 %60, ptr %11, align 1, !tbaa !6
  %scevgep6 = getelementptr i8, ptr %lsr.iv2, i16 2
  %61 = load i16, ptr %scevgep6, align 1, !tbaa !39
  %62 = trunc i16 %61 to i8
  store volatile i8 %62, ptr %12, align 2, !tbaa !6
  %63 = load i16, ptr %scevgep6, align 1, !tbaa !39
  %64 = lshr i16 %63, 8
  %65 = trunc nuw i16 %64 to i8
  store volatile i8 %65, ptr %13, align 1, !tbaa !6
  %scevgep9 = getelementptr i8, ptr %lsr.iv2, i16 6
  %66 = load i8, ptr %scevgep9, align 1, !tbaa !40
  store volatile i8 %66, ptr %14, align 4, !tbaa !6
  %scevgep4 = getelementptr i8, ptr %lsr.iv2, i16 4
  %67 = load i16, ptr %scevgep4, align 1, !tbaa !41
  %68 = trunc i16 %67 to i8
  store volatile i8 %68, ptr %15, align 1, !tbaa !6
  %69 = load i16, ptr %scevgep4, align 1, !tbaa !41
  %70 = lshr i16 %69, 8
  %71 = trunc nuw i16 %70 to i8
  store volatile i8 %71, ptr %16, align 2, !tbaa !6
  store volatile i8 %7, ptr inttoptr (i16 16907 to ptr), align 1, !tbaa !6
  %72 = load i16, ptr %scevgep4, align 1, !tbaa !41
  %73 = add i16 %72, %19
  br label %74

74:                                               ; preds = %58, %30, %22
  %75 = phi i16 [ %19, %22 ], [ %19, %30 ], [ %73, %58 ]
  %76 = add nuw i8 %20, 1
  %77 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %scevgep3 = getelementptr i8, ptr %lsr.iv2, i16 11
  %78 = icmp ult i8 %76, %77
  br i1 %78, label %17, label %split

split:                                            ; preds = %74
  %.lcssa14 = phi i8 [ %76, %74 ]
  br label %79

._crit_edge:                                      ; preds = %41
  %.lcssa15 = phi i8 [ %20, %41 ]
  br label %79

79:                                               ; preds = %split, %._crit_edge
  %80 = phi i8 [ %18, %._crit_edge ], [ %77, %split ]
  %81 = phi i8 [ %.lcssa15, %._crit_edge ], [ %.lcssa14, %split ]
  %82 = icmp ult i8 %81, %80
  br i1 %82, label %83, label %93

83:                                               ; preds = %79
  %84 = icmp eq i8 %81, 0
  br i1 %84, label %95, label %.preheader

.preheader:                                       ; preds = %83
  %85 = zext i8 %81 to i16
  %86 = mul nuw nsw i16 %85, 11
  br label %87

87:                                               ; preds = %.preheader, %87
  %lsr.iv = phi ptr [ @main.a, %.preheader ], [ %scevgep, %87 ]
  %88 = phi i8 [ %89, %87 ], [ 0, %.preheader ]
  %89 = add i8 %88, 1
  %scevgep1 = getelementptr i8, ptr %lsr.iv, i16 %86
  tail call void @llvm.memcpy.p0.p0.i16(ptr noundef nonnull align 1 dereferenceable(11) %lsr.iv, ptr noundef nonnull align 1 dereferenceable(11) %scevgep1, i16 11, i1 false), !tbaa.struct !120
  %90 = load i8, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  %scevgep = getelementptr i8, ptr %lsr.iv, i16 11
  %91 = add i8 %81, %89
  %92 = icmp ult i8 %91, %90
  br i1 %92, label %87, label %.loopexit, !llvm.loop !121

.loopexit:                                        ; preds = %87
  %.lcssa = phi i8 [ %89, %87 ]
  br label %93

93:                                               ; preds = %.loopexit, %79, %0
  %94 = phi i8 [ 0, %79 ], [ 0, %0 ], [ %.lcssa, %.loopexit ]
  store i8 %94, ptr getelementptr inbounds nuw (i8, ptr @main.a, i16 176), align 1, !tbaa !32
  br label %95

95:                                               ; preds = %93, %83
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #9

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #10

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i16(ptr writeonly captures(none), i8, i16, i1 immarg) #10

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16,+mos-a16,+mos-xy16" }
attributes #1 = { nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "nonreentrant" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16,+mos-a16,+mos-xy16" }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #3 = { nofree norecurse nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "nonreentrant" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16,+mos-a16,+mos-xy16" }
attributes #4 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "nonreentrant" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16,+mos-a16,+mos-xy16" }
attributes #5 = { nofree norecurse nosync nounwind optsize memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "nonreentrant" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16,+mos-a16,+mos-xy16" }
attributes #6 = { nofree noinline norecurse nosync nounwind optsize memory(argmem: read) "frame-pointer"="all" "no-trapping-math"="true" "nonreentrant" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16,+mos-a16,+mos-xy16" }
attributes #7 = { mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "nonreentrant" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16,+mos-a16,+mos-xy16" }
attributes #8 = { nofree noinline norecurse nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "nonreentrant" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16,+mos-a16,+mos-xy16" }
attributes #9 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #10 = { nocallback nofree nosync nounwind willreturn memory(argmem: write) "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #11 = { nounwind optsize }
attributes #12 = { optsize }
attributes #13 = { nounwind }

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
