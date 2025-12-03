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

