
.macro print_str(%label)
la $a0, %label
li $v0, 4
syscall
.end_macro

.macro print_int(%reg)
move $a0, %reg
li $v0, 1
syscall
.end_macro

.macro print_char(%reg)
move $a0, %reg
li $v0, 11
syscall
.end_macro

.macro read_int
li $v0, 5
syscall
.end_macro

.macro read_char
li $v0, 12
syscall
.end_macro
