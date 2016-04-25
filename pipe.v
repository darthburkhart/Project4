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
	
	always @(op or opr1 or opr2)
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
				//$display("out1: %h",out1);
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
	//reg `WORD i;
	reg squashNext2,squashNext1;
	ALU alu(op2,op1,toStage3,operation,cc);
		
	initial begin
		$readmemh("test8.ram",ram);
		halt<=0;
		holdUp<=0;
		//register file initialization
		$readmemh("registers.ram",registers);
		pc <= 16'b0;
		squashNext1<=0;
		squashNext2<=0;
		pcFlag<=0;
		newPC<=16'b0;
		stop1<=0;
		stop2<=0;
	end
	
	
	always@(clk) begin
		//$display("Clock: %b",clk);
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
		#2 $display("Stage 1: %h",stage1[5]);//$display("Stage1: %h  %h",pc,ram[pc]);
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
		#4 $display("Stage 2: %h",stage2[5]);
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
	
		#6 $display("Stage 3: %h\n",stage3[5]);
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
		//#15 $display("Stage 4: %h",registers[stage3[0][5:0]],stage3[1]);
	end
	
	always@(halt)
	begin
		if (halt == 1'b1)
		begin
		//$display("Program Counter: %h",pc);
		$display("First 15 registers: \n0: %h\n1: %h\n2: %h\n3: %h\n4: %h\n5: %h\n6: %h\n7: %h\n8: %h\n9: %h\n10: %h\n11: %h\n12: %h\n13: %h\n14: %h\n15: %h",registers[8],registers[9],registers[10],registers[11],registers[12],registers[13],registers[14],registers[15],registers[16],registers[17],registers[18],registers[19],registers[20],registers[21],registers[22],registers[23]);
		//$display("RAM Data: \n%h\n%h\n%h\n%h",ram[50],ram[51],ram[52],ram[53]);
		end
	end

endmodule

module testBench;
	reg clk;
	wire clear;

	processor proc(clk,clear);

	initial 
	begin
		//$dumpfile;
		//$dumpvars(0,testBench);
		//$display("Here 0");
		#100 //Wait until ALL memory is initialized
		clk <= 0;
		while (clear != 1)
		begin
			//$display("Clock %b",clk);
			#100;
			clk<=~clk;		
		end
		//$finish;
	end
	
	
endmodule