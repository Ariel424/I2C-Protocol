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
