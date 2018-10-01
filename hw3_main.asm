.include "hw3_helpers.asm"

.include "hw3_dict.asm"
.data
state_struct: .space 50
color_mapping: .space 50
default_fg_msg: .asciiz "Please enter the default foreground color 0-15: "
default_bg_msg: .asciiz "Please enter the default background color 0-15: "
highlight_fg_msg: .asciiz "Please enter the highlight foreground color 0-15: "
highlight_bg_msg: .asciiz "Please enter the highlight background color 0-15: "


.globl main
.text
main:
fg_again:
	print_str(default_fg_msg)	# prompts for setting default colors
	# NOTE: You need to press enter after typing the integer
	# 	The value of the integer should be in the valid
	# 	VT100 color range (0 - 15)
	read_int			# read integer input
	bltz $v0, fg_again		# read integer validation
	bgt $v0, 15, fg_again		# read integer validation
	move $s0, $v0 			# store default fg

bg_again:
	print_str(default_bg_msg)
	# NOTE: You need to press enter after typing the integer
	# 	The value of the integer should be in the valid
	# 	VT100 color range (0 - 15)
	read_int
	bltz $v0, bg_again		# read integer validation
	bgt $v0, 15, bg_again		# read integer validation
	sll $v0, $v0, 4
	add $s0, $s0, $v0		# store default bg

	# set the default color
	la $a0, state_struct			# state struct
	move $a1, $s0				# fg/bg byte
	move $a2, $0				# category
	li $a3, 0				# mode
	jal set_state_color

h_fg_again:
	print_str(highlight_fg_msg)	# prompts for setting highlight colors
	# NOTE: You need to press enter after typing the integer
	# 	The value of the integer should be in the valid
	# 	VT100 color range (0 - 15)
	read_int			# read integer input
	bltz $v0, h_fg_again		# read integer validation
	bgt $v0, 15, h_fg_again		# read integer validation
	move $s0, $v0 			# store default fg

h_bg_again:
	print_str(highlight_bg_msg)
	# NOTE: You need to press enter after typing the integer
	# 	The value of the integer should be in the valid
	# 	VT100 color range (0 - 15)
	read_int
	bltz $v0, h_bg_again		# read integer validation
	bgt $v0, 15, h_bg_again		# read integer validation
	sll $v0, $v0, 4
	add $s0, $s0, $v0		# store default bg

	# set the highlight color
	la $a0, state_struct			# state struct
	move $a1, $s0				# fg/bg byte
	li $a2, 1				# category
	li $a3, 0				# mode
	jal set_state_color

	# set the default colors for the full display
	la $a0, state_struct	# state struct
	move $a1, $0
	jal reset

	# set the cursor to (0,0)
	la $a0, state_struct	# state struct
	li $a1, 0				# first row
	li $a2, 0				# first col
	li $a3, 1				# initial
	jal set_cursor

while_true:
	# read input character
	# NOTE: You DO NOT need to press enter after typing the
	# 	character you which to enter.
	read_char
	move $s0, $v0
	beq $s0, '`', cmd_key
	beq $s0, '\n', nl_key

	# regular character (save on screen using MMIO)
	la $a0, state_struct
	move $a1, $s0	# character to be saved
	jal save_char

	# move cursor to next byte
	la $a0, state_struct
	li $a1, 'l'
	jal move_cursor

	beq $s0, ' ', update_screen
	j while_true
cmd_key:
	# backtick detected, handle command
	la $a0, state_struct
	jal handle_cmd
	beqz $v0, update_screen
	j while_true

nl_key:
	# newline detected, handle newline
	la $a0, state_struct
	jal handle_nl

update_screen:
	la $a0, state_struct			# state struct
	li $a1, 1				# color_only mode
	jal reset				# reset the screen to default colors

	# highlight all the words in the dictionary
	la $t0, state_struct		# state struct
	lbu $a0, 1($t0)			# load highlight color
	la $a1, highlight_dictionary	# mapping dictionary
	jal highlight_all		# update the highlighting

	#set the cursor again
	la $a0, state_struct		# state struct
	lbu $a1, 2($a0)			# first row
	lbu $a2, 3($a0)			# first col
	li $a3, 1			# initial
	jal set_cursor			# set the cursor
	j while_true			# next input

	# This should never be reached (unless it jumps to)
exit:
	li $v0, 10
	syscall

######################################################################
#	Function to handle commands
######################################################################
handle_cmd:
	# save ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	# read next character
	# NOTE: You DO NOT need to press enter after typing the
	# 	character you which to enter.
	li $v0, 12
	syscall
	move $t9, $v0
	beq $t9, 'd', handle_cmd_backspace
	beq $t9, 'F', handle_cmd_def_fg
	beq $t9, 'B', handle_cmd_def_bg
	beq $t9, 'f', handle_cmd_hl_fg
	beq $t9, 'b', handle_cmd_hl_bg
	beq $t9, 'h', handle_cmd_move
	beq $t9, 'j', handle_cmd_move
	beq $t9, 'k', handle_cmd_move
	beq $t9, 'l', handle_cmd_move
	beq $t9, 'q', exit
	j handle_cmd_ret

handle_cmd_move:
	move $a1, $t9
	jal move_cursor
	li $v0, 1		# skip updating screen upon return
	j handle_cmd_ret

handle_cmd_backspace:
	jal handle_backspace
	li $v0, 0		# set return value
	j handle_cmd_ret	# update the screen upon return

handle_cmd_def_bg:
	# read an int
	li $v0, 5
	syscall
	# make sure it's a valid color
	bgtu $v0, 255, handle_cmd_ret
	# $a0 is the state struct
	sll $a1, $v0, 4 # color
	li $a2, 0 		# default color
	li $a3, 2 		# bg only
	jal set_state_color
	li $v0, 0		# set return value
	j handle_cmd_ret

handle_cmd_def_fg:
	# read an int
	li $v0, 5
	syscall
	# make sure it's a valid color
	bgtu $v0, 255, handle_cmd_ret
	# $a0 is the state struct
	move $a1, $v0	# color
	li $a2, 0	# default color
	li $a3, 1	# fg only
	jal set_state_color
	li $v0, 0	# set return value
	j handle_cmd_ret
handle_cmd_hl_bg:
	# read an int
	li $v0, 5
	syscall
	# make sure it's a valid color
	bgtu $v0, 255, handle_cmd_ret
	# $a0 is the state struct
	sll $a1, $v0, 4	# color
	li $a2, 1	# highlight color
	li $a3, 2	# bg only
	jal set_state_color
	li $v0, 0	# set return value
	j handle_cmd_ret
handle_cmd_hl_fg:
	# read an int
	li $v0, 5
	syscall
	# make sure it's a valid color
	bgtu $v0, 255, handle_cmd_ret
	# $a0 is the state struct
	move $a1, $v0	# color
	li $a2, 1	# highlight color
	li $a3, 1	# fg only
	jal set_state_color
	li $v0, 0	# set return value

handle_cmd_ret:
	# restore ra
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

.include "hw3.asm"
