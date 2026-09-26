
	.section	.unresolved,"a",@progbits
	.mos_addr_asciz	external+1, 1

	.mos_addr_asciz	external+2, 2

	.mos_addr_asciz	external+3, 3

	.mos_addr_asciz	external+4, 4

	.mos_addr_asciz	external+5, 5

	.mos_addr_asciz	external+6, 6

	.mos_addr_asciz	external+7, 7

	.mos_addr_asciz	external+8, 8


	.section	.resolved,"a",@progbits
	.byte	56
	.asciz	"\000"

	.mos_addr_asciz	later, 2

	.mos_addr_asciz	end-begin, 2

later = 42
	.section	.distance,"a",@progbits
begin:
	.zero	7
end:

