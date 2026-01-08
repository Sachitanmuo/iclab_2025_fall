`include "Usertype.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;


class Type_and_mode;
    Training_Type f_type;
    Mode f_mode;
endclass

Type_and_mode fm_info = new();

always_comb begin
  if(inf.type_valid) begin
    fm_info.f_type = inf.D.d_type[0];
  end
  if(inf.mode_valid) begin
    fm_info.f_mode = inf.D.d_mode[0];
  end
end




logic any_in_valid;
  assign any_in_valid = inf.sel_action_valid  ||
                        inf.type_valid        ||
                        inf.mode_valid        ||
                        inf.date_valid        ||
                        inf.player_no_valid   ||
                        inf.monster_valid     ||
                        inf.MP_valid;

logic[3:0] in_valid_count;
assign in_valid_count = inf.sel_action_valid  +
                 inf.type_valid        +
                 inf.mode_valid        +
                 inf.date_valid        +
                 inf.player_no_valid   +
                 inf.monster_valid     +
                 inf.MP_valid;
            
function automatic int dim(input Month mon);
    case (mon)
      8'd1, 8'd3, 8'd5, 8'd7, 8'd8, 8'd10, 8'd12:  dim = 31;
      8'd4, 8'd6, 8'd9, 8'd11:                     dim = 30;
      8'd2:                                        dim = 28;
      default:                                     dim = 0; // illegal
    endcase
endfunction

function automatic bit is_valid_date(input Month mon, input Day day);
    int dpm;
    dpm = dim(mon);
    if (dpm == 0)                 return 1'b0;  // illegal month
    if (day < 1 || day > dpm)     return 1'b0;  // illegal day
    return 1'b1;
endfunction

// ====================================================================
// ==                          COVER GROUP                           ==
// ====================================================================

// SPEC 1
covergroup cg_type @(posedge clk iff (inf.type_valid));
    option.per_instance = 1;
    option.at_least = 200;
    cp_type : coverpoint inf.D.d_type[0] {
        bins A = {Type_A};
        bins B = {Type_B};
        bins C = {Type_C};
        bins D = {Type_D};
    }
endgroup

// SPEC 2
covergroup cg_mode @(posedge clk iff (inf.mode_valid));
    option.per_instance = 1;
    option.at_least = 200;
    cp_mode : coverpoint inf.D.d_mode[0] {
      bins Easy   = {Easy};
      bins Normal = {Normal};
      bins Hard   = {Hard};
    }
endgroup


//SPEC 3
covergroup cg_type_mode @(posedge clk iff (inf.mode_valid));
    option.per_instance = 1;
    option.at_least = 200;

    cp_type : coverpoint fm_info.f_type;
    cp_mode : coverpoint fm_info.f_mode;
    type_mode_cross : cross cp_type, cp_mode;
endgroup


 

covergroup cg_player_no @(posedge clk iff(inf.player_no_valid));
    option.per_instance = 1;
    option.at_least = 2;
    cp_player_no : coverpoint inf.D.d_player_no[0]{
      option.auto_bin_max = 256;
    }
endgroup

covergroup cg_act_trans @(posedge clk iff (inf.sel_action_valid));
  option.per_instance = 1;
  option.at_least = 200;
  cg_act_trans: coverpoint inf.D.d_act[0]{
    bins act [] = ([Login:Check_Inactive] => [Login:Check_Inactive]);
  }
endgroup

covergroup cg_mp @(posedge clk iff(inf.MP_valid));
  option.per_instance = 1;
  option.at_least = 1;
  cp_mp: coverpoint inf.D.d_attribute[0]{
      option.auto_bin_max = 32;
  }
endgroup

covergroup cg_warn@(posedge clk iff(inf.out_valid));
  option.per_instance = 1;
  option.at_least = 20;
  cp_warn: coverpoint inf.warn_msg{
    bins no_warn    = {No_Warn};
    bins date_warn  = {Date_Warn};
    bins exp_warn   = {Exp_Warn};
    bins hp_warn    = {HP_Warn};
    bins sat_warn   = {Saturation_Warn};
    bins mp_warn    = {MP_Warn};  
  }
endgroup

cg_type      u_cg_type      = new();
cg_mode      u_cg_mode      = new();
cg_type_mode u_cg_type_mode = new();
cg_player_no u_cg_player_no = new();
cg_act_trans u_cg_act_trans = new();
cg_mp        u_cg_mp        = new();
cg_warn      u_cg_warn      = new();

// ====================================================================
// ==                             ASSERTION                          ==
// ====================================================================

logic output_is_zero;
assign output_is_zero = ((!inf.out_valid) &&
      (!inf.warn_msg ) &&
      (!inf.complete ) &&
      (!inf.AR_VALID ) && (!inf.AR_ADDR) &&
      (!inf.R_READY  ) &&
      (!inf.AW_VALID ) && (!inf.AW_ADDR ) &&
      (!inf.W_VALID  ) && (!inf.W_DATA  ) &&
      (!inf.B_READY  ));

property reset_output_shoule_be_zero;
    @(posedge inf.rst_n) 1 |=> output_is_zero;
endproperty

// ================= SPEC 4 =========================
property login_spec2;
    @(posedge clk) inf.sel_action_valid && inf.D.d_act[0] == Login |-> ##[1:4] inf.date_valid  ##[1:4] inf.player_no_valid ##[1:999] inf.out_valid;
endproperty

property level_up_spec2;
    @(posedge clk) inf.sel_action_valid && inf.D.d_act[0] == Level_Up |-> ##[1:4] inf.type_valid  ##[1:4] inf.mode_valid ##[1:4] inf.player_no_valid ##[1:999] inf.out_valid;
endproperty

property battle_spec2;
    @(posedge clk) inf.sel_action_valid && inf.D.d_act[0] == Battle |-> ##[1:4] inf.player_no_valid
    ##[1:4] inf.monster_valid ##[1:4] inf.monster_valid ##[1:4] inf.monster_valid ##[1:999] inf.out_valid;
endproperty

property use_skill_spec2;
    @(posedge clk)inf.sel_action_valid && inf.D.d_act[0] == Use_Skill |-> ##[1:4] inf.player_no_valid
    ##[1:4] inf.MP_valid ##[1:4] inf.MP_valid ##[1:4] inf.MP_valid ##[1:4] inf.MP_valid ##[1:999] inf.out_valid;
endproperty

property check_inactive_spec2;
    @(posedge clk) inf.sel_action_valid && inf.D.d_act[0] == Check_Inactive |-> ##[1:4] inf.date_valid  ##[1:4] inf.player_no_valid ##[1:999] inf.out_valid;
endproperty
// ===================================================

property complete_no_warn;
    @(negedge clk) disable iff (!inf.rst_n)
      inf.complete |-> (inf.warn_msg == No_Warn);
endproperty


// ================= SPEC 4 =========================
property login_gap_check;
    @(posedge clk) inf.sel_action_valid && inf.D.d_act[0] === Login |-> ##[1:4] inf.date_valid  ##[1:4] inf.player_no_valid;
endproperty

property level_up_gap_check;
    @(posedge clk) inf.sel_action_valid && inf.D.d_act[0] === Level_Up |-> ##[1:4] inf.type_valid  ##[1:4] inf.mode_valid ##[1:4] inf.player_no_valid;
endproperty

property battle_gap_check;
    @(posedge clk) inf.sel_action_valid && inf.D.d_act[0] === Battle |-> ##[1:4] inf.player_no_valid
    ##[1:4] inf.monster_valid ##[1:4] inf.monster_valid ##[1:4] inf.monster_valid;
endproperty

property use_skill_gap_check;
    @(posedge clk)inf.sel_action_valid && inf.D.d_act[0] === Use_Skill |-> ##[1:4] inf.player_no_valid
    ##[1:4] inf.MP_valid ##[1:4] inf.MP_valid ##[1:4] inf.MP_valid ##[1:4] inf.MP_valid;
endproperty

property check_inactive_gap_check;
    @(posedge clk) inf.sel_action_valid && inf.D.d_act[0] === Check_Inactive |-> ##[1:4] inf.date_valid  ##[1:4] inf.player_no_valid;
endproperty
// ===================================================

property input_no_overlap;
    @(posedge clk) disable iff (!inf.rst_n)
      !(
        (inf.sel_action_valid && (inf.type_valid   || inf.mode_valid   || inf.date_valid   ||
                                  inf.player_no_valid || inf.monster_valid || inf.MP_valid)) ||
        (inf.type_valid       && (inf.mode_valid   || inf.date_valid   ||
                                  inf.player_no_valid || inf.monster_valid || inf.MP_valid)) ||
        (inf.mode_valid       && (inf.date_valid   ||
                                  inf.player_no_valid || inf.monster_valid || inf.MP_valid)) ||
        (inf.date_valid       && (inf.player_no_valid || inf.monster_valid || inf.MP_valid)) ||
        (inf.player_no_valid  && (inf.monster_valid || inf.MP_valid)) ||
        (inf.monster_valid    &&  inf.MP_valid)
      );
  endproperty

property out_valid_one_cycle;
    @(negedge clk) disable iff (!inf.rst_n)
      inf.out_valid |-> ##1 !inf.out_valid;
endproperty

property next_op_after_out_valid;
    @(negedge clk) disable iff (!inf.rst_n)
      $fell(inf.out_valid) |-> ##[1:4] inf.sel_action_valid;
endproperty

property input_date_legal;
    @(posedge clk) disable iff (!inf.rst_n)
      inf.date_valid |-> is_valid_date(inf.D.d_date[0].M, inf.D.d_date[0].D);
endproperty

property axi_read_write_no_overlap;
  @(posedge clk) !(inf.AR_VALID && inf.AW_VALID);
endproperty

assert property(reset_output_shoule_be_zero) else begin
    $display("Assertion 1 is violated");
    $fatal;
end
assert property(login_spec2) else  begin
    $display("Assertion 2 is violated");
    $fatal;
end
assert property(level_up_spec2) else  begin
    $display("Assertion 2 is violated");
    $fatal;
end
assert property(battle_spec2) else  begin
    $display("Assertion 2 is violated");
    $fatal;
end
assert property(use_skill_spec2) else  begin
    $display("Assertion 2 is violated");
    $fatal;
end
assert property(check_inactive_spec2) else  begin
    $display("Assertion 2 is violated");
    $fatal;
end
assert property(complete_no_warn) else begin
    $display("Assertion 3 is violated");
    $fatal;
end
assert property(login_gap_check) else begin
    $display("Assertion 4 is violated");
    $fatal;
end

assert property(level_up_gap_check) else begin
    $display("Assertion 4 is violated");
    $fatal;
end

assert property(battle_gap_check) else begin
    $display("Assertion 4 is violated");
    $fatal;
end

assert property(use_skill_gap_check) else begin
    $display("Assertion 4 is violated");
    $fatal;
end

assert property(check_inactive_gap_check) else begin
    $display("Assertion 4 is violated");
    $fatal;
end

assert property(input_no_overlap) else begin
    $display("Assertion 5 is violated");
    $fatal;
end
assert property(out_valid_one_cycle) else begin
    $display("Assertion 6 is violated");
    $fatal;
end

assert property(next_op_after_out_valid) else begin
    $display("Assertion 7 is violated");
    $fatal;
end

assert property(input_date_legal) else begin
    $display("Assertion 8 is violated");
    $fatal;
end
assert property(axi_read_write_no_overlap) else begin
    $display("Assertion 9 is violated");
    $fatal;
end
endmodule