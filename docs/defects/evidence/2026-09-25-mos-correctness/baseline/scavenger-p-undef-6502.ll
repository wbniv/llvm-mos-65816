; RUN: llc -mtriple=mos -mcpu=mos6502 -O0 -stop-after=prolog-epilog -verify-machineinstrs < %s | FileCheck %s

; Stock 6502 at -O0 (reduced with llvm-reduce from gcc.c-torture/execute/strlen-4.c).
; The frame is larger than 255 bytes, so a frame-index expansion is an
; AddrLostk/AddrHistk carry chain whose carry the register scavenger must place
; in $c. The fast register allocator reloads a spilled pointer between the `sec`
; that seeds a 16-bit subtraction and the `sbc` that consumes it, so $c is live
; across that reload and the scavenger must preserve $p around it.
;
; Both directions of the save are pinned:
;   * where nothing of $p holds a value (the preceding ADC dead-flagged $c and
;     $v), the PHP must read an undef $p, or the verifier rejects it;
;   * where $c is live, the PHP must stay a plain `PH $p`; an over-eager undef
;     would let that flag definition move or die.
; Without the undef flag the verifier rejects the first push after Prologue/
; Epilogue Insertion ("Using an undefined physical register" on PH $p).

; CHECK-LABEL: name: test_array_ptr
; CHECK: PH undef $p
; CHECK: $p = PL
; CHECK: PH $p
; CHECK-NOT: PH undef $p
; CHECK: $p = PL

target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

; Function Attrs: noinline optnone
define ptr @test_array_ptr(ptr %0, i16 %1, ptr %2, ptr %3, i16 %4, i16 %5, i16 %6, i16 %7) #0 {
  %9 = alloca i16, align 1
  %10 = alloca i16, align 1
  %11 = alloca i16, align 1
  br i1 false, label %13, label %12

12:                                               ; preds = %8
  unreachable

13:                                               ; preds = %8
  br i1 false, label %15, label %14

14:                                               ; preds = %13
  unreachable

15:                                               ; preds = %13
  br i1 false, label %17, label %16

16:                                               ; preds = %15
  unreachable

17:                                               ; preds = %15
  br i1 false, label %19, label %18

18:                                               ; preds = %17
  unreachable

19:                                               ; preds = %17
  %20 = load i16, ptr null, align 1
  %21 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %20
  %22 = load i16, ptr %9, align 1
  %23 = getelementptr [3 x [28 x i8]], ptr %21, i16 0, i16 %22
  %24 = load i16, ptr %9, align 1
  %25 = getelementptr [28 x i8], ptr %23, i16 %24
  %26 = load volatile i16, ptr %25, align 1
  br i1 false, label %28, label %27

27:                                               ; preds = %19
  unreachable

28:                                               ; preds = %19
  %29 = load i16, ptr %9, align 1
  %30 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %29
  %31 = load i16, ptr %9, align 1
  %32 = getelementptr [3 x [28 x i8]], ptr %30, i16 0, i16 %31
  %33 = load i16, ptr null, align 1
  %34 = getelementptr [28 x i8], ptr %32, i16 %33
  %35 = load volatile i16, ptr %34, align 1
  br i1 false, label %37, label %36

36:                                               ; preds = %28
  unreachable

37:                                               ; preds = %28
  %38 = load i16, ptr %3, align 1
  %39 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %38
  %40 = load i16, ptr %0, align 1
  %41 = getelementptr [3 x [28 x i8]], ptr %39, i16 0, i16 %40
  %42 = load i16, ptr null, align 1
  %43 = getelementptr [28 x i8], ptr %41, i16 %42
  %44 = load volatile i16, ptr %43, align 1
  %45 = load i16, ptr null, align 1
  %46 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %45
  %47 = load i16, ptr null, align 1
  %48 = getelementptr [3 x [28 x i8]], ptr %46, i16 0, i16 %47
  %49 = load i16, ptr null, align 1
  %50 = getelementptr [28 x i8], ptr %48, i16 %49
  %51 = load volatile i16, ptr %50, align 1
  br label %52

52:                                               ; preds = %37
  %53 = load volatile i16, ptr %2, align 1
  br i1 false, label %55, label %54

54:                                               ; preds = %52
  unreachable

55:                                               ; preds = %52
  %56 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %4
  %57 = load i16, ptr %10, align 1
  %58 = getelementptr [3 x [28 x i8]], ptr %56, i16 0, i16 %57
  %59 = load i16, ptr %10, align 1
  %60 = getelementptr [28 x i8], ptr %58, i16 %59
  %61 = load volatile i16, ptr %60, align 1
  br i1 false, label %63, label %62

62:                                               ; preds = %55
  unreachable

63:                                               ; preds = %55
  %64 = load i16, ptr null, align 1
  %65 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %64
  %66 = load i16, ptr %11, align 1
  %67 = getelementptr [3 x [28 x i8]], ptr %65, i16 0, i16 %66
  %68 = load i16, ptr %11, align 1
  %69 = getelementptr [28 x i8], ptr %67, i16 %68
  %70 = load volatile i16, ptr %69, align 1
  %71 = load i16, ptr null, align 1
  %72 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %71
  %73 = load i16, ptr null, align 1
  %74 = getelementptr [3 x [28 x i8]], ptr %72, i16 0, i16 %73
  %75 = load i16, ptr null, align 1
  %76 = getelementptr [28 x i8], ptr %74, i16 %75
  %77 = load volatile i16, ptr %76, align 1
  %78 = load i16, ptr null, align 1
  %79 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %78
  %80 = load i16, ptr null, align 1
  %81 = getelementptr [3 x [28 x i8]], ptr %79, i16 0, i16 %80
  %82 = load i16, ptr null, align 1
  %83 = getelementptr [28 x i8], ptr %81, i16 %82
  %84 = load volatile i16, ptr %83, align 1
  %85 = load i16, ptr null, align 1
  %86 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %85
  %87 = load i16, ptr %9, align 1
  %88 = getelementptr [3 x [28 x i8]], ptr %86, i16 0, i16 %87
  %89 = load i16, ptr %9, align 1
  %90 = getelementptr [28 x i8], ptr %88, i16 %89
  %91 = load volatile i16, ptr %90, align 1
  %92 = load i16, ptr null, align 1
  %93 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %92
  %94 = load i16, ptr null, align 1
  %95 = getelementptr [3 x [28 x i8]], ptr %93, i16 0, i16 %94
  %96 = load i16, ptr null, align 1
  %97 = getelementptr [28 x i8], ptr %95, i16 %96
  %98 = load volatile i16, ptr %97, align 1
  %99 = load i16, ptr null, align 1
  %100 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %99
  %101 = load i16, ptr null, align 1
  %102 = getelementptr [3 x [28 x i8]], ptr %100, i16 0, i16 %101
  %103 = load i16, ptr null, align 1
  %104 = getelementptr [28 x i8], ptr %102, i16 %103
  %105 = load volatile i16, ptr %104, align 1
  %106 = load i16, ptr %10, align 1
  %107 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %106
  %108 = load i16, ptr %10, align 1
  %109 = getelementptr [3 x [28 x i8]], ptr %107, i16 0, i16 %108
  %110 = load i16, ptr null, align 1
  %111 = getelementptr [28 x i8], ptr %109, i16 %110
  %112 = load volatile i16, ptr %111, align 1
  br label %113

113:                                              ; preds = %63
  %114 = load i16, ptr %10, align 1
  %115 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %114
  %116 = load i16, ptr %10, align 1
  %117 = getelementptr [3 x [28 x i8]], ptr %115, i16 0, i16 %116
  %118 = load i16, ptr null, align 1
  %119 = getelementptr [28 x i8], ptr %117, i16 %118
  %120 = load volatile i16, ptr %119, align 1
  br i1 false, label %122, label %121

121:                                              ; preds = %113
  unreachable

122:                                              ; preds = %113
  %123 = load i16, ptr %10, align 1
  %124 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %123
  %125 = load i16, ptr %10, align 1
  %126 = getelementptr [3 x [28 x i8]], ptr %124, i16 0, i16 %125
  %127 = load i16, ptr null, align 1
  %128 = getelementptr [28 x i8], ptr %126, i16 %127
  %129 = load volatile i16, ptr %128, align 1
  br i1 false, label %131, label %130

130:                                              ; preds = %122
  unreachable

131:                                              ; preds = %122
  %132 = load i16, ptr null, align 1
  %133 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %132
  %134 = load i16, ptr %11, align 1
  %135 = getelementptr [3 x [28 x i8]], ptr %133, i16 0, i16 %134
  %136 = load i16, ptr %11, align 1
  %137 = getelementptr [28 x i8], ptr %135, i16 %136
  %138 = load volatile i16, ptr %137, align 1
  %139 = load i16, ptr null, align 1
  %140 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %139
  %141 = load i16, ptr null, align 1
  %142 = getelementptr [3 x [28 x i8]], ptr %140, i16 0, i16 %141
  %143 = load i16, ptr null, align 1
  %144 = getelementptr [28 x i8], ptr %142, i16 %143
  %145 = load volatile i16, ptr %144, align 1
  br label %146

146:                                              ; preds = %131
  %147 = load i16, ptr null, align 1
  %148 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %147
  %149 = load i16, ptr null, align 1
  %150 = getelementptr [3 x [28 x i8]], ptr %148, i16 0, i16 %149
  %151 = load i16, ptr %9, align 1
  %152 = getelementptr [28 x i8], ptr %150, i16 %151
  %153 = load volatile i16, ptr %152, align 1
  %154 = load i16, ptr %9, align 1
  %155 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %154
  %156 = load i16, ptr null, align 1
  %157 = getelementptr [3 x [28 x i8]], ptr %155, i16 0, i16 %156
  %158 = load i16, ptr null, align 1
  %159 = getelementptr [28 x i8], ptr %157, i16 %158
  %160 = load volatile i16, ptr %159, align 1
  br i1 false, label %162, label %161

161:                                              ; preds = %146
  unreachable

162:                                              ; preds = %146
  %163 = load i16, ptr %9, align 1
  %164 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %163
  %165 = load i16, ptr %9, align 1
  %166 = getelementptr [3 x [28 x i8]], ptr %164, i16 0, i16 %165
  %167 = load i16, ptr null, align 1
  %168 = getelementptr [28 x i8], ptr %166, i16 %167
  %169 = load volatile i16, ptr %168, align 1
  br i1 false, label %171, label %170

170:                                              ; preds = %162
  unreachable

171:                                              ; preds = %162
  %172 = load i16, ptr %9, align 1
  %173 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %172
  %174 = load i16, ptr %9, align 1
  %175 = getelementptr [3 x [28 x i8]], ptr %173, i16 0, i16 %174
  %176 = load i16, ptr null, align 1
  %177 = getelementptr [28 x i8], ptr %175, i16 %176
  %178 = load volatile i16, ptr %177, align 1
  br i1 false, label %180, label %179

179:                                              ; preds = %171
  unreachable

180:                                              ; preds = %171
  %181 = load i16, ptr null, align 1
  %182 = getelementptr [3 x [28 x i8]], ptr null, i16 0, i16 %181
  %183 = sub i16 0, %1
  %184 = getelementptr [28 x i8], ptr %182, i16 %183
  %185 = call i16 null(ptr %184)
  %186 = icmp eq i16 %4, 1
  br i1 %186, label %188, label %187

187:                                              ; preds = %180
  unreachable

188:                                              ; preds = %180
  %189 = load i16, ptr null, align 1
  %190 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %189
  %191 = load i16, ptr null, align 1
  %192 = getelementptr [3 x [28 x i8]], ptr %190, i16 0, i16 %191
  %193 = load i16, ptr null, align 1
  %194 = getelementptr [28 x i8], ptr %192, i16 %193
  %195 = load volatile i16, ptr %194, align 1
  %196 = load i16, ptr null, align 1
  %197 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %196
  %198 = load i16, ptr null, align 1
  %199 = getelementptr [3 x [28 x i8]], ptr %197, i16 0, i16 %198
  %200 = load i16, ptr null, align 1
  %201 = getelementptr [28 x i8], ptr %199, i16 %200
  %202 = load volatile i16, ptr %201, align 1
  %203 = load i16, ptr null, align 1
  %204 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %203
  %205 = load i16, ptr null, align 1
  %206 = getelementptr [3 x [28 x i8]], ptr %204, i16 0, i16 %205
  %207 = load i16, ptr null, align 1
  %208 = getelementptr [28 x i8], ptr %206, i16 %207
  %209 = load volatile i16, ptr %208, align 1
  %210 = load i16, ptr null, align 1
  %211 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %210
  %212 = load i16, ptr null, align 1
  %213 = getelementptr [3 x [28 x i8]], ptr %211, i16 0, i16 %212
  %214 = load i16, ptr null, align 1
  %215 = getelementptr [28 x i8], ptr %213, i16 %214
  %216 = load volatile i16, ptr %215, align 1
  %217 = load i16, ptr null, align 1
  %218 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %217
  %219 = getelementptr [3 x [28 x i8]], ptr %218, i16 0, i16 %5
  %220 = load i16, ptr null, align 1
  %221 = getelementptr [28 x i8], ptr %219, i16 %220
  %222 = load volatile i16, ptr %221, align 1
  %223 = load i16, ptr null, align 1
  %224 = getelementptr [2 x [3 x [28 x i8]]], ptr null, i16 0, i16 %223
  %225 = getelementptr [3 x [28 x i8]], ptr %224, i16 0, i16 %6
  %226 = getelementptr [28 x i8], ptr %225, i16 %7
  %227 = load volatile i16, ptr %226, align 1
  ret ptr %2
}

attributes #0 = { noinline optnone }
