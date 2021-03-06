//`timescale 1ns/10ps
`define TCLK    250

module tb_spi;  

wire            SPI_SOMI;
wire    [5:0]   ctrlCNT;
//wire	[2:0]	state;

//wire 	[31:0]	written_data;
//wire	[2:0]	SID_ch;
//wire	[6:0]	addr_ch;
//wire	[31:0]	din_ch;
//wire		wr_r_ch;
//wire	[31:0]	dout;
reg             write_on;
reg             Reset_n;

reg             SPI_CS;
reg             SCK;
reg             SPI_SIMO;
reg             SPI_CLK;

reg     [31:0]  received_data;

reg     [42:0]  shift_wdata;
reg     [10:0]  shift_rdata;


// Hardwired ID of DUT
localparam  [2:0]   SPI_ID_VALUE = 3'b010;


SPI_SLAVE  DUT (
    	
    // Hardwired ID
    .SID_assign         (SPI_ID_VALUE),

    // Active Low Asynchronous Global Reset
    .SPI_RST           (Reset_n),

    // 4-Wire Signals for SPI
    .SPI_CS             (SPI_CS),
    .SPI_CLK            (SPI_CLK),
    .SPI_MOSI           (SPI_SIMO),
    .SPI_MISO           (SPI_SOMI)//,
//    .CST		(state),
//    .reg_val		(written_data),
//    .SID_ch		(SID_ch),
//    .addr_ch		(addr_ch),
//    .din_ch		(din_ch),
//    .wr_r_ch		(wr_r_ch),
//    .cnt		(ctrlCNT),
//    .dout		(dout)
);


// clk generators
initial 
begin
  SCK = 1'b0;
end

always #(`TCLK/2.0) SCK <= ~SCK;

// Reset
initial
begin
    		   Reset_n <= 1'b1;
    #(`TCLK*1)     Reset_n <= 1'b0;
    #(`TCLK*10)    Reset_n <= 1'b1;
end

// Simulation End
initial
begin
    $dumpfile("SPI_SLAVE.vcd");
    $dumpvars();
    #(`TCLK*400);
    $finish; 
end

// write (CS(1bit,Active LOW), SID(3bit), WRB(1bit) == 1'b1, ADDRESS(7bit), DATA(32bit));
// read (CS(1bit,Active LOW), SID(3bit), WRB(1bit) == 1'b0, ADDRESS(7bit));
// cmp (ADDRESS(7bit), expectedData(8bit));
initial 
begin
      SPI_CS = 1'b1;
      #(`TCLK*12);
      #(`TCLK/2);
      write(1'b0, SPI_ID_VALUE, 1'b1, 7'd30, 32'h92345679);
      done(1'b1);
    
      #(`TCLK*12);

      read(1'b0, 3'b111, 1'b0, 7'd30);
      cmp(7'd30,32'h92345679);
      done(1'b1);
      read(1'b0, SPI_ID_VALUE, 1'b0, 7'd30);
      cmp(7'd30,32'h92345679);
      done(1'b1);

  //  $dumpfile("SPI_SLAVE.vcd");
  //  $dumpvars();
    #(`TCLK*20);
end


always @* 
begin
    if(SPI_CS == 1'b0) 
        SPI_CLK <= SCK;
      
    else 
        SPI_CLK <= 1'b0;
end


task write;
   input CS;
   input [2:0] SID;
   input wrb;
   input [6:0] addr;
   input [31:0] data;

   begin
      SPI_CS = CS;
      write_on = 1'b1;
      shift_wdata = {SID,wrb,addr,data};
      $write("WRITE : At[%2d] = 0x%0x\n", addr,data);
      #(`TCLK*44);
   end

endtask


task read;
   input CS;
   input [2:0] SID;
   input wrb;
   input [6:0] addr;

   begin
      SPI_CS = CS;
      write_on = 1'b0;
      shift_rdata = {SID,wrb,addr};
      #(`TCLK*44);
   end

endtask

task cmp;
   input [6:0] addr;
   input [31:0] expectedData;

    begin
        if(expectedData != received_data) 
        begin
            $write("****** READ ERROR : At[%2d] = Expected 0x%0x, got 0x%0x\n", addr,expectedData, received_data);
        end

        else 
        begin
            $write("READ : At[%2d] = 0x%0x\n", addr,received_data);
        end
   end

endtask


task done;
   input CS;

   begin
      SPI_CS = CS;
      #(`TCLK);
   end

endtask

always @(posedge SPI_CLK or negedge Reset_n) 
begin
    if (~Reset_n) 
    begin
        SPI_SIMO <= 1'b0;
        shift_wdata <= 43'h0;
        shift_rdata <= 11'h000;
    end
    
    // For Write
    else if(write_on == 1'b1)
    begin
        shift_wdata <= shift_wdata << 1'b1;
        SPI_SIMO <= shift_wdata[42];
    end

    // For Read
    else if(write_on == 1'b0)
    begin
        shift_rdata <= shift_rdata << 1'b1;
        SPI_SIMO <= shift_rdata[10];
    end
end

// For Read


   always @(negedge SPI_CLK or negedge Reset_n)
   begin
      if (~Reset_n) 
      begin
         received_data <= 32'h0;
      end

      else if(write_on == 1'b0 && DUT.ctrl_cnt >= 5'd0 && DUT.ctrl_cnt <= 5'd31)
      begin
         received_data <= {received_data[30:0],SPI_SOMI};
      end
   end



endmodule

