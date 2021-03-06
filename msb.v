`define WORD [15:0]



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
				//$display("%b,%b,%b,%b",man1,man2,outMan,out);
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
			//$display("%b,%d,%b",in,numZeros,temp);
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
			//$display("%b",temp);
			
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
		$readmemh("recip.vmem",lookup);
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

// test bench module
module test;
	reg `WORD temp1;
	reg `WORD temp2;
	wire `WORD out;
	
	addf MSB(temp1,temp2,out);	
	initial begin
		temp1 <= 'h56b5;
		temp2 <= 'hd735;
		repeat (1) begin
			#5;
			$display("%h",out);
			//$display("%h",{1'b0, out[6:0]});
			//temp = temp * 2;
		end
	end
endmodule