`timescale 1ns / 1ps
module projectCPU2022(
  clk,
  rst,
  wrEn,
  data_fromRAM,
  addr_toRAM,
  data_toRAM,
  PC,
  W
);

// Opcodes
parameter ADD = 0;
parameter NOR = 1;
parameter SRL = 2;
parameter RRL = 3;
parameter CMP = 4;
parameter BZ = 5;
parameter CP2W = 6;
parameter CPfW = 7;

parameter RI = 0; // Read Instruction
parameter DE = 1; // Decode Instruction
parameter RD4 = 2; // Request Data 4
parameter EX = 3; // Take *A and Execute


input clk, rst;

input wire [15:0] data_fromRAM;
output reg [15:0] data_toRAM;
output reg wrEn;

// 12 can be made smaller so that it fits in the FPGA
output reg [12:0] addr_toRAM;
output reg [12:0] PC; // This has been added as an output for TB purposes
output reg [15:0] W; // This has been added as an output for TB purposes

// Internal signals
reg [12:0] PCNext;
reg [15:0] WNext;
reg [2:0] state, stateNext;
reg [2:0] opcode, opcodeNext;
reg [12:0] operandA, operandANext;
reg [15:0] starA, starANext;
// Your design goes in here

always @(posedge clk) begin
	state 	<= #1 stateNext;
	PC 		<= #1 PCNext;
	opcode 	<= #1 opcodeNext;
	operandA <= #1 operandANext;
	starA 	<= #1 starANext;
	W 			<= #1 WNext;
end

always @(*) begin
	// Default assignments
	stateNext    = state;
	PCNext 		 = PC;
	opcodeNext   = opcode;
	operandANext = operandA;
	starANext 	 = starA;
	WNext 		 = W;
	addr_toRAM   = 0;
	data_toRAM   = 0;
	wrEn         = 0;
	
	if(rst) begin
		stateNext 	 = 0;
		PCNext 	 	 = 0;
		opcodeNext   = 0;
		operandANext = 0;
		starANext 	 = 0;
		WNext 		 = 0;
		addr_toRAM   = 0;
		data_toRAM   = 0;
		wrEn         = 0;
	end
	else begin
		case(state)
			RI : begin
				PCNext 		 = PC;
				opcodeNext   = opcode;
				operandANext = 0;
				starANext 	 = 0;
				WNext 		 = W;
				addr_toRAM   = PC;
				data_toRAM   = 0;
				wrEn         = 0;
				stateNext 	 = DE;
			end
			
			DE : begin  // take opcode and request *A
				PCNext = PC;
				opcodeNext = data_fromRAM[15:13];
				operandANext = data_fromRAM[12:0];
				starANext = 0;
				addr_toRAM = data_fromRAM[12:0] == 0 ? 4 : data_fromRAM[12:0]; // request *4 or *A
				WNext = W;
				wrEn = 0;
				data_toRAM = 0;
				stateNext = data_fromRAM[12:0] == 0 ? RD4 : EX;
			end
			
			RD4 : begin  
				PCNext = PC;
				opcodeNext = opcode;
				operandANext = data_fromRAM;
				addr_toRAM = operandANext;  // request **4 
			   WNext = W;
				wrEn = 0;
				data_toRAM = 0;
				stateNext = EX;
			end
			
			EX : begin 
				starANext = data_fromRAM; //take *A
				case(opcode)
					ADD : begin
						WNext = W + starANext;
						PCNext = PC+1;
						stateNext = RI;
					end
					
					NOR : begin
						WNext = ~(W | starANext);
						PCNext = PC+1;
						stateNext = RI;
					end
					
					SRL : begin
						if(starANext < 16) begin
                     WNext = W >> starANext;
                  end
                  else begin
                     WNext = W << (starANext - 16);
							if(starANext >= 32) begin
								WNext = W << (starANext % 16);
							end
						end
						
						PCNext = PC+1;
						stateNext = RI;
					end
					
					RRL : begin
						if(starANext < 16) begin
							WNext = (W >> starANext) | (W << (16 - starANext));
						end
						else begin 
							WNext = (W << (starANext - 16)) | (W >> (16 - (starANext - 16)));
							if(starANext >= 32) begin
								WNext = (W << (starANext % 16)) | (W >> (16 - (starANext % 16)));
							end
						end
						
						PCNext = PC+1;
						stateNext = RI;
					end
					
					CMP : begin
						if(WNext < starANext)
							WNext = 65535;
						else if(W == starANext)
							WNext = 0;
						else
							WNext = 1;
						PCNext = PC+1;
						stateNext = RI;
					end
					
					BZ : begin
						if(starANext == 0) begin
							PCNext = W;
						end
						else begin 
							PCNext = PC+1;
						end
						stateNext = RI;	
					end
					
					CP2W : begin
						WNext = starANext;
						PCNext = PC+1;
						stateNext = RI;
					end
					
					CPfW : begin
						wrEn = 1;
						addr_toRAM = operandA;
						data_toRAM = W;
						PCNext = PC+1;
						stateNext = RI;
					end
				endcase	
			end
			
			default: begin 
				PCNext = 0;
				stateNext = 0;
				WNext = 0;
				opcodeNext = 0;
				operandANext = 0;
				starANext = 0;
				addr_toRAM = 0;
				wrEn = 0;
				data_toRAM = 0;
			end
			
		endcase
	end
end
endmodule
