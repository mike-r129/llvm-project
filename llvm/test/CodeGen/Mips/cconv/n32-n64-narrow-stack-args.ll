; RUN: llc -mtriple=mips64 -relocation-model=static -target-abi n32 < %s | FileCheck --check-prefixes=ALL,BE %s
; RUN: llc -mtriple=mips64el -relocation-model=static -target-abi n32 < %s | FileCheck --check-prefixes=ALL,LE %s
; RUN: llc -mtriple=mips64 -relocation-model=static -target-abi n64 < %s | FileCheck --check-prefixes=ALL,BE %s
; RUN: llc -mtriple=mips64el -relocation-model=static -target-abi n64 < %s | FileCheck --check-prefixes=ALL,LE %s

; The N32/N64 stack slots are 64 bits wide, but a caller only has to write the
; bytes of a 32-bit (or narrower, promoted to 32 bits) argument; GCC stores it
; with `sw` and leaves the rest of the slot alone. A callee must therefore not
; load the whole slot and trust the upper half to be extended, even when the
; parameter is `signext` or `zeroext`. It loads the 32 bits that were written
; (the high-address half on big endian) with the matching extending load.

; The ninth argument is the first one that is passed on the stack.

define i64 @i32_signext(i32 signext %a0, i32 signext %a1, i32 signext %a2, i32 signext %a3, i32 signext %a4, i32 signext %a5, i32 signext %a6, i32 signext %a7, i32 signext %a8) {
; ALL-LABEL: i32_signext:
; BE:           lw $2, 4($sp)
; LE:           lw $2, 0($sp)
  %r = sext i32 %a8 to i64
  ret i64 %r
}

define i64 @i32_zeroext(i32 zeroext %a0, i32 zeroext %a1, i32 zeroext %a2, i32 zeroext %a3, i32 zeroext %a4, i32 zeroext %a5, i32 zeroext %a6, i32 zeroext %a7, i32 zeroext %a8) {
; ALL-LABEL: i32_zeroext:
; BE:           lwu $2, 4($sp)
; LE:           lwu $2, 0($sp)
  %r = zext i32 %a8 to i64
  ret i64 %r
}

define i32 @i32_noext(i32 %a0, i32 %a1, i32 %a2, i32 %a3, i32 %a4, i32 %a5, i32 %a6, i32 %a7, i32 %a8) {
; ALL-LABEL: i32_noext:
; BE:           lw $2, 4($sp)
; LE:           lw $2, 0($sp)
  ret i32 %a8
}

define i64 @i16_signext(i32 %a0, i32 %a1, i32 %a2, i32 %a3, i32 %a4, i32 %a5, i32 %a6, i32 %a7, i16 signext %a8) {
; ALL-LABEL: i16_signext:
; BE:           lw $2, 4($sp)
; LE:           lw $2, 0($sp)
  %r = sext i16 %a8 to i64
  ret i64 %r
}

define i64 @i8_zeroext(i32 %a0, i32 %a1, i32 %a2, i32 %a3, i32 %a4, i32 %a5, i32 %a6, i32 %a7, i8 zeroext %a8) {
; ALL-LABEL: i8_zeroext:
; BE:           lwu $2, 4($sp)
; LE:           lwu $2, 0($sp)
  %r = zext i8 %a8 to i64
  ret i64 %r
}

; A 64-bit argument still takes the whole slot.
define i64 @i64_arg(i32 %a0, i32 %a1, i32 %a2, i32 %a3, i32 %a4, i32 %a5, i32 %a6, i32 %a7, i64 %a8) {
; ALL-LABEL: i64_arg:
; ALL:          ld $2, 0($sp)
  ret i64 %a8
}
