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


module test;

	reg `WORD temp;
	wire `WORD out;
	
	ones MSB(temp,out);
	
	initial begin
	temp <= 15;
	
	
	repeat (10) begin
		#5;
		$display("%d",out);
		temp = temp * 2;
	end
	end
	
	
endmodule