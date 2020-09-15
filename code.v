`default_nettype none
// GOOD BOTS COUNT FROM ZERO
/*
Tenets of faith for a good halo resolver:
0. Is divided between control unit and data path.
1. Has true-dual-port with read before write support.
2. port-0 used for sending Halos.
3. port-1 used for receiving Halos.

REMINDER FOR THE FORGETFUL:
- drainBuffers already Filled after draining from Clemence's Acc. Banks . Is made of 2portRAM/RBW.
- In the Clemens' Design, ADDRLEN is known as ACCUMULATOR_ADDR_WIDTH. It's the addr width 'for' Accumulators. Not 'in' acc. 
*/
// Right Rotate but RAMs can be LSB first too. Take care of ENDIANs. 3210 (1rot)--> 0321. RAM1 @ RAM0 means RAM ROT LEFT.
module rotUnit(
	output wire [2**ADDRLEN-1:0][WORDLEN-1:0] out,
	input  wire [2**ADDRLEN-1:0][WORDLEN-1:0] in,
	input  wire [ADDRLEN-1:0] ramt
);
	parameter ADDRLEN = 2;
	parameter WORDLEN = 8;
	//						   [  MUX NUMBER  ][  LINE NUMBER ]
	wire [WORDLEN-1:0] muxLine [2**ADDRLEN-1:0][2**ADDRLEN-1:0];
	
	generate
		genvar i, j;
		for(i=0; i<2**ADDRLEN; i=i+1) begin: m
			assign out[i] = muxLine[i][ramt];
			for (j=0; j<2**ADDRLEN; j=j+1) begin: n
				assign muxLine[i][j] = in[$unsigned(i[ADDRLEN-1:0]+j[ADDRLEN-1:0])];
			end
		end
	endgenerate
endmodule

module blockRam(
	output reg  [2**ADDRLEN-1:0][1:0][15:0] dOut,
	input  wire [2**ADDRLEN-1:0][1:0][15:0] dIn,
	input  wire [2**ADDRLEN-1:0][1:0][LINWDTH-ADDRLEN-1:0] addr,
	input  wire [2**ADDRLEN-1:0][1:0] en, wren,
	input  wire clk, reset
);
	parameter LINWDTH=9;
	parameter ADDRLEN=3;
	parameter RAMIMAG=0;
	parameter PLDEPTH=2;
	integer i, j;
	
	// RAM set-up
	reg  [15:0] data [2**ADDRLEN-1:0][2**(LINWDTH-ADDRLEN)-1:0];
	// misc. wire-up
	reg  [2**ADDRLEN-1:0][1:0][LINWDTH-ADDRLEN+1:0] pl [PLDEPTH:0];
	reg  [2**ADDRLEN-1:0][1:0][LINWDTH-ADDRLEN-1:0] addrPL;
	reg  [2**ADDRLEN-1:0][1:0] wrenPL, enPL;
	///////////////////////////// GTKWAVE MAPPING FOLLOWS - NON SYNTHESIZABLE CODE //////////////////////////////////////////
	wire [15:0] ram0Loc0 = data[0][0];
	wire [15:0] ram0Loc2 = data[0][2];
	wire [15:0] ram0Loc5 = data[0][5];
	wire [15:0] ram3Loc0 = data[3][0];
	wire [15:0] ram3Loc2 = data[3][2];
	wire [15:0] ram3Loc5 = data[3][5];
	wire [15:0] dOutRam0Prt0 = dOut[0][0];
	wire [15:0] dOutRam3Prt1 = dOut[3][1];
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	// Pipeline Extremity wire-up
	always @(*) {pl[0], enPL, wrenPL, addrPL} = {en, wren, addr, pl[PLDEPTH]};		// good because bad*bad=good
	
	generate
		genvar k, p;
		// PipeLine Register wire-up
		for(p=0; p < PLDEPTH; p=p+1) begin: m
			always @(posedge clk or negedge reset) begin
				if(~reset)
					pl[p+1] <= 'b0;
				else
					pl[p+1] <= pl[p];
			end
		end
		// RAM wire-up
		for(k=0; k<2**ADDRLEN; k=k+1) begin: n
			// read logic
			always @(posedge clk) begin
				if(en[k][1])
					dOut[k][1] <= data[k][addr[k][1]];
				if(en[k][0])
					dOut[k][0] <= data[k][addr[k][0]];
			end
			// write logic
			always @(posedge clk) begin
				if(wrenPL[k][1] && enPL[k][1])
					data[k][addrPL[k][1]] <= dIn[k][1];
				if(wrenPL[k][0] && enPL[k][0])
					data[k][addrPL[k][0]] <= dIn[k][0];
			end
		end
	endgenerate
	
	initial for(i=0; i<2**ADDRLEN; i=i+1)
		for(j=0; j<2**(LINWDTH-ADDRLEN); j=j+1)
			data[i][j] <= i*100+j;
endmodule

// HAS TO BE AN FSM.
// 0-state/reset-state: all counters init at rightful positions.
module haloResolveControlPath(
	output reg  [2**ADDRLEN-1:0][01:0][(LINWDTH-ADDRLEN)-1:0] addr,
	output reg  [2**ADDRLEN-1:0][01:0] wrenDP, enDP,
	input  wire [2**ADDRLEN-1:0][(LINWDTH-ADDRLEN)-1:0] initHaloSend, lastHaloSend,
	input  wire [2**ADDRLEN-1:0][(LINWDTH-ADDRLEN)-1:0] initHaloRecv, lastHaloRecv,
	input  wire [2:0][(LINWDTH-ADDRLEN)-1:0] incrTrg, incrVal,
	input  wire [(LINWDTH-ADDRLEN)-1:0] NUMITERS, EOF,
	input  wire [2**ADDRLEN-1:0] en,
	input  wire clk, reset
);
	parameter LINWDTH = 9;
	parameter ADDRLEN = 3;

	reg  [2**ADDRLEN-1:0][01:0][(LINWDTH-ADDRLEN)-1:0] incr, iter, base, offset;
	wire [2**ADDRLEN-1:0][01:0][(LINWDTH-ADDRLEN)-1:0] initHaloAddr, lastHaloAddr;
	////////////////////////// GTKWAVE MAPPING FOLLOWS - NON SYNTHESIZABLE CODE /////////////////////////////////////////////
	wire [(LINWDTH-ADDRLEN)-1:0] ram0Offset = offset[0][0];
	wire [(LINWDTH-ADDRLEN)-1:0] ram1Offset = offset[1][0];
	wire [(LINWDTH-ADDRLEN)-1:0] ram3Offset = offset[3][0];
	wire [(LINWDTH-ADDRLEN)-1:0] ram3Incr   = incr[3][0];
	wire ram0enDP = enDP[0][0];
	wire ram0wren = wrenDP[0][1];
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	wire done = enDP == 'b0;
	// Field Wide Setup.
	generate
		genvar k, p;		// 'p' for port
		for(k=0; k<2**ADDRLEN; k=k+1) begin: m
			assign initHaloAddr[k] = {initHaloRecv[k], initHaloSend[k]};
			assign lastHaloAddr[k] = {lastHaloRecv[k], lastHaloSend[k]};
			// Port handles
			for(p=0; p<2; p=p+1)begin: n
				// En, WrEn and Address Update Logic Follows
				always @(*)	begin	// Address and enableOut wire-up
					addr[k][p] <= base[k][p]+offset[k][p];
					enDP[k][p] <= en[k] & iter[k][p]!=NUMITERS;				// Use this to make done signal.
					wrenDP[k][p] <= en[k] & iter[k][p]!=NUMITERS;
				end
				// Send|Recv side Offset Increment Predictor. Combinational.
				always @(*) begin
					if(offset[k][p] > incrTrg[2])
						incr[k][p] <= incrVal[2];
					else if(offset[k][p] > incrTrg[1])
						incr[k][p] <= incrVal[1];
					else										// You may save '(LINWDTH-ADDRLEN) bits here
						incr[k][p] <= incrVal[0];
				end
				// Counter Logic for haloSendAddr/haloRecvAddr. Sequential.
				always @(negedge reset or posedge clk)
					if(~reset) begin
						iter[k][p]   <= 'b0;
						base[k][p]   <= 'b0;
						offset[k][p] <= initHaloAddr[k][p];
					end
					else if(en[k] & iter[k][p]!=NUMITERS) begin
						if(offset[k][p]!=lastHaloAddr[k][p])
							offset[k][p] <= offset[k][p]+incr[k][p]<EOF ? 
								offset[k][p]+incr[k][p]: offset[k][p]+incr[k][p]-EOF;
						else begin
							iter[k][p]   <= iter[k][p] + 'b1;
							base[k][p]   <= base[k][p] + EOF;
							offset[k][p] <= initHaloAddr[k][p];
						end
					end
			end
		end
	endgenerate
endmodule

module handOff(
	output wire [2**ADDRLEN-1:0][WORDLEN-1:0] orgSum, rotSum,
	input  wire [2**ADDRLEN-1:0][WORDLEN-1:0] orgIn, rotIn,
	input  wire [ADDRLEN-1:0] ramt,	// right rotate amount for L->R RAM arrangement
	input  wire clk
);
	parameter ADDRLEN = 3;
	parameter WORDLEN = 16;
	
	wire [2**ADDRLEN-1:0][WORDLEN-1:0] rotOut;
	reg  [2**ADDRLEN-1:0][WORDLEN-1:0] orgSumPL;
	wire [ADDRLEN-1:0] unRamt = 2**ADDRLEN-ramt;
	
	always @(posedge clk) orgSumPL = orgIn + rotOut;
	assign orgSum = orgSumPL;
	
	rotUnit #(ADDRLEN, WORDLEN) ROT1(
		.out(rotSum),
		.in(orgSum),
		.ramt(ramt)
	);
	
	rotUnit #(ADDRLEN, WORDLEN) ROT0(
		.out(rotOut),
		.in(rotIn),
		.ramt(unRamt)
	);
endmodule
	
module PE(
	output wire [2**ADDRLEN-1:0][WORDLEN-1:0] sendPortRG, sendPortDW,	// to external dInPort-0     v
	output wire [2**ADDRLEN-1:0][WORDLEN-1:0] sendPortLF, sendPortUP,	// to external handOff Mux     		v
	input  wire [2**ADDRLEN-1:0][WORDLEN-1:0] recvPortRG, recvPortDW,	// from external handOff     		^
	input  wire [2**ADDRLEN-1:0][WORDLEN-1:0] recvPortLF, recvPortUP,	// from external dOutPort-0  ^
	// Control Signals
	input  wire [2**ADDRLEN-1:0][01:0][(LINWDTH-ADDRLEN)-1:0] addrIn,
	input  wire [2**ADDRLEN-1:0][01:0] wrenDP, enDP,
	input  wire [ADDRLEN-1:0] ramt,
	input  wire [1:0] wrenMask,
	input  wire isLeft, clk, reset
);
	parameter LINWDTH = 9;
	parameter ADDRLEN = 3;
	parameter WORDLEN = 16;
	parameter RAMIMAG = 0;
	
	// Data Wires
	wire [2**ADDRLEN-1:0][1:0] wren;									// Wren Mask Wires
	wire [2**ADDRLEN-1:0][1:0][WORDLEN-1:0] dOut, dIn;					// RAM/HandOff Interface
	wire [2**ADDRLEN-1:0][WORDLEN-1:0] rotIn, orgIn, rotSum, orgSum;	// ROT/HandOff Interface
	// Interconnect and Route Logic 
	generate
		genvar k;
		for(k=0; k<2**ADDRLEN; k=k+1) begin: m
			// Internal Port 0 (HandOff) wire-up
			assign orgIn[k] = dOut[k][1];								// Internal dOutPort0
			assign rotIn[k] = isLeft ? recvPortLF[k] : recvPortUP[k];	// External rotPort(dOutPort1) Mux	
			assign sendPortRG[k] = rotSum[k];							// External dInPort1 route Right	
			assign sendPortDW[k] = rotSum[k];							// External dInPort1 route Below
			assign dIn[k][1] = orgSum[k];								// Internal dInPort0
			// Internal Port 1 (SendOff) wire-up						
			assign sendPortLF[k] = dOut[k][0];							// External dOutPort1 route Left
			assign sendPortUP[k] = dOut[k][0];							// External dOutPort1 route Top
			assign dIn[k][0] = isLeft ? recvPortRG[k] : recvPortDW[k];	// Internal dInPort1 mux
			// wren masking
			assign wren[k] = wrenMask & wrenDP[k];
		end
	endgenerate
	
	blockRam #(LINWDTH, ADDRLEN, RAMIMAG) BR0(
		.dOut(dOut),
		.dIn(dIn), .addr(addrIn),
		.en(enDP), .wren(wren),
		.clk(clk), .reset(reset)
	);
	
	handOff #(ADDRLEN, WORDLEN) HandOff(
		.orgSum(orgSum), .rotSum(rotSum),
		.orgIn(orgIn), .rotIn(rotIn),
		.ramt(ramt), .clk(clk)
	);
endmodule

module top;
	parameter LINWDTH = 9;
	parameter ADDRLEN = 3;
	parameter WORDLEN = 16;
	parameter RAMIMAG = 0;
	parameter SARRDIM = 3;		// Systolic Array Dimension
	integer i;

	// Control Signals
	wire [2**ADDRLEN-1:0][01:0][(LINWDTH-ADDRLEN)-1:0] addrOut;
	wire [2**ADDRLEN-1:0][01:0] wrenDP, enDP;
	reg  isLeft, clk, reset;
	// Meta Wires
	reg  [2**ADDRLEN-1:0][(LINWDTH-ADDRLEN)-1:0] initHaloSend, lastHaloSend;
	reg  [2**ADDRLEN-1:0][(LINWDTH-ADDRLEN)-1:0] initHaloRecv, lastHaloRecv;
	reg  [2:0][(LINWDTH-ADDRLEN)-1:0] incrTrg, incrVal;
	reg  [(LINWDTH-ADDRLEN)-1:0] NUMITERS, EOF;
	reg  [ADDRLEN-1:0] RAMROT;
	reg  [2**ADDRLEN-1:0] en;
	// Inter PE Wire Up. Coordinate Convention (Y, X). L2R: {0,0 0,1 0,2} ... T2B: {1,0 2,0 3,0} ...
	wire [2**ADDRLEN-1:0][WORDLEN-1:0] vertHalo [SARRDIM:0][SARRDIM-1:0];
	wire [2**ADDRLEN-1:0][WORDLEN-1:0] vertResl [SARRDIM:0][SARRDIM-1:0];
	wire [2**ADDRLEN-1:0][WORDLEN-1:0] horzHalo [SARRDIM-1:0][SARRDIM:0];
	wire [2**ADDRLEN-1:0][WORDLEN-1:0] horzResl [SARRDIM-1:0][SARRDIM:0];
	wire [1:0] wrenMask [SARRDIM-1:0][SARRDIM-1:0];
	
	haloResolveControlPath  #(LINWDTH, ADDRLEN) HRCP (
		.addr(addrOut), .wrenDP(wrenDP), .enDP(enDP),
		.initHaloSend(initHaloSend), .lastHaloSend(lastHaloSend),
		.initHaloRecv(initHaloRecv), .lastHaloRecv(lastHaloRecv),
		.incrTrg(incrTrg), .incrVal(incrVal),
		.NUMITERS(NUMITERS), .EOF(EOF),
		.en(en), .clk(clk), .reset(reset)
	);
	
	generate
		genvar j, k;
		for(j=0; j<SARRDIM; j=j+1) begin: m0
			for(k=0; k<SARRDIM; k=k+1) begin: m1
				// WrenMask Setup. 9 separate conditions.
				if(j==0)
					if(k==0)
						assign wrenMask[j][k] = isLeft ? 2'b10: 2'b10;
					else if(k==SARRDIM-1)
						assign wrenMask[j][k] = isLeft ? 2'b01: 2'b10;
					else
						assign wrenMask[j][k] = isLeft ? 2'b11: 2'b10;
				else if(j==SARRDIM-1)
					if(k==0)
						assign wrenMask[j][k] = isLeft ? 2'b10: 2'b01;
					else if(k==SARRDIM-1)
						assign wrenMask[j][k] = isLeft ? 2'b01: 2'b01;
					else
						assign wrenMask[j][k] = isLeft ? 2'b11: 2'b01;
				else
					if(k==0)
						assign wrenMask[j][k] = isLeft ? 2'b10: 2'b11;
					else if(k==SARRDIM-1)
						assign wrenMask[j][k] = isLeft ? 2'b01: 2'b11;
					else
						assign wrenMask[j][k] = isLeft ? 2'b11: 2'b11;			
				// PE Setup
				PE #(LINWDTH, ADDRLEN, WORDLEN, RAMIMAG) PEINST(
					.sendPortRG(horzResl[j][k+1]), .sendPortDW(vertResl[j+1][k]),	
					.sendPortLF(horzHalo[j][k+0]), .sendPortUP(vertHalo[j+0][k]),
					.recvPortRG(horzResl[j][k+0]), .recvPortDW(vertResl[j+0][k]),
					.recvPortLF(horzHalo[j][k+1]), .recvPortUP(vertHalo[j+1][k]),
					// Control Signals
					.addrIn(addrOut),
					.wrenDP(wrenDP), .enDP(enDP),
					.ramt(RAMROT),
					.wrenMask(wrenMask[j][k]),
					.isLeft(isLeft), .clk(clk), .reset(reset)
				);
			end
		end
	endgenerate
	
	initial begin
		$dumpfile("test.vcd");
		$dumpvars(0);
		
		#0 EOF = 'd5; #0 NUMITERS = 'd2;
		#0 RAMROT = 'd3;
		#0 en = {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
		#0 initHaloSend = {6'd01, 6'd03, 6'd00, 6'd02, 6'd04, 6'd01, 6'd03, 6'd00};
		#0 lastHaloSend = {6'd03, 6'd00, 6'd02, 6'd04, 6'd01, 6'd03, 6'd00, 6'd02};
		#0 initHaloRecv = {6'd02, 6'd04, 6'd01, 6'd03, 6'd00, 6'd02, 6'd04, 6'd01};
		#0 lastHaloRecv = {6'd04, 6'd01, 6'd03, 6'd00, 6'd02, 6'd04, 6'd01, 6'd03};
		#0 incrVal  = {6'd2, 6'd2, 6'd2};
		#0 incrTrg  = {6'd0, 6'd0, 6'd0};
		// PE Specific Control Signals
		#0 isLeft = 1'b1;
		
		#0 clk = 0;
		#0 reset = 1; #1 reset = 0; #1 reset = 1;
		for(i=0; i<20; i=i+1)
			#1 clk = ~clk;
	end
endmodule
