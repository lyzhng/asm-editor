##################################
# Part 1 - String Functions
##################################

is_whitespace:
	######################
	move $t0, $a0
	li $t1, '\n'
	li $t2, ' '
	li $t3, '\0'
	seq $t4, $t0, $t1
	seq $t5, $t0, $t2
	seq $t6, $t0, $t3
	or $t0, $t4, $t5
	or $t1, $t0, $t6
	move $v0, $t1
	######################
	jr $ra

cmp_whitespace:
	######################
	addi $sp, $sp, -12		# begin prologue
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	jal is_whitespace
	move $s0, $v0			# is_whitespace(c1) result
	move $a0, $a1	
	jal is_whitespace
	move $s1, $v0			# is_whitespace(c2) result
	and $t2, $s1, $s0
	move $v0, $t2
	lw $s1, 8($sp)
	lw $s0, 4($sp)
	lw $ra, 0($sp)			# begin epilogue
	addi $sp, $sp, 12
	######################
	jr $ra

strcpy:
	######################
	ble $a0, $a1, copydone		# src addr <= dest addr !?
	li $t1, 0			# loop counter
	copyloop:
		lb $t2, ($a0)		# src[i]
		beq $t1, $a2, copydone	# counter = done
		sb $t2, ($a1)
		addi $t1, $t1, 1
		addi $a0, $a0, 1
		addi $a1, $a1, 1
		j copyloop
	copydone:
	######################
	jr $ra

strlen:
	######################
	addi $sp, $sp, -16
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	move $s0, $a0
	add $s1, $zero, $zero
	lenloop:
		lb $s2, ($s0)
		move $a0, $s2
		jal is_whitespace
		bgtz $v0, lendone	# reached whitespace char / end of str
		addi $s1, $s1, 1
		addi $s0, $s0, 1
		j lenloop
	lendone:
		move $v0, $s1
		lw $s2, 12($sp)
		lw $s1, 8($sp)
		lw $s0, 4($sp)
		lw $ra, 0($sp)
		addi $sp, $sp, 16
	######################
	jr $ra

##################################
# Part 2 - vt100 MMIO Functions
##################################

set_state_color:
	######################
	li $t0, 0
	li $t1, 1
	li $t2, 2
	beq $t0, $a2, category0
	beq $t1, $a2, category1
	category0:
		beq $a3, $t0, cat0_mode0
		beq $a3, $t1, cat0_mode1
		beq $a3, $t2, cat0_mode2
		cat0_mode0:
			sb $a1, 0($a0)
			j statecolordone
		cat0_mode1:
			lb $t3, 0($a0)		# def bg,fg
			andi $t4, $t3, 0xf0	# save default bg
			move $t5, $a1
			andi $t5, $t5, 0x0f	# add default fg of color
			or $t6, $t5, $t4
			sb $t6, 0($a0)
			j statecolordone
		cat0_mode2:
			lb $t3, 0($a0)
			andi $t4, $t3, 0x0f	# save default fg
			move $t5, $a1
			andi $t5, $t5, 0xf0	# add default bg of color
			or $t6, $t5, $t4
			sb $t6, 0($a0)
			j statecolordone
	category1:
		cat1_mode0:
			sb $a1, 1($a0)
			j statecolordone
		cat1_mode1:
			lb $t3, 1($a0)
			andi $t4, $t3, 0xf0
			move $t5, $a1
			andi $t5, $t5, 0x0f
			or $t6, $t5, $t4
			sb $t6, 1($a0)
			j statecolordone
		cat1_mode2:
			lb $t3, 1($a0)
			andi $t4, $t3, 0x0f	# save default bg
			move $t5, $a1
			andi $t5, $t5, 0xf0	# add default fg of color
			or $t6, $t5, $t4
			sb $t6, 1($a0)
	statecolordone:
	######################
	jr $ra

save_char:
	######################
	li $t0, 160
	li $t1, 2
	lb $t2, 2($a0) # x
	lb $t3, 3($a0) # y
	mul $t4, $t2, $t0 # 160x
	mul $t5, $t3, $t1 # 2y
	add $t6, $t5, $t4 # 160x+2y
	addi $t8, $t6, 0xffff0000 # hex address to put char c in
	sb $a1, 0($t8)
	######################
	jr $ra

reset:
	######################
	li $t0, 0xffff0000
	li $t1, 0xffff0fa0
	li $t2, '\0'
	lb $t3, 0($a0) # default colors for fg, bg
	loopthrough:
		bgt $t0, $t1, resetdone
		bnez $a1, color1
		color0: # make the ascii null
			sb $t2, 0($t0)
		color1: # set color to default 
			sb $t3, 1($t0)
		addi $t0, $t0, 2 # go to next cell
		j loopthrough
	######################
	resetdone:
	jr $ra

clear_line:
	######################
	# prologue s0 s
	addi $sp, $sp, -8
	sw $s0, 0($sp)
	sw $s1, 4($sp)
	
	li $t0, 160
	li $t1, 2
	mul $t2, $t0, $a0 # 160x reused
	mul $t3, $t1, $a1 # 2y
	add $t4, $t3, $t2 # 160x+2y
	addi $s0, $t4, 0xffff0000 # starting addr
	li $t0, 79
	mul $t3, $t0, $t1 # 79*2
	add $t5, $t3, $t2 # 79*2 + 160x
	addi $s1, $t5, 0xffff0000 # ending address
	li $t6, '\0'
	clearlineloop:
		bgt $s0, $s1, clearlinedone
		sb $t6, 0($s0)
		sb $a2, 1($s0)
		addi $s0, $s0, 2
		j clearlineloop
	######################
	clearlinedone:
		lw $s1, 4($sp)
		lw $s0, 0($sp)
		addi $sp, $sp, 8
		jr $ra

set_cursor:
	# 160x + 2y
	######################
	# struct a0, x a1, y a2, initial a3
	li $t0, 1
	beqz $a3, clear_cursor  # initial = 0 --> not the first time --> clear first
	j set_new_cursor  # initial = 1 --> first time --> just set new cursor, don't clear
	
	clear_cursor:  # don't clear cursor. just set
		lb $t0, 2($a0) # x
		lb $t1, 3($a0) # y
		li $t2, 160
		li $t3, 2
		mul $t4, $t2, $t0
		mul $t5, $t3, $t1
		add $t5, $t5, $t4 # 160x+2y
		addi $t7, $t5, 0xffff0000 # old hex address
		
		lb $t0, 1($t7) # color byte
		xori $t5, $t0, 0x88
		sb $t5, 1($t7) # save inverted bold bits into color @ old x,y
		
	set_new_cursor:
		sb $a1, 2($a0) # store new x
		sb $a2, 3($a0) # store new y
		
		li $t0, 160
		li $t1, 2
		mul $t2, $t0, $a1
		mul $t3, $t1, $a2
		add $t4, $t3, $t2
		addi $t6, $t4, 0xffff0000 # new hex addr
		
		lb $t0, 1($t6) # color byte
		xori $t5, $t0, 0x88
		sb $t5, 1($t6)

	######################
	jr $ra

move_cursor:
	######################
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	li $t0, 'h'
	li $t1, 'j'
	li $t2, 'k'
	li $t3, 'l'
	lb $t4, 2($a0) # x
	lb $t5, 3($a0) # y
	li $t6, 24 # max x
	li $t7, 79 # max y
	beq $t0, $a1, charh
	beq $t1, $a1, charj
	beq $t2, $a1, chark
	beq $t3, $a1, charl
	j movecursordone # otherwise
	charh: # left
		beqz $t5, y_is_zero
		lb $a1, 2($a0)
		lb $a2, 3($a0)
		addi $a2, $a2, -1 # y-1
		li $a3, 0
		jal set_cursor
		y_is_zero:
		j movecursordone
	charj: # down
		beq $t4, $t6, x_is_max
		lb $a1, 2($a0)
		lb $a2, 3($a0)
		addi $a1, $a1, 1 # x+1
		li $a3, 0
		jal set_cursor
		x_is_max:
		j movecursordone
	chark: # up
		beqz $t4, x_is_zero
		lb $a1, 2($a0)
		lb $a2, 3($a0)
		addi $a1, $a1, -1 # x-1
		li $a3, 0
		jal set_cursor
		x_is_zero:
		j movecursordone
	charl: # right
		beq $t5, $t7, movecursordone # y_is_max
		lb $a1, 2($a0) # x
		lb $a2, 3($a0) # y
		addi $a2, $a2, 1 # y+1
		li $a3, 0
		jal set_cursor
	movecursordone:
	######################
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

mmio_streq:
	######################
	# mmio a0, b a1
	# prologue
	addi $sp, $sp, -20
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	move $s0, $a0
	move $s1, $a1
	li $v0, 1 # assume true
	mmiostrloop:
		lb $t0, ($s0)
		lb $t1, ($s1)
		sub $t2, $t1, $t0
		seq $s2, $t2, $zero # if eq char, s2 <- 1
		# check whitespaces
		move $a0, $t0
		move $a1, $t1
		jal cmp_whitespace
		move $s3, $v0 # both whitespaces result
		bnez $s3, stop_mmiostrloop # if both whitespaces, stop the loop, ret 1
		lb $t5, ($s0)
		move $a0, $t5
		jal is_whitespace # result in v0
		bnez $v0, notequal
		lb $t6, ($s1)
		move $a0, $t6
		jal is_whitespace # result in v0
		bnez $v0, notequal
		# singular cases
		or $t1, $s2, $s3 # same char or both whitespace char
		bnez $t1, continue_mmiostrloop
		move $v0, $t1
		beqz $t1, stop_mmiostrloop
		continue_mmiostrloop:
			addi $s1, $s1, 1
			addi $s0, $s0, 2
		j mmiostrloop
	notequal:
		li $v0, 0
	stop_mmiostrloop:
	######################
	lw $s3, 16($sp)
	lw $s2, 12($sp)
	lw $s1, 8($sp)
	lw $s0, 4($sp)
	lw $ra, 0($sp)
	addi $sp, $sp, 20
	jr $ra

##################################
# Part 3 - UI/UX Functions
##################################

handle_nl:
	######################
	# a0 state
	# prologue
	addi $sp, $sp, -12
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	
	move $s0, $a0 # struct
	# a0 stays a0
	li $a1, '\n'
	jal save_char # void
	
	lb $a0, 2($s0) # x
	lb $a1, 3($s0) # y
	addi $a1, $a1, 1 # y+1
	lb $a2, 0($s0) # def fg,bg
	jal clear_line # void
	
	li $s1, 24 # max x
	lb $t1, 2($s0) # cur x
	beq $s1, $t1, reset_line
	
	# otherwise, not last row
	move $a0, $s0 # struct
	lb $a1, 2($s0)
	li $a2, 0
	addi $a1, $a1, 1 # x+1
	li $a3, 0 # initial
	jal set_cursor
	j handlenldone
	
	reset_line:
	move $a0, $s0
	move $a1, $s1
	li $a2, 0
	li $a3, 0 #
	jal set_cursor # void
	
	handlenldone:
	lw $s1, 8($sp)
	lw $s0, 4($sp)
	lw $ra, 0($sp)
	addi $sp, $sp, 12
	######################
	jr $ra

handle_backspace:
	######################
	# a0 struct
	# prologue
	addi $sp, $sp, -16
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	
	move $s2, $a0
	
	lb $t0, 2($a0) # x
	lb $t1, 3($a0) # y
	li $t2, 160
	mul $t2, $t2, $t0 # 160x | reuse
	sll $t1, $t1, 1 # 2y
	add $t3, $t2, $t1 
	addi $s0, $t3, 0xffff0000 # starting addr
	
	li $t4, 80
	sll $t4, $t4, 1 # 2*80
	add $t4, $t4, $t2 # 160x+2*80
	addi $s1, $t4, 0xffff0000 # ending addr
	
	li $t0, 79
	lb $t1, 3($a0) # y
	sub $t2, $t0, $t1 # 79-y = n
	addi $t3, $s0, 2 # hex addr (x,y+1)
	move $a0, $t3 # src
	move $a1, $s0 # dst
	sll $t2, $t2, 1
	move $a2, $t2 # n
	jal strcpy # void
	
	# $s1 is addr (x,79) | ending addr
	lb $t0, 0($s2) # def bg/fg
	sb $zero, 0($s1)
	sb $t0, 1($s1)
	
	# epilogue
	lw $s2, 12($sp)
	lw $s1, 8($sp)
	lw $s0, 4($sp)
	lw $ra, 0($sp)
	addi $sp, $sp, 16
	######################
	jr $ra

highlight:
	# a0 x, a1 y, a2 col, a3 n
	######################
	li $t0, 80
	mul $t1, $t0, $a0
	add $t2, $t1, $a1
	sll $t2, $t2, 1 # 2(80x+y)
	addi $t2, $t2, 0xffff0000 # addr
	li $t0, 0 # counter
	highlightloop:
		beq $a3, $t0, highlightdone
		sb $a2, 1($t2)
		addi $t0, $t0, 1
		addi $t2, $t2, 2 # go to next mmio cell's color
		j highlightloop
	highlightdone:
	######################
	jr $ra

highlight_all:
	######################
	# prologue
	addi $sp, $sp, -24
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	li $s0, 0xffff0000
	li $s1, 0xffff0fa0
	move $s2, $a0 # color
	move $s3, $a1 # dictionary
	move $s4, $a1
	not_end_of_display:
		bgt $s0, $s1, end_of_display
		is_whitespace_loop:
			beq $s0, $s1, end_of_display
			lb $a0, 0($s0) 
			jal is_whitespace # checks if ascii letter in that cell is whitespace char
			beqz $v0, out_whitespace_loop # not whitespace
			addi $s0, $s0, 2
			j is_whitespace_loop
		out_whitespace_loop: # at this pt, $s0 contains something that is not a whitespace
		move $s3, $s4 # reset dictionary
		loop_through_dict:
			move $a0, $s0 # starting hex addr
			lw $a1, ($s3) # word from dict arr
			beqz $a1, is_not_whitespace_loop
			jal mmio_streq
			beqz $v0, continue_loop_dict # no match
			# match! | highlight
			highlighting_word:
				lw $a0, ($s3)
				jal strlen
				move $a3, $v0
				move $a2, $s2			
				li $t0, 0xffff0000
				sub $t0, $s0, $t0 # subtract base address
				li $t1, 2
				div $t0, $t1 # divide by 2
				mflo $t0
				li $t1, 80
				div $t0, $t1 # divide by 80
				mflo $a0
				mfhi $a1
				jal highlight # void
				j is_not_whitespace_loop
			continue_loop_dict:
				addi $s3, $s3, 4
			j loop_through_dict
		is_not_whitespace_loop:
			beq $s0, $s1, end_of_display
			lb $a0, ($s0)
			jal is_whitespace
			bnez $v0, out_is_not_whitespace
			addi $s0, $s0, 2
			j is_not_whitespace_loop
		out_is_not_whitespace:
		j not_end_of_display
	end_of_display:
	######################
	lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	addi $sp, $sp, 24
	jr $ra
