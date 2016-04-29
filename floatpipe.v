//`timescale 10ns/1ns
//DIRECTIVES
`define WORD [15:0]

`define JZ   4'h0
`define ADD  4'h1
`define AND  4'h2
`define ANY  4'h3
`define OR   4'h4
`define SHR  4'h5
`define XOR  4'h6
`define DUP  4'h7
`define LD   4'h8
`define ST   4'h9

`define LI   4'hA
`define ADDF 4'hB
`define F2I  4'hC
`define I2F  4'hD
`define INVF 4'hE
`define MULF 4'hF

//END DIRECTIVES

// multiply floats
module multiplyf( in1,in2,outf);
	output reg `WORD outf;
	input `WORD in1;
	input `WORD in2;
	reg [7:0] temp;
    reg [15:0] temp1;
	
	always @ (*) 
	begin
		// check if either the inputs are zero, if so, the output is zero
		if (in1==16'b0 || in2 == 16'b0) begin
			outf = 16'b0;
		end else begin
			// checks the sign of the inputs and sets the output sign 
			if (in1[15] != in2[15])
			begin
				outf[15] <= 1;    // if 1 in is neg and 1 is pos, the output sign is neg
			end
			else begin
				outf[15] <= 0;		// if the signs are the same, output is positive
			end 	
			
			// add the two exponents and store these 6 bits in temp 
			temp = (in1[14:7] + in2[14:7])- 127;	//subtract  (bias) because adding 2 exponents and result is one exponent
			
			// normalize (add 1 to the front) then
			//multiply the fractions/mantissa of inputs
			temp1 = {1'b1,in1[6:0]} * {1'b1,in2[6:0]};   
			//#5 $display("%h %h", temp,temp1
			
			// check if the multiplied mantissa result (temp1) causes overflow
			if (temp1[15] == 1) begin
				outf[14:7] = temp + 1;	// if overflow, add 1 to the output exponent
				outf[6:0] = temp1[14:8];	// the output mantissa becomes the 7 bits after the overflow
			end else begin
				outf[14:7] = temp;   	// if no overflow, then exponent is the 2 input exponents added together
				outf[6:0] = temp1[13:7];	//output mantissa becomes the 7 bits after the 2 msbits
			end
		end
	end
endmodule


module msb(in,out);
	input `WORD in;
	output reg `WORD out;
	reg `WORD temp;
	always @(*) begin
		temp = in | (in >>1);
		temp = temp | (temp >>2);
		temp = temp | (temp >>4);
		temp = temp | (temp >>8);
		out = temp & ~(temp >>1);
	end
	
endmodule


// float additon - takes in 2 floating point numbers, adds them and outputs the floating point result
module addf(in1,in2,out);
	input `WORD in1;
	input `WORD in2;
	output reg `WORD out;
	
	reg `WORD temp;
	reg `WORD op1;
	reg `WORD op2;
	
	reg[8:0] man1;
	reg[8:0] man2;
	reg[8:0] outMan;
	wire `WORD numZeros;

	lead_zero leadZeros({outMan,7'b0}, numZeros);
	
	always@(*) begin
		// in input 1 is 0, then the output is the input 2
		if (in1 == 16'b0) begin
			out = in2;

		// if input 2 is 0, the the output is the input 1
		end else if (in2 == 16'b0) begin
			out = in1;
		// floating points are opposite (i.e: -2 and 2) if all bits the same except the sign bit.
		// check for this case, if true, the output is 0 
		end else if ((in1[14:0] == in2[14:0]) && (in1[15] != in2[15])) begin
			out = 0;
			
		// general addition case
		end else begin
			// denormailize the exponents so they are the same
			
			// always make op1 the larger exponent
			// if input 2 exponent is larger than input 1 exponent, then make in2 become op1 and in2 become op2
			if (in2[14:7] > in1[14:7] ) begin
				op2 = in1;
				op1 = in2;
			end else begin	//otherwise, op1 is in1 and op2 is in2
				op2 = in2;
				op1 = in1;
			end
			
			//normalize the mantissa (add a 1 in front) then add and subtract fractional/mantissa parts
			man1 = {2'b01,op1[6:0]};
			man2 = {2'b01,op2[6:0]};
		
			//denormalize smaller value (man2) for addition
			man2 = man2 >> (op1[14:7] - op2[14:7]);
		
			// the output exponent becomes the 
			out[14:7] = (op1[14:7]);
			
			// check the signs of the inputs
			//if the signs are the same, add the 2 input mantissas
			if (op1[15] == op2[15]) begin
				outMan = man1+man2;
				//$display("%b,%b,%b,%b",man1,man2,outMan,out);
				
				// if signs are the same, the output sign will also be the same as in1/in2 sign
				out[15] = op1[15];
				
				if (outMan[8] == 1) //CHECK FOR OVERFLOW
				begin
					// if overflow, add 1 to the output exponent 
					out[14:7] = out[14:7]+1; 
					//the output mantissa becomes the 7 bits after the overflow
					out[6:0] = outMan[7:1];
				end else begin
					out[6:0] = outMan[6:0];	// if no overflow, the output mantissa remains as the bottom bits of the input mantissas added together
				end
			// if the signs of the inputs are opposite, subtract the smaller input mantissa from the larger one
			end else begin
				// 
				if (man1 > man2) begin
					outMan = man1-man2;
					out[15] = op1[15];
				end else begin
					outMan = man2-man1;
					out[15] = op2[15];
				end
				if (numZeros == 2) begin  //////////////???????????
					out[14:7] = out[14:7] + (1-numZeros);
					out[6:0] = {outMan[5:0], 1'b0};
				end else begin
					out[14:7] = out[14:7] ;
					out[6:0] = {outMan[6:0]};
				end
			end
		end	
	end
endmodule

// integer to floating point conversion
// input: a 16-bit binary integer
// output: the 16-bit floating point representation
module i2f(in,out);
	input `WORD in;
	output reg `WORD out;
	reg[6:0] zeros;
	reg [22:0] temp;
	wire `WORD numZeros;
	wire `WORD countZ;
	assign countZ = temp[22:7];
	lead_zero leadZeros(countZ, numZeros);
	
	initial begin
		zeros<= 0;
	end
	always@(*) begin
		// if the input binary number is 0, the output float is 0
		if (in == 16'b0) begin
			out = 16'b0;
		end else begin
			// check the sign of the fp input
			// if it is positive 
			if (in[15] ==0) begin
				temp = {in,zeros};
				out[15] = in[15]; //set sign bit
				out[14:7] = 127 + (15-numZeros); //set exponent
				out[6:0] = temp >> (15-numZeros); //set mantissa
			// if the input is negative
			end else begin
				// flip the bits and add 1, then perform the same operations as you did on the positive input
				temp = {((in^16'b1111111111111111)+16'b01),zeros};
				out[15] = in[15]; //set sign bit
				out[14:7] = 127 + (15-numZeros); //set exponent
				out[6:0] = temp >> (15-numZeros); //set mantissa
			end
		end
	end
endmodule


// Dietz's lead_zeros module
// takes the 16 bit input and outputs the number of 0s in the most significant bits 
module lead_zero(in, out);

	input `WORD in;
	output reg `WORD out;
	
	reg `WORD temp;
	wire `WORD vari;
	
	ones Count(temp,vari);
	
	always @(*) begin 
		temp = in | (in>>1);
			temp = temp | (temp>>2);
			temp = temp | (temp>>4);
			temp = temp | (temp>>8);
			out = 16-vari;
	end
endmodule


 // needed for the leading zeros 
module ones(in,out);
	input `WORD in;
	output reg `WORD out;
	reg `WORD temp;
	
	always @(*) begin
		temp = in - ((in >>1)& 16'h5555);
		temp = (((temp >>2) & 16'h3333) + (temp & 16'h3333));
		temp = (((temp >>4)+temp)& 16'h0f0f);
		temp = temp + (temp>>8);
		temp = temp + (temp>>16);
		out = temp & 16'h003f;
	end
endmodule


// floating point to integer converion 
// input: 16-bit floating point 
// output: 16-bit integer representation of the input
module f2i(in,out);
	input `WORD in;
	output reg `WORD out;
	reg [22:0] temp;
	
	always @(*) begin
		// check if the input is 0, if so, the output is also 0
		if (in == 16'b0) begin
			out = 16'b0;
		end else begin
			//normalize the mantissa (add 1 to front)
			temp = {16'b1,in[6:0]};
			$display("F2I: %h",in);
			
			// if the exponent is larger than the bias (127) shift the mantissa the difference
			if (in[14:7] >= 127) begin
				temp = temp << (in[14:7] - 127);
				out = temp[22:7];
				
			// otherwise the output is 0
			end else begin 
				out = 0;
			end
			// if the input is negative, flip the bits of the output and add 1
			if (in[15] == 1) begin
				out = out ^ 'hffff;
				out = out+1;
			end
		end
	end	
endmodule

// reciprocal floating point module
// input: 16-bit floating point 
// output: the 16 bit reciprocal of the input (1/input)
module recip_float(in, out);
	input `WORD in;
	output reg `WORD out;
	reg [7:0] temp;
	reg  [7:0] lookup[0:127]; //[x:y] used as bus width goes before the name, after the name means its an array
	//Also swapped order from 127:0 to 0:127 to get rid of compiler warning
	
	//Initial blocks run once at the very beginning of simulation
	//They are good for initializing variables and constants (like LUTs)
	//The best way to initialize memory is to use the readmemh(...) function, its also less lines
	initial begin
		
               $readmemh1(lookup);
	end

	always @(*) begin
	//This LUT in the always block has every value assigned for every time IN changes. 
	//We do not need to reset the LUT every time, so it should be moved to an initial block
		// set the sign bit of output eqaul to the input sign bit
		out[15] = in[15];	
		//negate the exponent 
		// if the mantissa is all 0s, 
		if (in[6:0] == 7'b0) begin
			out[14:7] = 254 - (in[14:7]);
		end else begin
			out[14:7] = 253 - (in[14:7]);
		end	
		// input mantissa in binary and we want in decimal
		if (in[6:0] == 1) begin  // this is where we fooked up and put the 1 equivalent mantissa at the end of the list
			out[6:0] = lookup[126];
		end else begin
			//
			//temp[7:0] = lookup[in[6:0]-1]; //needed to be -, not + //because of the previous fuck up all of the lookups are off by 1
			// the lookup result is 8 bits while the mantissa is only 7 so its either top 7 bits or bottom 7 bits
			temp[7:0] = lookup[in[6:0]]; //This is for the readmemh
			out[6:0] = temp[6:0]; //bottom 7 bits, not top 7
		end
	end// end of always block
endmodule

module ALU(opr1,opr2,out1,op,cc);
	input `WORD opr1;
	input `WORD opr2;
	output reg `WORD out1;
	input [3:0] op;
	output reg `WORD cc;
	
	initial begin
		out1 <= 16'b0;
		cc <= 16'b0;
	end
	
	wire `WORD outFloat;
	wire `WORD outInt;
	wire `WORD outAdd;
	wire `WORD outMul;
	wire `WORD outRecip;
	
	i2f toFloat(opr1,outFloat);
	f2i toInt(opr1,outInt);
	addf addition(opr1,opr2,outAdd);
	multiplyf multiply(opr1,opr2,outMul);
	recip_float recip(opr2,outRecip);
	
	always @(*)
	begin
		case (op)
			`ADD: begin
				out1 <= opr1 + opr2;
			end
			`AND: begin
				out1 <= opr1 & opr2;
			end
			`ANY: begin
				out1 <= (opr1 == 16'b0 ? 16'b000000:16'b000001);
			end
			`OR: begin
				out1 <= opr1 | opr2;
			end	
			`SHR: begin
				out1 <= opr1 >> 1;
				out1[15] <= opr1[15];
			end
			`XOR: begin
				out1 <= opr1 ^ opr2;
			end
			`DUP: begin
				out1<= opr1;
			end
			`ADDF: begin
				out1 <= outAdd;
			end
			`I2F: begin
				out1 <= outFloat;
			end
			`F2I: begin
				out1 <= outInt;
			end
			`MULF: begin
				out1 <= outMul;
			end
			`INVF: begin
				out1 <= outRecip;
			end
			default: begin
				out1 <= opr1;
			end
		endcase
	end
	
	always @(out1)
	begin
		if (out1 == 16'b0 && op <7 && op>0)
		begin
			cc[0] <= 1'b1;
		end else if (op <7 && op>0) begin
			cc[0] <= 1'b0;
		end else begin
			cc <= cc;
		end
	end
endmodule




module processor(clk,halt);
	input clk;
	output reg halt;
	reg `WORD pc;
	reg `WORD ram[0:65535];
	//reg `WORD instruction;
	reg `WORD stage1[0:5];
	reg `WORD stage2[0:5];
	reg `WORD stage3[0:5];
	reg `WORD op1;
	reg `WORD op2;
	reg `WORD newPC;
	reg stop1;
	reg stop2;
	reg pcFlag;
	reg [3:0] operation;
	
	//reg regFileIn,regFileOut;
	reg `WORD registers[0:63];
	reg holdUp;
	wire `WORD toStage3;
	wire `WORD cc;
	reg `WORD i;
	reg squashNext2,squashNext1;
	ALU alu(op2,op1,toStage3,operation,cc);
		
	initial begin
		
                $readmemh0(ram);
		halt<=0;
		holdUp<=0;
		//register file initialization

                $readmemh2(registers);
		pc <= 16'b0;
		squashNext1<=0;
		squashNext2<=0;
		pcFlag<=0;
		newPC<=16'b0;
		stop1<=0;
		stop2<=0;
	end
	
	
	always@(clk) begin
	end
	
	//stage 1 instruction fetch
	always@(posedge clk)
	begin

		if (pcFlag == 1 ) begin
			pc<=newPC;
			pcFlag <=0;
		end
		//instruction <= ram[pc];
	end
	
	always@(negedge clk)
	begin
		if (holdUp == 0)begin
		stop1<=0;
		case (ram[pc][15:12])
			`LI: 
			begin
				pc<=pc+2;
				stage1[4]<=ram[pc+1];
			end
			default: pc<=pc+1;
		endcase
//		if (ram[pc] == 16'b0)
//		begin
//			halt<=1;
//		end

		//pc<=pc+1;
		stage1[0]<=ram[pc][15:12];
		stage1[1]<=ram[pc][11:6];
		stage1[2]<=ram[pc][5:0];
		stage1[3]<=ram[pc][11:6];
		stage1[5]<=ram[pc];
		end else begin
			stop1<=1;
		end
	end
	
	
	//stage 2 register file games
	always@(posedge clk)
	begin

	end
	
	always@(negedge clk)
	begin
		if (holdUp==0) begin
			stop2<=0;
			stage2[0]<=stage1[0];
			stage2[1]<=registers[stage1[1]];
			stage2[2]<=registers[stage1[2]];
			stage2[3]<=stage1[3];
			stage2[4]<=stage1[4];
			stage2[5]<=stage1[5];
		end else begin
			stop2<=1;
			stage2[0] <= 16'bz;
			stage2[1] <= 16'bz;
			stage2[2] <= 16'bz;
			stage2[3] <= 16'bz;
			stage2[4] <= 16'bz;
			stage2[5] <= 16'bz;
		end		
	end
	
	
	//stage 3 ALU and memory stuff
	always@(posedge clk)
	begin
		op1<=stage2[1];
		op2<=stage2[2];
		operation<=stage2[0][3:0];
	end
	
	always@(negedge clk)
	begin 
		if(operation == `ST) begin
			ram[op2]<=op1;
			stage3[5] <= stage2[5];
		end else if (operation == `LD) begin
			stage3[0]<=stage2[3];
			stage3[1]<=ram[stage2[2]];
			stage3[2]<=stage2[0];
			stage3[4]<=stage2[4];
			stage3[5]<=stage2[5];
		end else begin
			stage3[0]<=stage2[3];
			stage3[1]<=toStage3;
			stage3[2]<=stage2[0];
			stage3[4]<=stage2[4];
			stage3[5]<=stage2[5];
			case(stage2[5][15:12])
				`JZ: begin
					if (stage2[1] == 0) begin
						if (stage2[5][5:0]==6'b0 && stage2[5][11:6]!=6'b0) begin
							if(holdUp==1) begin
							squashNext1<=1;
							end else begin
							squashNext2<=1;
							end
						end else if (stage2[5][5:0]>6'b0)begin
							newPC<=stage2[2];
							squashNext2<=1;
							squashNext1<=1;
							pcFlag <=1;
						end
					end
				end
			endcase
		end
	
	end
	
	always@(squashNext2) begin
		if (squashNext2 == 1)
		begin
			squashNext2 <= 0;
			stage2[0] = 16'bx;
			stage2[1] = 16'bx;
			stage2[2] = 16'bx;
			stage2[3] = 16'bx;
			stage2[4] = 16'bx;
			stage2[5] = 16'bx;
		end
	end
	always@(squashNext1) begin
		if (squashNext1 == 1)
		begin
			squashNext1 <= 0;
			stage1[0] = 16'bx;
			stage1[1] = 16'bx;
			stage1[2] = 16'bx;
			stage1[3] = 16'bx;
			stage1[4] = 16'bx;
			stage1[5] = 16'bx;
		end
	end
	
	//Stage 4 Write back?
	always@(posedge clk)
	begin
		if(stage1[5][11:6]==stage2[5][11:6] || stage1[5][11:6]==stage3[5][11:6] || stage1[5][5:0]==stage2[5][11:6] || stage1[5][5:0]==stage3[5][11:6])
		begin
			holdUp<=1;
		end else begin
			holdUp<=0;
		end
	end
	
	always@(negedge clk)
	begin
		if(stage3[5] == 16'b0) begin
			halt<=1;
		end else begin
		case(stage3[2][3:0])
			`LI: 
			begin
				registers[stage3[0][5:0]]<=stage3[4];
			end
			`JZ: begin
				
			end
			`ST: begin

			end
			default: registers[stage3[0][5:0]]<=stage3[1];
		endcase
		end
	end
	
	always@(halt)
	begin
		if (halt == 1'b1)
		begin
		for (i=0; i<64;i=i+1) begin
						$display("Value of register %d is %h",i-8,registers[i]);
						end
						$finish;
		end
	end

endmodule

module testBench;
	reg clk;
	wire clear;

	processor proc(clk,clear);

	initial 
	begin
		$dumpfile;
		$dumpvars(0,testBench);
		#100 //Wait until ALL memory is initialized
		clk <= 0;
		while (clear != 1)
		begin
			//$display("Clock %b",clk);
			#100;
			clk<=~clk;		
		end
		
	end
	
	
endmodule