// Code your testbench here
// or browse Examples

package tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // -------------------------------------------------
  // Global testbench parameters
  // -------------------------------------------------
  parameter int DWIDTH = 16;
  parameter int DEPTH      = 8 ;

//seq_item
class seq_item extends uvm_sequence_item;

  rand bit [DWIDTH-1:0]din;
  rand bit wr_en;
  rand bit rd_en;
  bit [DWIDTH-1:0]dout;
  bit empty;
  bit full;
  function new(string name="seq_item");
    super.new(name);
  endfunction
  
  constraint no_sim_rd_wr {
      // Favor writes over reads
  	wr_en dist {1 := 70, 0 := 30};
    rd_en dist {1 := 30, 0 := 70};
    !(rd_en&&wr_en);
  }

  `uvm_object_utils_begin(seq_item)
     `uvm_field_int(wr_en,UVM_ALL_ON)
     `uvm_field_int(rd_en,UVM_ALL_ON)
     `uvm_field_int(din,UVM_ALL_ON)  
     `uvm_field_int(dout,UVM_ALL_ON)
     `uvm_field_int(empty,UVM_ALL_ON)
     `uvm_field_int(full,UVM_ALL_ON)
  `uvm_object_utils_end
endclass

//seq
class myseq extends uvm_sequence#(seq_item);
  `uvm_object_utils(myseq)
  rand int num;
  function new(string name="myseq");
    super.new(name);
  endfunction
  
  constraint c1 { num inside {[50:100]}; }
  
  virtual task body;
    this.randomize();
    `uvm_info(get_type_name(),$sformatf("generating num=%0d transactions \n",num),UVM_LOW);
    repeat (num) begin
      seq_item seq_item1;
      seq_item1=seq_item::type_id::create("seq_item1");
      start_item(seq_item1);
      assert(seq_item1.randomize());
      finish_item(seq_item1);
    end
  endtask
  
endclass

//seqr
class seqr extends uvm_sequencer#(seq_item);
  `uvm_component_utils(seqr)
  function new(string name="seqr",uvm_component parent);
    super.new(name,parent);
  endfunction
  
endclass

//driver
class driver extends uvm_driver#(seq_item);
  `uvm_component_utils(driver)
  virtual intf vif;
  
  function new(string name="driver",uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual intf)::get(this,"","vif",vif))
      `uvm_fatal(get_type_name(),"failed to get virtual intf\n");
  endfunction
  
  task run_phase(uvm_phase phase);
    forever begin
      seq_item seq_item1;
      //seq_item1=seq_item::type_id::create("seq_item1",this);
      seq_item_port.get_next_item(seq_item1);
      
      drive_sig(seq_item1);
      seq_item_port.item_done();
     // `uvm_info(get_type_name(),$sformatf("driver rstn=%0b wren=%0b full=%0b din=%0h\n",vif.rstn,vif.wr_en,vif.full,vif.din),UVM_LOW);
    end
    
  endtask
  
  task drive_sig(seq_item seq_item1);
    @(posedge vif.clk);
    if(vif.rstn) begin
    vif.wr_en<=seq_item1.wr_en;
    vif.rd_en<=seq_item1.rd_en;
    vif.din<=seq_item1.din;
    end
    
  endtask
  
endclass

//monitor

class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)
  
  virtual intf vif;
  
  uvm_analysis_port#(seq_item) a_port;
  
  function new(string name="monitor",uvm_component parent);
    super.new(name,parent);
    a_port=new("a_port",this);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual intf)::get(this,"","vif",vif))
       `uvm_fatal(get_type_name(),"failed to get virtual intf\n");
    
  endfunction
  
  task run_phase(uvm_phase phase);
    forever begin
       seq_item seq_item1;
        seq_item1=seq_item::type_id::create("seq_item1",this);
       @(posedge vif.clk);
     
      if(vif.wr_en  && vif.rstn) begin
        `uvm_info(get_type_name(),$sformatf("monitor rstn=%0b wren=%0b full=%0b din=%0h\n",vif.rstn,vif.wr_en,vif.full,vif.din),UVM_LOW);
          seq_item1.wr_en=vif.wr_en;
          seq_item1.din=vif.din;
         seq_item1.full=vif.full;
         a_port.write(seq_item1);
        
      end
      else if (vif.rd_en && vif.rstn ) begin
        seq_item1.rd_en=1'b1;
        seq_item1.empty=vif.empty;
        fork
        begin
          @(posedge vif.clk);
          seq_item1.dout = vif.dout;
          `uvm_info(get_type_name(),$sformatf("monitor rstn=%0b rden=%0b empty=%0b dout=%0h\n",vif.rstn,vif.rd_en,vif.empty,vif.dout),UVM_LOW);
          a_port.write(seq_item1);
        end
      join_none
      end
      
      //@(posedge vif.clk);
     
    end
  endtask
endclass

//agent
class agent extends uvm_agent;
  `uvm_component_utils(agent)
  seqr seqr1;
  driver driver1;
  monitor monitor1;
  
  function new(string name="agent",uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(get_is_active()==UVM_ACTIVE) begin
    seqr1=seqr::type_id::create("seqr1",this);
    driver1=driver::type_id::create("driver1",this);
    end
    
    monitor1=monitor::type_id::create("monitor1",this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(get_is_active()==UVM_ACTIVE)
    driver1.seq_item_port.connect(seqr1.seq_item_export);
  endfunction
endclass

//scoreboard
class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)
  
  uvm_analysis_imp#(seq_item,scoreboard) a_imp;
  bit [DWIDTH-1:0]ref_model[$];
  bit [DWIDTH-1:0]exp_data;
  
  function new(string name="scoreboard",uvm_component parent);
    super.new(name,parent);
    
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a_imp=new("a_imp",this);
  endfunction
  
  virtual function void write(seq_item seq_item1);
    if(seq_item1.wr_en && !(seq_item1.full)) begin
      ref_model.push_back(seq_item1.din);
      `uvm_info(get_type_name(),$sformatf("REF FIFO PUSH DATA=%0h\n",seq_item1.din),UVM_LOW);
    end
    else if(seq_item1.rd_en && !(seq_item1.empty)) begin //{
      
      exp_data=ref_model.pop_front();
      `uvm_info(get_type_name(),$sformatf("REF FIFO POP DATA=%0h\n",exp_data),UVM_LOW);
      if(seq_item1.dout == exp_data) begin//{
        `uvm_info(get_type_name(),$sformatf("FIFO DATA MATCH exp=%0h and act=%0h\n",exp_data,seq_item1.dout),UVM_LOW);
      end //}
      else begin //{
       `uvm_info(get_type_name(),$sformatf("FIFO DATA MISMATCH exp=%0h and act=%0h\n",exp_data,seq_item1.dout),UVM_LOW);
       `uvm_error(get_type_name(),"Data Mismatch\n");
      end //}
    end //}
  endfunction
endclass

//env
class env extends uvm_env;
  `uvm_component_utils(env)
  
  scoreboard scoreboard1;
  agent agent1;
  
  function new(string name="env",uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent1=agent::type_id::create("agent1",this);
    scoreboard1=scoreboard::type_id::create("scoreboard1",this);                             
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent1.monitor1.a_port.connect(scoreboard1.a_imp);
  endfunction
  
endclass

//test
class test extends uvm_test;
  `uvm_component_utils(test)
  env env1;

  function new(string name="test", uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env1=env::type_id::create("env1",this);
  endfunction
  
  task run_phase(uvm_phase phase);
    myseq myseq1;    
    phase.raise_objection(this);
    myseq1=myseq::type_id::create("myseq1",this);
    myseq1.start(env1.agent1.seqr1);
    phase.drop_objection(this);
    
  endtask
endclass




endpackage
      
`timescale 1ns/1ps
import uvm_pkg::*;
import tb_pkg::*;
`include "uvm_macros.svh"

module tb_top;
  
  // Clock
  logic clk;

  // Interface
   intf vif (clk);
  
  // DUT instance
  sync_fifo dut (
    .clk     (clk),
    .rstn     (vif.rstn),
    .rd_en    (vif.rd_en),
    .wr_en    (vif.wr_en),
    .empty    (vif.empty),
    .full    (vif.full),
    .din  (vif.din),
    .dout (vif.dout)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;   // 100 MHz
  end

  // Reset generation
  initial begin
    vif.rstn    = 0;
    vif.rd_en   = 0;
    vif.wr_en   = 0;
    vif.din = 0;

    repeat (3) @(posedge clk);
    vif.rstn = 1;
  end

  // UVM configuration and test start
  initial begin
    // Make virtual interface visible to UVM
    uvm_config_db#(virtual intf)::set(
      null, "*", "vif", vif
    );

    // Start UVM
    run_test("test");
    
    
  end

  initial begin
    $dumpvars;
    $dumpfile ("dump.vcd");
  end
  

endmodule
