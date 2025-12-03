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

