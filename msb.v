`define WORD [15:0]

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
	
	
	always@(*) begin
	
		if (in2[14:7] > in1[14:7] ) begin
			op2 = in1;
			op1 = in2;
		end else begin
			op2 = in2;
			op1 = in1;
		end
	
		man1 = {2'b1,op1[6:0]};
		man2 = {2'b1,op2[6:0]};
		
		man2 = man2 >> (op1[14:7] - op2[14:7]);
		out[14:7] = (op1[14:7]);
		if (op1[15] == op2[15]) begin
			outMan = man1+man2;
			$display("%b,%b,%b",man1,man2,outMan);
			out[15] = op1[15];
			if (outMan[8] == 1) //CHECK FOR OVERFLOW
			begin
				out[14:7] = out[14:7]-1; //MIGHT BREAK
			end
		end else begin
		if (man1 > man2) begin
			outMan = man1-man2;
			out[15] = op1[15];
		end else begin
			outMan = man2-man1;
			out[15] = op2[15];
		end

		end
		out[6:0] = outMan[8:2];
	
	end	
	
endmodule
	
module i2f(in,out);
	input `WORD in;
	output reg `WORD out;
	
	reg[6:0] zeros;
	reg [22:0] temp;
	
	wire `WORD numZeros;
	
	lead_zero leadZeros(in, numZeros);
	
	initial begin
		zeros<= 0;
	end
	
	always@(*) begin
		temp = {in,zeros};
		out[15] = in[15]; //set sign bit
		out[14:7] = 127+(15-numZeros-1); //set exponent
		out[6:0] = temp >> (15-numZeros); //set mantissa
	end
endmodule

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


module f2i(in,out);
	input `WORD in;
	output reg `WORD out;
	reg [22:0] temp;
	
	always @(*) begin
		temp = {16'b1,in[6:0]};
		//$display("%b",temp);
		if (in[14:7] >= 127) begin
			temp = temp << (in[14:7] - 127);
			out = temp[22:7];
		 end else begin 
			out = 0;
		end
		if (in[15] == 1) begin
			out = out ^ 'hffff;
			out = out+1;
		end
	end	
endmodule

module test;

	reg `WORD temp1;
	reg `WORD temp2;
	wire `WORD out;
	
	addf MSB(temp1,temp2,out);
	
	initial begin
	temp1 <= 'h4040;
	temp2 <= 'h4040;
	
	
	repeat (1) begin
		#5;
		$display("%b",out);
		//temp = temp * 2;
	end
	end
	
	
endmodule