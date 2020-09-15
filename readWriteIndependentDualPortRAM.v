// True Dual Port RAM. Use non-blocking assignment (<=) for Read-Before-Write Capability.
module tdpRAM(
	output reg  [1:0][DATA_WIDTH-1:0] dOut,
	input  wire [1:0][DATA_WIDTH-1:0] dIn,
	input  wire [1:0][ADDR_WIDTH-1:0] addr,
	input  wire [1:0] wren,
	input  wire clk
);
	parameter DATA_WIDTH = 8;
	parameter ADDR_WIDTH = 5;
	reg [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];
	// Port 0
	always @(posedge clk) begin 
		if(wren[0])
			ram[addr[0]] = dIn[0];
		dOut[0] = ram[addr[0]];
	end
	// Port 1
	always @(posedge clk) begin 
		if(wren[1])
			ram[addr[1]] = dIn[1];
		dOut[1] = ram[addr[1]];
	end
endmodule

module liveValueTable(
	output reg  [1:0] memLoc,
	input  wire [1:0] updVal,
	input  wire [1:0][ADDR_WIDTH-1:0] rdAddr, wrAddr,
	input  wire [1:0] wren,
	input  wire clk, reset
);
	parameter ADDR_WIDTH = 5;
	integer i;
	reg ram [2**ADDR_WIDTH];
	// Combinational Read
	always @(*) begin
		memLoc[0] <= ram[rdAddr[0]];
		memLoc[1] <= ram[rdAddr[1]];
	end
	// Sequential Write
	always @(posedge clk or negedge reset) begin
		if(~reset)
			for(i=0; i<2**ADDR_WIDTH; i=i+1)
				ram[i] <= 1'b0;
		else begin
			if(wren[0])
				ram[wrAddr[0]] <= updVal[0];
			if(wren[1])
				ram[wrAddr[1]] <= updVal[1];
		end
	end
endmodule

module main(
	output reg  [1:0][DATA_WIDTH-1:0] dOut,
	input  wire [1:0][DATA_WIDTH-1:0] dIn,
	input  wire [1:0][ADDR_WIDTH-1:0] rdAddr, wrAddr,
	input  wire [1:0] wren,
	input  wire clk, reset
);
	parameter DATA_WIDTH = 8;
	parameter ADDR_WIDTH = 5;
	
	wire [1:0] memLoc;
	reg  [1:0] updVal;
	wire [1:0] wrenRAM0, wrenRAM1;
	reg  [3:0] wrenVector;
	wire [1:0][ADDR_WIDTH-1:0] addrRAM0, addrRAM1;
	wire [1:0][DATA_WIDTH-1:0] dtInRAM0, dtInRAM1, dOutRAM0, dOutRAM1;
	reg  [3:0][ADDR_WIDTH-1:0] addrVector;
	reg  [3:0][DATA_WIDTH-1:0] dtInVector;
	// Vector to RAM wiring.
	assign {addrRAM0, addrRAM1} = addrVector;		// for address routing
	assign {wrenRAM0, wrenRAM1} = wrenVector;		// for wren routing
	assign {dtInRAM0, dtInRAM1} = dtInVector;
	// Address Route and Update Configuration Mux
	always @(*) begin
		case(memLoc)
			2'b00: begin
				dtInVector = {{DATA_WIDTH{1'bx}}, {DATA_WIDTH{1'bx}}, dIn[0], dIn[1]};
				addrVector = {rdAddr[0], rdAddr[1], wrAddr[0], wrAddr[1]};
				wrenVector = {1'b0, 1'b0, 1'b1 & wren[0], 1'b1 & wren[1]};
				dOut = {dOutRAM0[0], dOutRAM0[1]};	// Magic here.
				updVal = 2'b11;
			end
			2'b01: begin
				dtInVector = {{DATA_WIDTH{1'bx}}, dIn[0], {DATA_WIDTH{1'bx}}, dIn[1]};
				addrVector = {rdAddr[0], wrAddr[0], rdAddr[1], wrAddr[1]};
				wrenVector = {1'b0, 1'b1 & wren[0], 1'b0, 1'b1 & wren[1]};
				dOut = {dOutRAM1[1], dOutRAM0[1]};	// Magic here.
				updVal = 2'b01;
			end
			2'b10: begin
				dtInVector = {{DATA_WIDTH{1'bx}}, dIn[0], {DATA_WIDTH{1'bx}}, dIn[1]};
				addrVector = {rdAddr[1], wrAddr[0], rdAddr[0], wrAddr[1]};
				wrenVector = {1'b0, 1'b1 & wren[0], 1'b0, 1'b1 & wren[1]};
				dOut = {dOutRAM0[1], dOutRAM1[1]};	// Magic here.
				updVal = 2'b01;
			end
			2'b11: begin
				dtInVector = {dIn[0], dIn[1], {DATA_WIDTH{1'bx}}, {DATA_WIDTH{1'bx}}};
				addrVector = {wrAddr[0], wrAddr[1], rdAddr[0], rdAddr[1]};
				wrenVector = {1'b1 & wren[0], 1'b1 & wren[1], 1'b0, 1'b0};
				dOut = {dOutRAM1[0], dOutRAM1[1]};	// Magic here.
				updVal = 2'b00;
			end
		endcase
	end
	
	tdpRAM #(DATA_WIDTH, ADDR_WIDTH) RAM0(
		.dOut(dOutRAM0),
		.dIn(dtInRAM0),
		.addr(addrRAM0),
		.wren(wrenRAM0),
		.clk(clk)
	);
	
	tdpRAM #(DATA_WIDTH, ADDR_WIDTH) RAM1(
		.dOut(dOutRAM1),
		.dIn(dtInRAM1),
		.addr(addrRAM1),
		.wren(wrenRAM1),
		.clk(clk)
	);
	
	liveValueTable #(ADDR_WIDTH) LVT0(
		.memLoc(memLoc),
		.updVal(updVal),
		.rdAddr(rdAddr),
		.wrAddr(wrAddr),
		.wren(wren),
		.clk(clk), .reset(reset)
	);
endmodule

