.global _start

GoLBoard:
//  x 0 1 2 3 4 5 6 7 8 9 a b c d e f    y
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 0
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 1
.word 0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0 // 2
.word 0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0 // 3
.word 0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0 // 4
.word 0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0 // 5
.word 0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0 // 6
.word 0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0 // 7
.word 0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0 // 8
.word 0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0 // 9
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // a
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // b

GoLBoard_Neighbor_Count:
//  x 0 1 2 3 4 5 6 7 8 9 a b c d e f    y
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 0
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 1
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 2
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 3
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 4
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 5
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 6
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 7
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 8
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // 9
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // a
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 // b

keyboard_value: .word 0

//--------------------------------------------------------------Libraries----------------------------------------------------------------

//VGA Driver - Place a pixel in a location 
//pre -- A1: x coordinate of pixel [0,319]
//		 A2: y coordinate of pixel [0,239]
//		 A3: colour of the pixel (16 bits) red[15-11] green[10-5] blue[4-0]
.equ pixel_buffer_addr, 0xc8000000
VGA_draw_point_ASM:
	push {A1, A2, A3, A4, LR}
	
//Validating the input 
	//if (x < 0) -> exit
	CMP A1, #0 
	BLT exit_vga_draw_point
	
	//if (x > 319) -> exit 
	LDR A4, =319
	CMP A1, A4
	BGT exit_vga_draw_point
	
	//if (y < 0) -> exit
	CMP A2, #0
	BLT exit_vga_draw_point
	
	//if (y > 239) -> exit
	CMP A2, #239
	BGT exit_vga_draw_point
	
//Obtaining the correct address offset using X and Y 
	LDR A4, =pixel_buffer_addr
	
	LSL A1, #1  // x << 1
	LSL A2, #10 // y << 21 (to accomodate for the bits used by x) 
	
	ADD A4, A4, A1 //(addr) + x 
	ADD A4, A4, A2 //(add + x) + y 

//Storing the pixel value (short) into memory 
	STRH A3, [A4]

	exit_vga_draw_point:
		pop {A1, A2, A3, A4, LR}
		BX LR

//VGA Driver - clear the VGA screen
//NOTE: The colour was changed from 0000 to a light grey! 
VGA_clear_pixelbuff_ASM:
	
	push {R0-R6, LR}
	//A1, A2 and A3 are reserved for draw_point 
	
	//A2 is the index for outerloop
	//A1 is the index for innerloop
	mov A1, #0 
	mov A2, #0
	
	LDR A3, =0xD69A //to replace pixels 
	LDR V2, =320 //Used to compare and know when to exit loop
	LDR V3, =240
	//-------------------Outerloop: Iterating over each column---------------------------------
	clear_pixel_iterating_over_col: 
		
		MOV A1, #0 //Resetting the index of the innerloop
		
		//-------------------------Innerloop: Iterating over the rows--------------------------
		clear_pixel_iterating_over_row:

			BL VGA_draw_point_ASM

			ADD A1, A1, #1 //incrementing the index of the innerloop by 1 
			CMP A1, V2 
			BLT clear_pixel_iterating_over_row //Loop while index is < 320
		//-------------------------------------------------------------------------------------
		
		ADD A2, A2, #1 //incrementing the index of the outerloop by 1 
		CMP A2, V3
		BLT clear_pixel_iterating_over_col
	//-----------------------------------------------------------------------------------------
	
	pop {R0-R6, LR}
	BX LR

// PS/2 Driver - Obtains the value of the data register of keyboard 
//pre --A1: address in memory where we want to store the value 
//post -A1: 0 if no data was obtained, 1 if data was obtained 
.equ PS2_DATA_ADDR, 0xFF200100
read_PS2_data_ASM: 
	push {A2, A3, A4, LR} 
	
	//-------------Obtaining and asserting the RVALID bit--------------
	LDR A2, =PS2_DATA_ADDR //getting address 
	LDR A4, [A2]
	LSR A4, #15 //shifting by 15 to have RVALID as the LSB
	TST A4, #0x1 //RVALID AND 0x01
	
	BNE keyboard_pressed //data register contains keyboard data
	BEQ keyboard_idle //data register doesn't contain keyboard data
	
	//---------------Case where data from keyboard is waiting---------------
	keyboard_pressed: 
	LDR A2, =PS2_DATA_ADDR //getting address 
	LDR A4, [A2]
	
	BFC A4, #8, #24  //gets the rightmost 8 bits (contains Data from keyboard)
	STRB A4, [A1] //storing data at address of argument (might need STRB) 
	
	mov A1, #1
	b exit_read_ps2
	
	//--------------Case where no data from keyboard is waiting-----------------
	keyboard_idle: 
	mov A1, #0
	
	//--------------------Exiting subroutine---------------------------
	exit_read_ps2: 
	POP {A2, A3, A4, LR}
	BX LR

//------------------------------------------------------------------------------GoL Drivers-----------------------------------------------------------------------------------

//VGA Driver - Draw a line on the screen 
//pre -- A1: x1 coordinate of pixel [0,319]
//		 A2: y1 coordinate of pixel [0,239]
//		 A3: x2 coordinate of pixel [0,319]
//		 A4: y2 coordinate of pixel [0,239]
//		 V1: colour of the line (16 bits) red[15-11]green[10-5] blue[4-0] (from stack) 
VGA_draw_line_ASM: 
	push {R0-R4, LR}
	
	//if x1 and x2 are equal, then it's a vertical line, otherwise it's horizontal! 
	CMP A1, A3
	BNE draw_horizontal_line_setup
	
	//--------------Iterating Y1 -> Y2 (VERTICAL) and colouring lines------------------------------
	mov A3, V1 //Colour Decision
	draw_vertical_line:

	BL VGA_draw_point_ASM
	
	ADD A2, A2, #1 //Incrementing y1
	
	CMP A2, A4 //checking if y1 > y2 (stop in this case)
	BLE draw_vertical_line
	b exit_vga_draw_line
	
	//--------------Iterating X1 -> X2 (HORIZONTAL) and colouring lines----------------------------
	draw_horizontal_line_setup: 
	
	mov A4, A3 // A4 = A3 
	mov A3, V1 //Colour Decision
	draw_horizontal_line:

	BL VGA_draw_point_ASM
	
	ADD A1, A1, #1 //Incrementing x1
	
	CMP A1, A4 //checking if x1 > x2 (stop in this case)
	BLE draw_horizontal_line

	//---------------------Exiting subroutine-----------------------------
	exit_vga_draw_line:
	
	pop {R0-R4, LR}
	
	BX LR

//GoL driver - Draw the grid for the game 
GoL_draw_grid_ASM: 
	push {A1, A2, A3, A4, LR}
	
	BL VGA_clear_pixelbuff_ASM //Clearing the board 

	//-----------------------Drawing Horizontal Lines------------------------
	mov A1, #0 //x1 
	mov A2, #0 //y1
	LDR A3, =319 //x2
	mov A4, #0 //y2
	mov V1, #0 //Black colour 
	placing_horizontal_lines: 
	
		BL VGA_draw_line_ASM
		
		ADD A2, A2, #20
		ADD A4, A4, #20
		
		//Checking if the limit has been reached 
		CMP A2, #240
		BLT placing_horizontal_lines
		
		//Removing a pixel for the last row to compensate (h=18, w=19)
		SUB A2, A2, #1
		SUB A4, A4, #1
		BL VGA_draw_line_ASM
		

	//-----------------------Drawing Vertical Lines------------------------
	mov A1, #0 //x1 
	mov A2, #0 //y1
	mov A3, #0 //x2
	mov A4, #239 //y2
	placing_vertical_lines: 
	
		BL VGA_draw_line_ASM
		
		ADD A1, A1, #20
		ADD A3, A3, #20
		
		//Checking if the limit has been reached 
		CMP A3, #320
		BLT placing_vertical_lines
		
		//Removing a pixel for the last column to compensate (h=19, w=18)
		SUB A1, A1, #1
		SUB A3, A3, #1
		BL VGA_draw_line_ASM
	
	//--------------------Exiting Subroutine---------------------------
	pop {A1, A2, A3, A4, LR}
	BX LR 
	
//VGA Driver - Draw a rectangle on the screen 
//Note: This assumes that (X1,Y1) are the top left coordinates and (X2,Y2) are the bottom right coordinates of the rectangle
//pre -- A1: x1 coordinate of pixel [0,319]
//		 A2: y1 coordinate of pixel [0,239]
//		 A3: x2 coordinate of pixel [0,319]
//		 A4: y2 coordinate of pixel [0,239]
//		 V1: colour of the line (16 bits) red[15-11]green[10-5] blue[4-0] (from stack) 
VGA_draw_rect_ASM: 
	push {R0-R5, LR}
	
	//---------------------------Storing variables to deal with input-----------------------
	MOV V2, A4 //storing y2 in V2 
	MOV A4, A2 //Copying y1 into y2
	//need to pass colour C but idk how (stored in V1) 
	
	//---------------------------Itrating from y1 -> y2 to colour square-----------------------
	draw_rect:
	
	BL VGA_draw_line_ASM
	
	//incrementing both y values 
	ADD A2, A2, #1 
	ADD A4, A4, #1 
	
	//Checking for end 
	CMP A2, V2
	BLE draw_rect //Looping back
	
	//----------------------------------Exiting Subroutine---------------------------------------
	pop {R0-R5, LR}
	BX LR
	
//GoL driver - Fill in a specific square on the grid 
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12) 
//		 A3: Colour C red[15-11]green[10-5] blue[4-0]
GoL_fill_gridxy_ASM: 
	
	push {R0-R5, LR}
	
	MOV V1, A3 //moving the colour to V1 (for future subroutines)
	MOV V2, #20

	CMP A1, #15
	BEQ special_right_column
	
	//normal column
	MUL A1, A1, V2
	ADD A3, A1, #19
	ADD A1, A1, #1
	b test_row_case
	
	//Case where the square is 1 less pixel on the right side
	special_right_column:
	MUL A1, A1, V2
	ADD A3, A1, #18
	ADD A1, A1, #1
	
	test_row_case: 
	CMP A2, #11
	BEQ special_bottom_row
	
	//normal row 
	MUL A2, A2, V2
	ADD A4, A2, #19
	ADD A2, A2, #1
	b exit_fill_gridxy
	
	//Case where the square is 1 less pixel on the bottom side
	special_bottom_row:
	MUL A2, A2, V2
	ADD A4, A2, #18
	ADD A2, A2, #1

	exit_fill_gridxy: 
	BL VGA_draw_rect_ASM

	pop {R0-R5, LR}
	
	BX LR 
	
//GoL driver - Fills the grid according to the starting board 
GoL_draw_board_ASM: 
	push {R0-R4, LR}
	
	LDR V1, =GoLBoard //loading address from memory 
	mov A2, #0 //Holds the index of y 
	mov A3, #0 //Colour Black for the boxes
	
	//-----------------------Nested loop iterating over the board------------------------
	draw_board_outerloop:
		mov A1, #0 //Holds the index of x 
	
		draw_board_innerloop: 
			
			LDR A4, [V1], #4 //Loading value at current address 
			
			//Checking if the current value is a 1 (skipping gridxy subroutine if it's not)
			CMP A4, #1
			BNE increment_draw_board
			
			//Drawing the box at (x,y)
			BL GoL_fill_gridxy_ASM
			
			increment_draw_board:
			ADD A1, A1, #1 //Incrementing the x index (x++)	
			CMP A1, #15 //Checking if x has reached its max (needs to be reset)
			BLE draw_board_innerloop
			
			ADD A2, A2, #1 //Incrementing the y index (y++)
			CMP A2, #11 //Checking i y has reached its max (exit loop)
			BLE draw_board_outerloop
	
	pop {R0-R4, LR}
	BX LR
	
//---------------------------------------------------------------------------------GAME LOGIC DRIVERS-----------------------------------------------------------------------------------------

//GoL driver - Updating board cell for cursor based on the cell's state ('1' or '0')
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12) 
GoL_moving_cursor_ASM: 
	
	push {A1, A2, A3, A4, LR}
	
	push {A1}
	
	BL GoL_Identify_Board_Status
	MOV A4, A1 
	
	pop {A1}
	
	CMP A4, #1 
	BEQ dark_square_case
	
	LDR A3, =0x342F
	b skip_dark_case
	
	dark_square_case:
	LDR A3, =0x2A11
	
	skip_dark_case:
	BL GoL_fill_gridxy_ASM
	
	pop {A1, A2, A3, A4, LR}
	
	BX LR 

//GoL driver - Removing the cursor from the board and putting the correct colour on the cell (black or grey)
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12) 
GoL_fix_board_square:

	push {A1, A3, A4, LR}
	
	push {A1}
	
	BL GoL_Identify_Board_Status
	MOV A4, A1 
	
	pop {A1}
	
	CMP A4, #1 
	BEQ board_fix_dark_square_case
	
	LDR A3, =0xD69A //to replace pixels 
	b board_fix_skip_dark_case
	
	board_fix_dark_square_case:
	mov A3, #0 
	
	board_fix_skip_dark_case:
	BL GoL_fill_gridxy_ASM
	
	pop {A1, A3, A4, LR}
	
	BX LR 
	
//GoL driver - Determining if the current location on the board is '1' or '0'
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
//post - A1: 1 if the board is 1, 0 if the board is 0
GoL_Identify_Board_Status:

	push {R1-R5, LR}
	
	//Verifying if the board is 1 or 0 at that location 
	LDR V2, =GoLBoard //loading address from memory //update V1 as a result! 
	mov A3, #0
	MOV A4, #15
	MOV V1, #4

	MUL A3, A2, A4 //offset = 15 * y 
	ADD A3, A3, A1 //offset = (15 * y) + x
	ADD A3, A3, A2 //offset = (15 * y) + x + y 
	MUL A3, A3, V1 //offset = [(15 * y) + x + y] * 4 (word!) 
	
	ADD V2, V2, A3 //Getting the correct address 
	
	LDR A1, [V2] //1 or 0 based on board 
	
	pop {R1-R5, LR}

	BX LR
	
//GoL driver - Toggling the current location on the board 
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
GoL_Toggle_Board_Location: 
	
	push {R0-R5, LR}
	
	//Verifying if the board is 1 or 0 at that location
	LDR V2, =GoLBoard //loading address from memory //update V1 as a result! 
	mov A3, #0
	MOV A4, #15
	MOV V1, #4

	MUL A3, A2, A4 //offset = 15 * y 
	ADD A3, A3, A1 //offset = (15 * y) + x
	ADD A3, A3, A2 //offset = (15 * y) + x + y 
	MUL A3, A3, V1 //offset = [(15 * y) + x + y] * 4 (word!) 
	
	ADD V2, V2, A3 //Getting the correct address 
	
	LDR A1, [V2] //1 or 0 based on board 
	MOV A3, A1
	
	CMP A3, #1 
	BEQ whiten_board_location
	
	//darken_board_location:
	mov A3, #1 
	STR A3, [V2] //updating board 
	b exit_toggle_subroutine
	
	whiten_board_location: 
	mov A3, #0
	STR A3, [V2] //updating board 
	
	exit_toggle_subroutine: 
	
	pop {R0-R5, LR}
	
	BX LR

//GoL driver - Updates the state of each cell on the board based on their neighbouring cells 
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
GoL_Update_Board_State: 
	
	push {A1, A2, A3, LR}
	
//--------------------------OBTAINING THE SUM OF NEIGHBOURING CELLS FOR EACH CELL------------------------
	
	mov A2, #0 //Y = 0
	
	//------------------------Iterating over Y axis------------------------------
	update_outer_loop_board_state: 
		mov A1, #0 //X = 0 
		
		//------------------------Iterating over X axis-----------------------------------
		update_inner_loop_board_state: 
		
			CMP A2, #0 
			BNE skip_case_y_zero
			
			//If y = 0 -> use special case (BL GoL_Neighbor_Sum_Case_Y_Zero)
			BL GoL_Neighbor_Sum_Case_Y_Zero
			B increment_update_loop 
			
			skip_case_y_zero:
			
			CMP A2, #11
			BNE skip_case_y_eleven
			
			//If y = 11 -> use special case (BL GoL_Neighbor_Sum_Case_Y_Eleven)
			BL GoL_Neighbor_Sum_Case_Y_Eleven
			B increment_update_loop 
			
			skip_case_y_eleven:
			
			CMP A1, #0
			BNE skip_case_x_zero
			
			//If x = 0 -> special case (BL GoL_Neighbor_Sum_Case_X_Zero)
			BL GoL_Neighbor_Sum_Case_X_Zero
			B increment_update_loop 
			
			skip_case_x_zero:
			
			CMP A1, #15
			BNE skip_case_x_fiften
			
			//If x = 15 -> special case (BL GoL_Neighbor_Sum_Case_X_Fifteen)
			BL GoL_Neighbor_Sum_Case_X_Fifteen
			B increment_update_loop 
						
			skip_case_x_fiften:
			//Otherwise we will do this: 
			
			BL GoL_Neighbor_Sum_Normal_Case //updates the mirrored board 
			
			increment_update_loop:

			ADD A1, A1, #1 //X = X + 1 
			CMP A1, #15
			BLE update_inner_loop_board_state
	
		ADD A2, A2, #1 //Y = Y + 1 
		CMP A2, #11
		BLE update_outer_loop_board_state
		
//----------------------UPDATING THE ACTUAL BOARD CELLS BASED ON NEIGHBOURING CELLS--------------------
	mov A2, #0 //Y = 0

	//------------------------Iterating over Y axis------------------------------
	update_outer_loop: 
		mov A1, #0 //X = 0 
		
		//------------------------Iterating over X axis-----------------------------------
		update_inner_loop: 

			BL Gol_Update_Cell_State //updates the mirrored board 
			
			
			//------------------If a cell is '0', set it to light grey-------------------
			push {A1} 
			BL GoL_Identify_Board_Status
			MOV A3, A1
			
			POP {A1} 
			
			CMP A3, #0
			BNE not_removing_black_cell
			
			LDR A3, =0xD69A //to replace pixels 
			BL GoL_fill_gridxy_ASM
			//----------------------------------------------------------------------------
			
			not_removing_black_cell:
			ADD A1, A1, #1 //X = X + 1 
			CMP A1, #15
			BLE update_inner_loop
	
		ADD A2, A2, #1 //Y = Y + 1 
		CMP A2, #11
		BLE update_outer_loop
		
		//Exiting the subroutine
	BL GoL_draw_board_ASM

	pop {A1, A2, A3, LR}
	BX LR 

//GoL driver - Updating the mirror board at (X,Y) with the number of neighbouring active cells [Normal Case]
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
GoL_Neighbor_Sum_Normal_Case:

	push {R0-R8, LR}

	//Verifying if the board is 1 or 0 at that location
	LDR V2, =GoLBoard //loading address from memory 
	mov A3, #0
	MOV A4, #15
	MOV V1, #4

	MUL A3, A2, A4 //offset = 15 * y 
	ADD A3, A3, A1 //offset = (15 * y) + x
	ADD A3, A3, A2 //offset = (15 * y) + x + y 
	MUL A3, A3, V1 //offset = [(15 * y) + x + y] * 4 (word!) 
	
	MOV V5, A3 //Storing offset in V5
	
	ADD A4, V2, A3 //Getting the correct address 
	
	SUB V1, A4, #68 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	SUB V1, A4, #64 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	SUB V1, A4, #60 
	LDR A3, [V1] 
	ADD V3, V3, A3

	SUB V1, A4, #4
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #4 
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #60 
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #64
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #68 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//At this point, A3 holds the total sum of active neighbors for the cell at (X,Y) 
	
	LDR V4, =GoLBoard_Neighbor_Count //loading address from memory 
	STR V3, [V4, V5]! //Storing the sum inside of the mirror board 
	
	exit_normal_case: 
	pop {R0-R8, LR}

	BX LR 


//GoL driver - Updating the mirror board at (X,Y) with the number of neighbouring active cells [Case Y=0]
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
GoL_Neighbor_Sum_Case_Y_Zero:	

	push {R0-R8, LR}

	//Verifying if the board is 1 or 0 at that location
	LDR V2, =GoLBoard //loading address from memory
	mov A3, #0
	MOV A4, #15
	MOV V1, #4

	MUL A3, A2, A4 //offset = 15 * y 
	ADD A3, A3, A1 //offset = (15 * y) + x
	ADD A3, A3, A2 //offset = (15 * y) + x + y 
	MUL A3, A3, V1 //offset = [(15 * y) + x + y] * 4 (word!) 
	
	MOV V5, A3 //Storing offset in V5
	
	ADD A4, V2, A3 //Getting the correct address
	
	//----------------------------Filtering through edge cases----------------------------------
	
	//Common case (South) 
	ADD V1, A4, #64
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//Identifying if we need to skip a case
	CMP A1, #0
	BEQ skipping_case_A
	
	//West
	SUB V1, A4, #4
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//South West
	ADD V1, A4, #60 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//Identifying if we need to skip a case
	CMP A1, #15
	BEQ skipping_case_B
	
	skipping_case_A:
	
	//East
	ADD V1, A4, #4 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//South East
	ADD V1, A4, #68 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	skipping_case_B:
	
	//At this point, A3 holds the total sum of active neighbors for the cell at (X,Y) 
	
	LDR V4, =GoLBoard_Neighbor_Count //loading address from memory 
	STR V3, [V4, V5]! //Storing the sum inside of the mirror board 
	
	pop {R0-R8, LR}
	BX LR 

//GoL driver - Updating the mirror board at (X,Y) with the number of neighbouring active cells [Case Y=11]
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
GoL_Neighbor_Sum_Case_Y_Eleven: 

	push {R0-R8, LR}

	//Verifying if the board is 1 or 0 at that location
	LDR V2, =GoLBoard //loading address from memory 
	mov A3, #0
	MOV A4, #15
	MOV V1, #4

	MUL A3, A2, A4 //offset = 15 * y 
	ADD A3, A3, A1 //offset = (15 * y) + x
	ADD A3, A3, A2 //offset = (15 * y) + x + y 
	MUL A3, A3, V1 //offset = [(15 * y) + x + y] * 4 (word!) 
	
	MOV V5, A3 //Storing offset in V5
	
	ADD A4, V2, A3 //Getting the correct address 
	
	//----------------------------Filtering through edge cases----------------------------------
	
	//Common case (North) 
	SUB V1, A4, #64 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//Identifying if we need to skip a case
	CMP A1, #0
	BEQ skipping_case_A_eleven
	
	//North West
	SUB V1, A4, #68 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//West
	SUB V1, A4, #4
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//Identifying if we need to skip a case
	CMP A1, #15
	BEQ skipping_case_B_eleven
	
	skipping_case_A_eleven:
	
	//North East
	SUB V1, A4, #60 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//East
	ADD V1, A4, #4 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	skipping_case_B_eleven:
	
	//At this point, A3 holds the total sum of active neighbors for the cell at (X,Y) 
	
	LDR V4, =GoLBoard_Neighbor_Count //loading address from memory 
	STR V3, [V4, V5]! //Storing the sum inside of the mirror board 
	
	pop {R0-R8, LR}
	BX LR 

//GoL driver - Updating the mirror board at (X,Y) with the number of neighbouring active cells [Case X=0]
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
GoL_Neighbor_Sum_Case_X_Zero: 
	push {R0-R8, LR}

	//Verifying if the board is 1 or 0 at that location
	LDR V2, =GoLBoard //loading address from memory 
	mov A3, #0
	MOV A4, #15
	MOV V1, #4

	MUL A3, A2, A4 //offset = 15 * y 
	ADD A3, A3, A1 //offset = (15 * y) + x
	ADD A3, A3, A2 //offset = (15 * y) + x + y 
	MUL A3, A3, V1 //offset = [(15 * y) + x + y] * 4 (word!) 
	
	MOV V5, A3 //Storing offset in V5
	
	ADD A4, V2, A3 //Getting the correct address 
	
	SUB V1, A4, #64 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	SUB V1, A4, #60 
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #4 
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #64
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #68 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//At this point, A3 holds the total sum of active neighbors for the cell at (X,Y) 
	
	LDR V4, =GoLBoard_Neighbor_Count //loading address from memory 
	STR V3, [V4, V5]! //Storing the sum inside of the mirror board 
	
	pop {R0-R8, LR}
	BX LR 
	
//GoL driver - Updating the mirror board at (X,Y) with the number of neighbouring active cells [Case X=15]
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
GoL_Neighbor_Sum_Case_X_Fifteen: 
	push {R0-R8, LR}

	//Verifying if the board is 1 or 0 at that location
	LDR V2, =GoLBoard //loading address from memory 
	mov A3, #0
	MOV A4, #15
	MOV V1, #4

	MUL A3, A2, A4 //offset = 15 * y 
	ADD A3, A3, A1 //offset = (15 * y) + x
	ADD A3, A3, A2 //offset = (15 * y) + x + y 
	MUL A3, A3, V1 //offset = [(15 * y) + x + y] * 4 (word!) 
	
	MOV V5, A3 //Storing offset in V5
	
	ADD A4, V2, A3 //Getting the correct address 
	
	SUB V1, A4, #64 
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	SUB V1, A4, #68 
	LDR A3, [V1] 
	ADD V3, V3, A3

	SUB V1, A4, #4 
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #60
	LDR A3, [V1] 
	ADD V3, V3, A3

	ADD V1, A4, #64
	LDR A3, [V1] 
	ADD V3, V3, A3
	
	//At this point, A3 holds the total sum of active neighbors for the cell at (X,Y) 
	
	LDR V4, =GoLBoard_Neighbor_Count //loading address from memory 
	STR V3, [V4, V5]! //Storing the sum inside of the mirror board 
	
	pop {R0-R8, LR}
	BX LR 

//GoL driver - Updating the actual board with using the number of neighbouring cells 
//pre -- A1: X coordinate (0 <= x < 16) 
//		 A2: Y coordinate (0 <= y < 12)
Gol_Update_Cell_State: 

	push {R0-R8, LR}

	//Verifying if the board is 1 or 0 at that location
	LDR V2, =GoLBoard //loading address from memory //update V1 as a result! 
	mov A3, #0
	MOV A4, #15
	MOV V1, #4

	MUL A3, A2, A4 //offset = 15 * y 
	ADD A3, A3, A1 //offset = (15 * y) + x
	ADD A3, A3, A2 //offset = (15 * y) + x + y 
	MUL A3, A3, V1 //offset = [(15 * y) + x + y] * 4 (word!) 

	ADD A4, V2, A3 //Getting the correct address 

	LDR V4, [A4] //Obtaining the status of (X,Y)
	
	LDR V5, =GoLBoard_Neighbor_Count //loading address from memory 
	LDR V3, [V5, A3]! //Obtaining the number of neighbors of current cell
	
	CMP V4, #1 //Cell is active
	BEQ checking_active_cell_cases
	
	//Any inactive cell with exactly 3 active neighbors becomes active 
	CMP V3, #3
	BNE exit_update_board_subroutine

	//------------------Updating the actual GoL board (activating the previously inactive cell)------------------
	mov V3, #1 
	STR V3, [A4] //Storing '1' (activating) the current cell on the GoL board 
	B exit_update_board_subroutine
	
	checking_active_cell_cases: 
	//Any active cell with 0 or 1 active neighbors becomes inactive 
	CMP V3, #1 
	BLE deactivate_cell_normal_case
	//Any active cell with 4 or more active neihbors becomes inactive
	CMP V3, #4 
	BGE deactivate_cell_normal_case
	//Any active cell with 2 or 3 active neighbors remains active 
	B exit_update_board_subroutine
	
	deactivate_cell_normal_case: 
	mov A3, #0 
	STR A3, [A4] //Updating the status of (X,Y)

	exit_update_board_subroutine:
	pop {R0-R8, LR}

	BX LR 


//------------------------------------------------------------------------------Game Execution------------------------------------------------------------------------

_start:
	
	/*
	A3: 
	A4: 
	V1: 
	-----
	V2: 
	V3: 
	V5: Address where the value of the keyboard is stored 
	V6: Boolean for finding a break char (F0)
	V7: The X coordinate of the cursor
	V8: The Y coordinate of the cursor
	*/

	//------------------Initializing the board and the cells---------------------
	BL GoL_draw_grid_ASM
	BL GoL_draw_board_ASM
	
	//-------------Placing the cursor to the (0,0) cell on the board-------------
	mov A1, #0 
	mov A2, #0
	BL GoL_moving_cursor_ASM
	MOV V7, #0 
	MOV V8, #0

	//---------------Misc-------------------
	LDR V5, =keyboard_value //Obtaining the address where we want to store the keyboard value later
	mov V6, #0 //Break = false (this deals with the double movement)

	//----------------Polling over the keyboard for input----------------------
	polling: 
		
		//----------------identifying if keyboard was pressed-----------------------
		mov A1, V5 //placing address of keyboard value into A1 
		BL read_PS2_data_ASM //Reading data from keyboard
		CMP A1, #1 
		BEQ determine_key_pressed //Managing keyboard input if there's something 
		B polling //Looping backwards if no data was found
		
		//-----------------------Determines which key was pressed------------------------------
		determine_key_pressed: 
		
		//------------Case 1: Second break character incoming---------------
		CMP V6, #1
		BEQ exit_break
		LDR A1, [V5] //Getting data from keyboard (no break incoming)
		
		//------------Case 2: Break character found (F0)--------------------
		LDR A2, =0xF0
		CMP A1, A2
		BEQ break_found
		
		//------------Case 3: Checking if the key was 'W'--------------------
		LDR A2, =0x1D
		CMP A1, A2
		BEQ move_cursor_up

		//------------Case 4: Checking if the key was 'A'------------------
		LDR A2, =0x1C
		CMP A1, A2
		BEQ move_cursor_left
		
		//------------Case 5: Checking if the key was 'S'------------------
		LDR A2, =0x1B
		CMP A1, A2
		BEQ move_cursor_down
		
		//------------Case 5: Checking if the key was 'D'------------------
		LDR A2, =0x23
		CMP A1, A2
		BEQ move_cursor_right
		
		//------------Case 6: Checking if the key was 'SPACE'------------------
		LDR A2, =0x29
		CMP A1, A2
		BEQ toggle_board_square
		
		//------------Case 7: Checking if the key was 'N'------------------
		LDR A2, =0x31
		CMP A1, A2
		BEQ update_board_state_checker

		b polling	
		
	//---------------------------Updating the Cursor Position---------------------------------
	move_cursor_up: 
		CMP V8, #0 //trying to exit the field (go to y = -1) 
		BEQ polling //return to the poll 
		
		mov A1, V7 //moving x into parameter
		mov A2, V8 //moving y into parameter
		BL GoL_fix_board_square
		
		SUB V8, V8, #1 // y-1 
		b move_cursor
		
	move_cursor_left: 
		CMP V7, #0 //trying to exit the field (go to x = -1) 
		BEQ polling //return to the poll 
		
		mov A1, V7 //moving x into parameter
		mov A2, V8 //moving y into parameter
		BL GoL_fix_board_square

		
		SUB V7, V7, #1 // x-1 
		b move_cursor
		
	move_cursor_down: 
		CMP V8, #11 //trying to exit the field (go to y = 12) 
		BEQ polling //return to the poll
		
		mov A1, V7 //moving x into parameter
		mov A2, V8 //moving y into parameter
		BL GoL_fix_board_square

		
		ADD V8, V8, #1 // y+1
		b move_cursor
		
	move_cursor_right: 
		CMP V7, #15 //trying to exit the field (go to x = 16) 
		BEQ polling //return to the poll 
		
		mov A1, V7 //moving x into parameter
		mov A2, V8 //moving y into parameter
		BL GoL_fix_board_square

		
		ADD V7, V7, #1 // x+1
		b move_cursor
	
	//---------------------------Toggling the current position of the cursor---------------------------------
	toggle_board_square: 
	
		mov A1, V7 //moving x into parameter
		mov A2, V8 //moving y into parameter
		BL GoL_Toggle_Board_Location
		bl GoL_moving_cursor_ASM

		b polling 
	
	//---------------------------------Updating the state of the board---------------------------------
	update_board_state_checker:

		//This is implemented to avoid the double state update
		CMP V3, #1 
		BEQ skip_this_update
		
		//Updating the board state
		bl GoL_Update_Board_State
		
		//Placing the keyboard on screen again (the update gets rid of it)
		mov A1, V7 //moving x into parameter
		mov A2, V8 //moving y into parameter
		bl GoL_moving_cursor_ASM
		
		//This is done to prevent the state from being updated twice
		mov V3, #1
		
		b polling 
		
		//Case where an immediate second state update is happening
		skip_this_update:
		mov V3, #0
		
		b polling
		
	//-----------------------Perfoming the cursor movement on screen------------------------
	move_cursor: 
		
		//Updating the cursor location registers and visually moving cursor
		mov A1, V7 //moving x into parameter
		mov A2, V8 //moving y into parameter
		bl GoL_moving_cursor_ASM
		
		b polling
	
	//-----------------------------Setting the break avoiding system---------------------------
	break_found: 
		mov V6, #1 //Break = true
		b polling 
		
	//----------------------------Removing break avoiding system-------------------------------
	exit_break: 
		mov V6, #0 //Break = false
		b polling 

	b _inf
	
_inf: 
	b _inf
	
	
