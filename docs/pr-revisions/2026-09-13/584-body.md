On SPC700, LDImm accepts imaginary-register destinations to represent `mov dp, #imm`. `combineLdImm` tracks only A/X/Y; processing an imaginary destination through that path dereferences a null tracking pointer.

Restrict immediate-load folding to GPR destinations in the existing filtering condition. Other instructions use the existing register-invalidation path. The sibling TA handler keeps its original behavior.

The SPC700 MIR regression covers an imaginary-register immediate load and confirms that it does not interfere with folding an adjacent GPR load to TAX.

Validation: MOS CodeGen suite 79 pass, 1 unsupported (Linux, assertions enabled).
