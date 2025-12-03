`timescale 1ns / 1ps

//==============================================================================
// Transaction Class
//==============================================================================
class transaction;
    
    //--------------------------------------------------------------------------
    // Data Members
    //--------------------------------------------------------------------------
    bit         newd;
    rand bit    op;
    rand bit [7:0] din;
    rand bit [6:0] addr;
    bit [7:0]   dout;
    bit         done;
    bit         busy;
    bit         ack_err;
    
    //--------------------------------------------------------------------------
    // Constraints
    //--------------------------------------------------------------------------
    constraint addr_c {
        addr > 1;
        addr < 5;
        din > 1;
        din < 10;
    }
    
    constraint rd_wr_c {
        op dist {1 :/ 50, 0 :/ 50};
    }
    
endclass


//==============================================================================
// Generator Class
//==============================================================================
class generator;
    
    //--------------------------------------------------------------------------
    // Class Members
    //--------------------------------------------------------------------------
    transaction tr;
    mailbox #(transaction) mbxgd;
    
    event done;      // Generator completed sending requested transactions
    event drvnext;   // Driver completed its work
    event sconext;   // Scoreboard completed its work
    
    int count = 0;
    
    //--------------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------------
    function new(mailbox #(transaction) mbxgd);
        this.mbxgd = mbxgd;
        tr = new();
    endfunction
    
    //--------------------------------------------------------------------------
    // Run Task
    //--------------------------------------------------------------------------
    task run();
        repeat(count) begin
            assert(tr.randomize) else $error("Randomization Failed");
            
            mbxgd.put(tr);
            $display("[GEN]: op: %0d, addr: %0d, din: %0d", tr.op, tr.addr, tr.din);
            
            @(drvnext);
            @(sconext);
        end
        -> done;
    endtask
    
endclass


//==============================================================================
// Driver Class
//==============================================================================
class driver;
    
    //--------------------------------------------------------------------------
    // Class Members
    //--------------------------------------------------------------------------
    virtual i2c_if vif;
    transaction tr;
    event drvnext;
    mailbox #(transaction) mbxgd;
    
    //--------------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------------
    function new(mailbox #(transaction) mbxgd);
        this.mbxgd = mbxgd;
    endfunction
    
    //--------------------------------------------------------------------------
    // Reset Task
    //--------------------------------------------------------------------------
    task reset();
        vif.rst  <= 1'b1;
        vif.newd <= 1'b0;
        vif.op   <= 1'b0;
        vif.din  <= 0;
        vif.addr <= 0;
        
        repeat(10) @(posedge vif.clk);
        
        vif.rst <= 1'b0;
        
        $display("[DRV]: RESET DONE");
        $display("---------------------------------");
    endtask
    
    //--------------------------------------------------------------------------
    // Write Task
    //--------------------------------------------------------------------------
    task write();
        vif.rst  <= 1'b0;
        vif.newd <= 1'b1;
        vif.op   <= 1'b0;
        vif.din  <= tr.din;
        vif.addr <= tr.addr;
        
        repeat(5) @(posedge vif.clk);
        vif.newd <= 1'b0;
        
        @(posedge vif.done);
        
        $display("[DRV]: OP: WR, ADDR: %0d, DIN: %0d", tr.addr, tr.din);
        
        vif.newd <= 1'b0;
    endtask
    
    //--------------------------------------------------------------------------
    // Read Task
    //--------------------------------------------------------------------------
    task read();
        vif.rst  <= 1'b0;
        vif.newd <= 1'b1;
        vif.op   <= 1'b1;
        vif.din  <= 0;
        vif.addr <= tr.addr;
        
        repeat(5) @(posedge vif.clk);
        vif.newd <= 1'b0;
        
        @(posedge vif.done);
        
        $display("[DRV]: OP: RD, ADDR: %0d, DOUT: %0d", tr.addr, vif.dout);
    endtask
    
    //--------------------------------------------------------------------------
    // Run Task
    //--------------------------------------------------------------------------
    task run();
        tr = new();
        
        forever begin
            mbxgd.get(tr);
            
            if (tr.op == 1'b0)
                write();
            else
                read();
            
            -> drvnext;
        end
    endtask
    
endclass


//==============================================================================
// Monitor Class
//==============================================================================
class monitor;
    
    //--------------------------------------------------------------------------
    // Class Members
    //--------------------------------------------------------------------------
    virtual i2c_if vif;
    transaction tr;
    mailbox #(transaction) mbxms;
    
    //--------------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------------
    function new(mailbox #(transaction) mbxms);
        this.mbxms = mbxms;
    endfunction
    
    //--------------------------------------------------------------------------
    // Run Task
    //--------------------------------------------------------------------------
    task run();
        tr = new();
        
        forever begin
            @(posedge vif.done);
            
            tr.din  = vif.din;
            tr.addr = vif.addr;
            tr.op   = vif.op;
            tr.dout = vif.dout;
            
            repeat(5) @(posedge vif.clk);
            
            mbxms.put(tr);
            
            $display("[MON]: op: %0d, addr: %0d, din: %0d, dout: %0d", 
                     tr.op, tr.addr, tr.din, tr.dout);
        end
    endtask
    
endclass


//==============================================================================
// Scoreboard Class
//==============================================================================
class scoreboard;
    
    //--------------------------------------------------------------------------
    // Class Members
    //--------------------------------------------------------------------------
    transaction tr;
    mailbox #(transaction) mbxms;
    event sconext;
    
    bit [7:0] temp;
    bit [7:0] mem[128] = '{default:0};
    
    //--------------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------------
    function new(mailbox #(transaction) mbxms);
        this.mbxms = mbxms;
        
        for (int i = 0; i < 128; i++) begin
            mem[i] <= i;
        end
    endfunction
    
    //--------------------------------------------------------------------------
    // Run Task
    //--------------------------------------------------------------------------
    task run();
        forever begin
            mbxms.get(tr);
            temp = mem[tr.addr];
            
            if (tr.op == 1'b0) begin
                // Write Operation
                mem[tr.addr] = tr.din;
                $display("[SCO]: DATA STORED -> ADDR: %0d, DATA: %0d", 
                         tr.addr, tr.din);
                $display("-----------------------------------------------");
            end
            else begin
                // Read Operation
                if (tr.dout == temp) begin
                    $display("[SCO]: DATA READ -> Data Matched, exp: %0d, rec: %0d", 
                             temp, tr.dout);
                end
                else begin
                    $display("[SCO]: DATA READ -> DATA MISMATCHED, exp: %0d, rec: %0d", 
                             temp, tr.dout);
                end
                $display("-----------------------------------------------");
            end
            
            -> sconext;
        end
    endtask
    
endclass


//==============================================================================
// Testbench Top Module
//==============================================================================
module tb;
    
    //--------------------------------------------------------------------------
    // Testbench Components
    //--------------------------------------------------------------------------
    generator   gen;
    driver      drv;
    monitor     mon;
    scoreboard  sco;
    
    //--------------------------------------------------------------------------
    // Events
    //--------------------------------------------------------------------------
    event nextgd;
    event nextgs;
    
    //--------------------------------------------------------------------------
    // Mailboxes
    //--------------------------------------------------------------------------
    mailbox #(transaction) mbxgd, mbxms;
    
    //--------------------------------------------------------------------------
    // Interface and DUT Instantiation
    //--------------------------------------------------------------------------
    i2c_if vif();
    
    i2c_top dut (
        .clk     (vif.clk),
        .rst     (vif.rst),
        .newd    (vif.newd),
        .op      (vif.op),
        .addr    (vif.addr),
        .din     (vif.din),
        .dout    (vif.dout),
        .busy    (vif.busy),
        .ack_err (vif.ack_err),
        .done    (vif.done)
    );
    
    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    initial begin
        vif.clk <= 0;
    end
    
    always #5 vif.clk <= ~vif.clk;
    
    //--------------------------------------------------------------------------
    // Testbench Initialization
    //--------------------------------------------------------------------------
    initial begin
        // Create mailboxes
        mbxgd = new();
        mbxms = new();
        
        // Create testbench components
        gen = new(mbxgd);
        drv = new(mbxgd);
        mon = new(mbxms);
        sco = new(mbxms);
        
        // Configure generator
        gen.count = 20;
        
        // Connect interfaces
        drv.vif = vif;
        mon.vif = vif;
        
        // Connect events
        gen.drvnext = nextgd;
        drv.drvnext = nextgd;
        gen.sconext = nextgs;
        sco.sconext = nextgs;
    end
    
    //--------------------------------------------------------------------------
    // Pre-Test Task
    //--------------------------------------------------------------------------
    task pre_test;
        drv.reset();
    endtask
    
    //--------------------------------------------------------------------------
    // Test Task
    //--------------------------------------------------------------------------
    task test;
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
    endtask
    
    //--------------------------------------------------------------------------
    // Post-Test Task
    //--------------------------------------------------------------------------
    task post_test;
        wait(gen.done.triggered);
        $finish();
    endtask
    
    //--------------------------------------------------------------------------
    // Run Task
    //--------------------------------------------------------------------------
    task run();
        pre_test;
        test;
        post_test;
    endtask
    
    //--------------------------------------------------------------------------
    // Main Test Execution
    //--------------------------------------------------------------------------
    initial begin
        run();
    end
    
    //--------------------------------------------------------------------------
    // Waveform Dump
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars();
    end
    
endmodule
