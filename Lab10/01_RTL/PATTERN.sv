`timescale 1ns/1ps
`include "Usertype.sv"
parameter PAT_NUM             = 0;
parameter seed                = 1234;
parameter CYCLE_BEFORE_FINISH = 0;
parameter CHECK_DRAM          = 0;
parameter DEBUG               = 0;

program automatic PATTERN(input clk, INF.PATTERN inf);
  import usertype::*;
  parameter int PLAYER_NUM = 256;
  // ---------------------  printer (no SVA) ---------------------
  task automatic SPEC_NO_PASS(input string msg);
    $display("************************************************************");
    $display("                          Wrong Answer !                    ");
    $display("*  %s", msg);
    $display("************************************************************");
    //repeat (CYCLE_BEFORE_FINISH) #(15);
    $finish;
  endtask

  // --------------------- RNG ---------------------
  int seed;
  initial begin
    void'($urandom(seed));
  end
  function int  rand1to4; rand1to4 = $urandom_range(1,3); endfunction
  function int  rand_u16; rand_u16 = $urandom & 16'hffff; endfunction

  // --------------------- DRAM shadow ---------------------
  localparam logic [16:0] DRAM_BASE  = 17'h10000;
  localparam logic [16:0] DRAM_LAST  = 17'h10BFF;                // inclusive

  function automatic int addr2idx(input logic [16:0] a);
    int off;
    int idx;

    off = int'(a) - int'(DRAM_BASE);


    idx = off / 12; // 0..255

    return idx;
  endfunction

  function automatic logic [95:0] pack_player(input Player_Info p);
      logic [7:0] mon8, day8;
      logic [95:0] x;

      mon8 = {4'b0, p.M};         // 8 = 4 + 4
      day8 = {3'b0, p.D};

      x = {p.HP, mon8, day8, p.Attack, p.Defense, p.Exp, p.MP};
      return x;
  endfunction
  function automatic Player_Info unpack_player(input logic [95:0] x);
        Player_Info p;
        logic [15:0] hp, atk, def_, exp_, mp_;
        logic [7:0]  mon8, day8;
        {hp, mon8, day8, atk, def_, exp_, mp_} = x;
        p.HP      = hp;
        p.M       = Month'(mon8);
        p.D       = Day'(day8);
        p.Attack  = atk;
        p.Defense = def_;
        p.Exp     = exp_;
        p.MP      = mp_;
        return p;
    endfunction

  parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
  logic [7:0] golden_DRAM [((65536+12*256)-1):(65536+0)];
  Player_Info shadow_dram [0:PLAYER_NUM-1];
  initial begin
    integer i;
    int base_addr;
    logic [95:0] raw96;

    $readmemh(DRAM_p_r, golden_DRAM);

    for (i = 0; i < PLAYER_NUM; i++) begin
      base_addr = 65536 + i*12;
      raw96 = {
        golden_DRAM[base_addr+11],
        golden_DRAM[base_addr+10],
        golden_DRAM[base_addr+9],
        golden_DRAM[base_addr+8],
        golden_DRAM[base_addr+7],
        golden_DRAM[base_addr+6],
        golden_DRAM[base_addr+5],
        golden_DRAM[base_addr+4],
        golden_DRAM[base_addr+3],
        golden_DRAM[base_addr+2],
        golden_DRAM[base_addr+1],
        golden_DRAM[base_addr+0]
      };

      shadow_dram[i] = unpack_player(raw96);

      if (i < 8) begin
        $display("[INIT] player %0d raw96=%h HP=%h MON=%0d DAY=%0d ATK=%h DEF=%h EXP=%h MP=%h",
                i, raw96,
                shadow_dram[i].HP,
                shadow_dram[i].M,
                shadow_dram[i].D,
                shadow_dram[i].Attack,
                shadow_dram[i].Defense,
                shadow_dram[i].Exp,
                shadow_dram[i].MP);
      end
    end
  end

  // --------------------- Stimulus packers ---------------------
  function automatic Data pack_action(input Action a);
      Data d='0;
      d.d_act[0]=a;
      return d;
  endfunction
  function automatic Data pack_type(input Training_Type t);
      Data d='0;
      d.d_type[0]=t;
      return d;
  endfunction
  function automatic Data pack_mode(input Mode m);
      Data d='0;
      d.d_mode[0]=m;
      return d;
  endfunction
  function automatic Data pack_date(input Month M, input Day D0);
      Data d='0;
      Date dt;
      dt.M=M;
      dt.D=D0;
      d.d_date[0]=dt;
      return d;
  endfunction
  function automatic Data pack_player_no(input Player_No n);
      Data d='0;
      d.d_player_no[0]=n;
      return d;
  endfunction
  function automatic Data pack_attr(input Attribute a);
      Data d='0;
      d.d_attribute[0]=a;
      return d;
  endfunction

  // --------------------- Drive helpers ---------------------
  task automatic gap_1to4();
      repeat (0) @(negedge clk);
  endtask
  task automatic drive_action(input Action a);
     @(negedge clk)
     inf.sel_action_valid = 1;
     inf.D = pack_action(a);
     @(negedge clk)
     inf.sel_action_valid = 0;
     gap_1to4();
  endtask
  task automatic drive_type(input Training_Type t);
     @(negedge clk)
     inf.type_valid = 1;
     inf.D = pack_type(t);
     @(negedge clk)
     inf.type_valid = 0;
     inf.D = 0;
     gap_1to4();
  endtask
  task automatic drive_mode  (input Mode m);
      @(negedge clk)
      inf.mode_valid =1;
      inf.D<=pack_mode(m);
      @(negedge clk) 
      inf.mode_valid = 0;
      inf.D = 0;
      gap_1to4();
  endtask
  task automatic drive_date  (input Month M, input Day D0);
      @(negedge clk)
      inf.date_valid<=1;
      inf.D<=pack_date(M,D0);
      @(negedge clk) 
      inf.date_valid<=0;
      inf.D = 0;
      gap_1to4(); 
  endtask
  task automatic drive_player_no(input Player_No no);
      @(negedge clk)
      inf.player_no_valid = 1;
      inf.D = pack_player_no(no);
      @(negedge clk)
      inf.player_no_valid = 0;
      inf.D = 0;
      gap_1to4();
  endtask
  task automatic drive_monster(input Attribute atk,def_,hp);
    @(negedge clk) begin
      inf.monster_valid = 1;
      inf.D<=pack_attr(atk);
    end
    @(negedge clk)
    inf.monster_valid = 0;
    inf.D = 0;
    gap_1to4();
    @(negedge clk) begin
      inf.monster_valid = 1;
      inf.D<=pack_attr(def_);
    end
    @(negedge clk)
    inf.monster_valid = 0;
    inf.D = 0;
    gap_1to4();
    @(negedge clk) begin
      inf.monster_valid = 1;
      inf.D =pack_attr(hp); 
    end
    @(negedge clk)
    inf.monster_valid = 0;
    inf.D = 0;
  endtask
  task automatic drive_skills(input Attribute s0,s1,s2,s3);
    //repeat(rand1to4()) @(negedge clk)
    @(negedge clk) begin
      inf.MP_valid = 1;
      inf.D = pack_attr(s0);
    end
    @(negedge clk)
    inf.MP_valid = 0;

    //repeat(rand1to4()) @(negedge clk)
    @(negedge clk) begin
      inf.MP_valid = 1;
      inf.D<=pack_attr(s1);
    end
    @(negedge clk)
    inf.MP_valid = 0;

    //repeat(rand1to4()) @(negedge clk)
    @(negedge clk) begin
      inf.MP_valid = 1;
      inf.D = pack_attr(s2);
    end
    @(negedge clk)
    inf.MP_valid = 0;

    //repeat(rand1to4()) @(negedge clk)
    @(negedge clk) begin
      inf.MP_valid = 1;
      inf.D<=pack_attr(s3);
    end
    @(negedge clk)
    inf.MP_valid = 0;
  endtask


  logic [16:0] last_aw_addr, last_ar_addr;
  //always @(posedge clk) if (inf.AW_VALID && inf.AW_READY) last_aw_addr <= inf.AW_ADDR;
  typedef struct packed { bit valid; logic [16:0] addr; logic [95:0] expect_data; } exp_write_t;
  exp_write_t exp_w;
  // ------------------------------------------------------------
  // Helper: days per month (Feb = 28 as in spec)
  // ------------------------------------------------------------
  function automatic int days_in_month(input Month mon);
    case (mon)
      8'd1, 8'd3, 8'd5, 8'd7, 8'd8, 8'd10, 8'd12: days_in_month = 31;
      8'd4, 8'd6, 8'd9, 8'd11:                     days_in_month = 30;
      8'd2:                                       days_in_month = 28;
      default:                                    days_in_month = 0; // illegal month
    endcase
  endfunction

  // ------------------------------------------------------------
  // Helper: convert (Month, Day) -> [0..364]
  //   return -1 if date is illegal.
  //   Used for:
  //     - Login: only to check "consecutive" login (no warning here)
  //     - Check Inactive: to compute date difference (with warning)
  // ------------------------------------------------------------
  function automatic int date_to_index(input Month mon, input Day day);
    int dpm;
    int idx;
    dpm = days_in_month(mon);
    if (dpm == 0) begin
      return -1; // illegal month
    end
    if (day < 1 || day > dpm) begin
      return -1; // illegal day
    end

    // accumulate days of previous months
    idx = 0;
    for (int m = 1; m < mon; m++) begin
      idx += days_in_month(Month'(m[7:0]));
    end
    // zero-based index in this month
    idx += (day - 1);
    return idx; // 0 .. 364
  endfunction

  // ------------------------------------------------------------
  // Helper: saturated add (16-bit, unsigned)
  //   out = min(a + b, 65535)
  //   sat = 1 if saturation occurs
  // ------------------------------------------------------------
  function automatic logic [15:0] sat_add16(
    input logic [15:0] a,
    input int unsigned b,
    output bit sat
  );
    logic [16:0] sum;
    sum = {1'b0, a} + b[16:0];
    if (sum > 17'h0_FFFF) begin
      sat = 1'b1;
      sat_add16 = 16'hFFFF;
    end
    else begin
      sat = 1'b0;
      sat_add16 = sum[15:0];
    end
  endfunction

  // ------------------------------------------------------------
  // Helper: saturated sub (16-bit, unsigned)
  //   out = max(a - b, 0)
  //   sat = 1 if saturation occurs
  // ------------------------------------------------------------

  function automatic logic [15:0] sat_sub16(
        input  logic [15:0] a,
        input  int   unsigned b, 
        output bit   sat
    );
        int unsigned ua, ub;

        ua = a;
        ub = b[15:0];

        if (ub > ua) begin
            sat        = 1'b1;
            sat_sub16  = 16'd0;
        end
        else begin
            sat        = 1'b0;
            sat_sub16  = ua - ub;
        end
  endfunction

  // ------------------------------------------------------------
  // Helper: EXP threshold by mode (Table 2)
  // ------------------------------------------------------------
  function automatic int unsigned exp_need(input Mode md);
    case (md)
      2'b00: exp_need = 4095;   // Easy
      2'b01: exp_need = 16383;  // Normal
      2'b10: exp_need = 32767;  // Hard
      default: exp_need = 0;
    endcase
  endfunction

  function automatic int unsigned adjust_delta_by_mode(
    input Mode md,
    input int unsigned di
  );
    case (md)
      2'b00: adjust_delta_by_mode = di - (di >> 2); // Easy
      2'b01: adjust_delta_by_mode = di;             // Normal
      2'b10: adjust_delta_by_mode = di + (di >> 2); // Hard
      default: adjust_delta_by_mode = di;
    endcase
  endfunction

  // ============================================================
  // Golden functions
  // ============================================================

  function automatic Player_Info calc_golden_login(
    input  Player_Info pre,
    input  Month    mon,
    input  Day      day,
    output Warn_Msg wm,
    output bit      done
  );
    Player_Info post;
    int old_idx, new_idx;
    int diff;
    bit sat_exp, sat_mp;
    bit sat_any;

    post = pre;
    wm   = No_Warn;
    done = 1'b1;

    // Check consecutive login based on old date vs today's date
    old_idx = date_to_index(pre.M, pre.D);
    new_idx = date_to_index(mon,    day);

    if (old_idx >= 0 && new_idx >= 0) begin
      diff = new_idx - old_idx;
      if (diff < 0)
        diff += 365; // wrap around year

      if (diff == 1) begin
        // consecutive login: reward Exp and MP
        post.Exp = sat_add16(pre.Exp, 512,  sat_exp);
        post.MP  = sat_add16(pre.MP,  1024, sat_mp);
        sat_any  = sat_exp | sat_mp;
        if (sat_any) begin
          wm   = Saturation_Warn;
          done = 1'b0; // action not complete when warning appears
        end
      end
    end

    // Always update login date to today's date (spec item 8)
    post.M = mon;
    post.D = day;

    return post;
  endfunction

  task automatic print_player_info(input string tag, input Player_Info p);
    $display("    [%s] MP=%5d  EXP=%5d  HP=%5d  ATK=%5d  DEF=%5d  DATE=%2d/%2d",
            tag, p.MP, p.Exp, p.HP, p.Attack, p.Defense, p.M, p.D);
  endtask

  function automatic Player_Info calc_golden_levelup(
    input  Player_Info      pre,
    input  Training_Type tp,
    input  Mode          md,
    output Warn_Msg      wm,
    output bit           done
  );
    Player_Info post;
    int unsigned d0, d1, d2, d3;
    int unsigned df0, df1, df2, df3;
    bit sat_mp, sat_hp, sat_atk, sat_def;
    bit sat_any;

    // Default: copy all fields
    post = pre;
    wm   = No_Warn;
    done = 1'b1;

    // 1) Check EXP requirement
    if (pre.Exp < exp_need(md)) begin
      wm   = Exp_Warn;
      done = 1'b0;
      return post; // no change
    end


    d0 = 0; d1 = 0; d2 = 0; d3 = 0; // MP, HP, ATK, DEF

    unique case (tp)
      2'b00: begin

        int unsigned sum_attr;
        int unsigned delta;
        sum_attr = pre.MP + pre.HP + pre.Attack + pre.Defense;
        delta    = sum_attr >> 3; // floor( (MP+HP+ATK+DEF) / 8 )
        d0 = delta;
        d1 = delta;
        d2 = delta;
        d3 = delta;
      end

      2'b01: begin
        logic [15:0] small_, big_;
        int unsigned mp, hp, atk, def_;

        mp  = pre.MP;
        hp  = pre.HP;
        atk = pre.Attack;
        def_ = pre.Defense;
        d0 = 0; d1 = 0; d2 = 0; d3 = 0;  // MP, HP, ATK, DEF

        if ((mp  <= atk) && (mp  <= def_) &&
            (hp  <= atk) && (hp  <= def_)) begin

          if (atk <= def_) begin
            small_ = atk;
            big_   = def_;
          end else begin
            small_ = def_;
            big_   = atk;
          end

          if (mp <= hp) begin
            d0 = small_ - mp;   // MP
            d1 = big_   - hp;   // HP
          end else begin
            d1 = small_ - hp;
            d0 = big_   - mp;
          end

        end else if ((mp  <= hp)  &&
                     (mp  <= def_) &&
                     (atk <= hp)  &&
                     (atk <= def_)) begin

          if (hp <= def_) begin
            small_ = hp;
            big_   = def_;
          end else begin
            small_ = def_;
            big_   = hp;
          end

          if (mp <= atk) begin
            d0 = small_ - mp;    // MP
            d2 = big_   - atk;   // ATK
          end else begin
            d2 = small_ - atk;
            d0 = big_   - mp;
          end
        end else if ((mp   <= hp) &&
                     (mp   <= atk) &&
                     (def_ <= hp) &&
                     (def_ <= atk)) begin

          if (hp <= atk) begin
            small_ = hp;
            big_   = atk;
          end else begin
            small_ = atk;
            big_   = hp;
          end

          if (mp <= def_) begin
            d0 = small_ - mp;     // MP
            d3 = big_   - def_;   // DEF
          end else begin
            d3 = small_ - def_;
            d0 = big_   - mp;
          end

        end else if ((hp  <= mp)  &&
                     (hp  <= def_) &&
                     (atk <= mp)  &&
                     (atk <= def_)) begin

          if (mp <= def_) begin
            small_ = mp;
            big_   = def_;
          end else begin
            small_ = def_;
            big_   = mp;
          end

          if (hp <= atk) begin
            d1 = small_ - hp;    // HP
            d2 = big_   - atk;   // ATK
          end else begin
            d2 = small_ - atk;
            d1 = big_   - hp;
          end

        end else if ((hp   <= mp) &&
                     (hp   <= atk) &&
                     (def_ <= mp) &&
                     (def_ <= atk)) begin

          if (mp <= atk) begin
            small_ = mp;
            big_   = atk;
          end else begin
            small_ = atk;
            big_   = mp;
          end

          if (hp <= def_) begin
            d1 = small_ - hp;     // HP
            d3 = big_   - def_;   // DEF
          end else begin
            d3 = small_ - def_;
            d1 = big_   - hp;
          end
        end else begin

          if (mp <= hp) begin
            small_ = mp;
            big_   = hp;
          end else begin
            small_ = hp;
            big_   = mp;
          end

          if (atk <= def_) begin
            d2 = small_ - atk;    // ATK
            d3 = big_   - def_;   // DEF
          end else begin
            d3 = small_ - def_;
            d2 = big_   - atk;
          end
        end
      end

      2'b10: begin
        if (pre.MP  < 16'd16383) d0 = 16'd16383 - pre.MP;  else d0 = 0;
        if (pre.HP  < 16'd16383) d1 = 16'd16383 - pre.HP;  else d1 = 0;
        if (pre.Attack < 16'd16383) d2 = 16'd16383 - pre.Attack; else d2 = 0;
        if (pre.Defense < 16'd16383) d3 = 16'd16383 - pre.Defense; else d3 = 0;
      end

      2'b11: begin
        int unsigned base0, base1, base2, base3;
        base0 = 3000 + ((16'hFFFF - pre.MP)  >> 4);
        base1 = 3000 + ((16'hFFFF - pre.HP)  >> 4);
        base2 = 3000 + ((16'hFFFF - pre.Attack) >> 4);
        base3 = 3000 + ((16'hFFFF - pre.Defense) >> 4);

        d0 = (base0 > 5047) ? 5047 : base0;
        d1 = (base1 > 5047) ? 5047 : base1;
        d2 = (base2 > 5047) ? 5047 : base2;
        d3 = (base3 > 5047) ? 5047 : base3;
      end

      default: begin
        d0 = 0; d1 = 0; d2 = 0; d3 = 0;
      end
    endcase

    df0 = adjust_delta_by_mode(md, d0);
    df1 = adjust_delta_by_mode(md, d1);
    df2 = adjust_delta_by_mode(md, d2);
    df3 = adjust_delta_by_mode(md, d3);

    // 4) Saturated update of attributes
    post.MP  = sat_add16(pre.MP,  df0, sat_mp);
    post.HP  = sat_add16(pre.HP,  df1, sat_hp);
    post.Attack = sat_add16(pre.Attack, df2, sat_atk);
    post.Defense = sat_add16(pre.Defense, df3, sat_def);

    sat_any = sat_mp | sat_hp | sat_atk | sat_def;
    if (sat_any) begin
      wm   = Saturation_Warn;
      done = 1'b0;
    end

    return post;
  endfunction


   function automatic Player_Info calc_golden_battle(
    input  Player_Info pre,
    input  Attribute atk_m,   // monster ATK
    input  Attribute def_m,   // monster DEF
    input  Attribute hp_m,    // monster HP
    output Warn_Msg wm,
    output bit      done
  );
    Player_Info post;
    int damage_to_player;
    int damage_to_monster;
    int player_hp_temp;
    int monster_hp_temp;

    // saturation flags for each field
    bit sat_exp, sat_mp, sat_hp, sat_atk, sat_def;
    bit sat_any;

    post = pre;
    wm   = No_Warn;
    done = 1'b1;

    // 1) Insufficient HP before battle
    if (pre.HP == 16'd0) begin
      wm   = HP_Warn;
      done = 1'b0;
      return post;
    end

    // 2) Compute damage
    damage_to_player  = int'(atk_m) - int'(pre.Defense);
    damage_to_monster = int'(pre.Attack) - int'(def_m);
    if(DEBUG) $display("[DBG] damage_to_player=%0d damage_to_monster=%0d", damage_to_player, damage_to_monster);
    // 3) Temporary HP based on damage (Table 5 style)
    if (damage_to_player > 0)
      player_hp_temp = int'(pre.HP) - damage_to_player;
    else
      player_hp_temp = int'(pre.HP);

    if (damage_to_monster > 0)
      monster_hp_temp = int'(hp_m) - damage_to_monster;
    else
      monster_hp_temp = int'(hp_m);
    if(DEBUG) $display("[DBG] player_hp_temp=%0d monster_hp_temp=%0d", player_hp_temp, monster_hp_temp);

    // 4) Decide result and raw updates
    if ((player_hp_temp  > 0) && (monster_hp_temp <= 0)) begin
      // ---------------- Win case ----------------
      // EXP += 2048, MP += 2048 (saturated)
      post.Exp = sat_add16(pre.Exp, 2048, sat_exp);
      post.MP  = sat_add16(pre.MP,  2048, sat_mp);

      // HP is clamped into [0,65535] (should normally be >=0 here)
      if (player_hp_temp < 0)        post.HP = 0;
      else if (player_hp_temp > 65535) post.HP = 65535;
      else                           post.HP = player_hp_temp[15:0];

      post.Attack = pre.Attack;
      post.Defense = pre.Defense;

      sat_hp  = (player_hp_temp < 0) || (player_hp_temp > 65535);
      sat_atk = 1'b0;
      sat_def = 1'b0;

    end
    else if (player_hp_temp <= 0) begin
      // ---------------- Loss case ----------------
      // HP is forced to 0
      post.HP = 16'd0;

      // EXP/ATK/DEF are reduced by 2048 (saturated at 0)
      post.Exp = sat_sub16(pre.Exp, 2048, sat_exp);
      post.Attack = sat_sub16(pre.Attack, 2048, sat_atk);
      post.Defense = sat_sub16(pre.Defense, 2048, sat_def);

      // MP unchanged on Loss
      post.MP  = pre.MP;
      sat_mp   = 1'b0;
      sat_hp   = 1'b0; // exact value 0 is always in range

    end
    else begin
      // ---------------- Tie case ----------------
      // Both HP_temp > 0
      if (player_hp_temp < 0)        post.HP = 16'd0;
      else if (player_hp_temp > 65535) post.HP = 65535;
      else                           post.HP = player_hp_temp[15:0];

      post.Exp = pre.Exp;
      post.MP  = pre.MP;
      post.Attack = pre.Attack;
      post.Defense = pre.Defense;

      sat_exp = 1'b0;
      sat_mp  = 1'b0;
      sat_atk = 1'b0;
      sat_def = 1'b0;
      sat_hp  = (player_hp_temp < 0) || (player_hp_temp > 65535);
    end

    // 5) If any field hit saturation boundary, raise Saturation_Warn
    sat_any = sat_exp | sat_mp | sat_hp | sat_atk | sat_def;
    if (sat_any) begin
      wm   = Saturation_Warn;
      done = 1'b0;
    end
    if(DEBUG) $display("[DBG] player's HP = %d", post.HP);

    return post;
  endfunction

  function automatic Player_Info calc_golden_skill(
    input  Player_Info pre,
    input  Attribute s0,
    input  Attribute s1,
    input  Attribute s2,
    input  Attribute s3,
    output Warn_Msg wm,
    output bit      done
  );
    Player_Info post;
    int unsigned cost        [4];
    int unsigned sorted_cost [4];
    int          idx         [4];
    int          sorted_idx  [4];
    bit          used        [4];

    int unsigned mp_u;
    int unsigned total_cost;
    int          used_cnt;
    bit          sat_mp;

    post = pre;
    wm   = No_Warn;
    done = 1'b1;

    cost[0] = s0;
    cost[1] = s1;
    cost[2] = s2;
    cost[3] = s3;
    if(DEBUG) $display("[DBG] pre.MP=%0d", pre.MP);
    if(DEBUG) $display("[DBG] s0=%0d s1=%0d s2=%0d s3=%0d", s0, s1, s2, s3);
    for (int i = 0; i < 4; i++) begin
      sorted_cost[i] = cost[i];
      sorted_idx[i]  = i;
      used[i]        = 1'b0;
    end

    mp_u = pre.MP;

    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 3 - i; j++) begin
        if (sorted_cost[j] > sorted_cost[j+1]) begin
          int unsigned tmpc;
          int          tmpi;

          tmpc              = sorted_cost[j];
          sorted_cost[j]    = sorted_cost[j+1];
          sorted_cost[j+1]  = tmpc;

          tmpi              = sorted_idx[j];
          sorted_idx[j]     = sorted_idx[j+1];
          sorted_idx[j+1]   = tmpi;
        end
      end
    end
    for (int k = 0; k < 4; k++) begin
      if(DEBUG) $display("[DBG] k=%0d sorted_cost=%0d sorted_idx=%0d used_flag=%0b",
              k, sorted_cost[k], sorted_idx[k], used[sorted_idx[k]]);
    end

    total_cost = 0;
    used_cnt   = 0;

    for (int k = 0; k < 4; k++) begin
      if (total_cost + sorted_cost[k] <= mp_u) begin
        total_cost              += sorted_cost[k];
        used[ sorted_idx[k] ]    = 1'b1;
        used_cnt++;
        if(DEBUG) $display("%d used", k);
      end
    end
    if(DEBUG) $display("[DBG] total_cost=%0d used_cnt=%0d", total_cost, used_cnt);

    //post.MP = sat_sub16(pre.MP, total_cost, sat_mp);
    if(DEBUG) $display("[DBG] sat_sub16: a=%0d b=%0d -> post.MP=%0d sat_mp=%0b",
            pre.MP, total_cost, post.MP, sat_mp);

    if (used_cnt == 0) begin
      wm   = MP_Warn;
      done = 1'b0;
      return post;
    end
    post.MP = sat_sub16(pre.MP, total_cost, sat_mp);

    if (sat_mp) begin
      wm   = Saturation_Warn;
      done = 1'b0;
    end
    return post;
  endfunction


  function automatic Player_Info calc_golden_inactive(
    input  Player_Info pre,
    input  Month    mon,
    input  Day      day,
    output Warn_Msg wm,
    output bit      done
  );
    Player_Info post;
    int last_idx, today_idx;
    int diff;

    post = pre;
    wm   = No_Warn;
    done = 1'b1;

    last_idx  = date_to_index(pre.M, pre.D);
    today_idx = date_to_index(mon,     day);

    // illegal date -> Date_Warn
    if (last_idx < 0 || today_idx < 0) begin
      wm   = Date_Warn;
      done = 1'b0;
      return post;
    end

    // compute difference with wrap (365 days calendar)
    diff = today_idx - last_idx;
    if (diff < 0)
      diff += 365;

    if (diff > 90) begin
      wm   = Date_Warn;
      done = 1'b0;
    end

    return post;
  endfunction


  Player_No cur_pno; Month cur_mon; Day cur_day;
  Training_Type cur_type; Mode cur_mode;
  Attribute cur_atk,cur_def,cur_hp,cur_s0,cur_s1,cur_s2,cur_s3;

  function automatic logic [16:0] player_addr_from_no(input Player_No no);
    return DRAM_BASE + (no * 12);
  endfunction


  task automatic wait_out_and_check(input Action act);
    int i;
    bit seen_out = 1'b0;
    Warn_Msg golden_w; 
    bit      golden_c;
    Player_Info pre, post;
    logic [16:0] paddr = player_addr_from_no(cur_pno);
    string act_name;


    unique case (act)
      Login        :   act_name = "Login";
      Level_Up     :   act_name = "Level_Up";
      Battle       :   act_name = "Battle";
      Use_Skill    :   act_name = "Use_Skill";
      Check_Inactive:  act_name = "Check_Inactive";
      default      :   act_name = "Unknown";
    endcase

    pre = shadow_dram[addr2idx(paddr)];

    unique case (act)
      Login: begin
        post = calc_golden_login(pre, cur_mon, cur_day, golden_w, golden_c);
      end
      Level_Up: begin
        post = calc_golden_levelup(pre, cur_type, cur_mode, golden_w, golden_c);
      end
      Battle: begin
        post = calc_golden_battle(pre, cur_atk, cur_def, cur_hp, golden_w, golden_c);
      end
      Use_Skill: begin
        post = calc_golden_skill(pre, cur_s0, cur_s1, cur_s2, cur_s3, golden_w, golden_c);
      end
      Check_Inactive: begin
        post = calc_golden_inactive(pre, cur_mon, cur_day, golden_w, golden_c);
      end
      default: SPEC_NO_PASS("Unknown action in wait_out_and_check.");
    endcase

    for (i=0;i<1000;i++) begin
      @(negedge clk);

      if (inf.out_valid && (inf.sel_action_valid || inf.type_valid || inf.mode_valid ||
                            inf.date_valid || inf.player_no_valid || inf.monster_valid || inf.MP_valid)) begin
        SPEC_NO_PASS("out_valid must not overlap with any input valid.");
      end

      if(inf.W_VALID === 1 && inf.W_READY === 1 && CHECK_DRAM) begin
        Player_Info exp_p, got_p;
        int      idx;

        idx   = addr2idx(paddr);
        //exp_p = shadow_dram[idx];
        exp_p = post;

        if (inf.W_DATA !== pack_player(exp_p)) begin
          got_p = unpack_player(inf.W_DATA);

          $display("--------------------------------------------------");
          $display("[WRITE MISMATCH] addr=%h (idx=%0d)", paddr, idx);
          $display("  GOT RAW : %h", inf.W_DATA);

          $display("  Compare (GOLDEN vs DUT):");
          $display("    FIELD      GOLDEN        DUT");
          $display("    MP      %8d   %8d", exp_p.MP     , got_p.MP     );
          $display("    EXP     %8d   %8d", exp_p.Exp    , got_p.Exp    );
          $display("    HP      %8d   %8d", exp_p.HP     , got_p.HP     );
          $display("    ATK     %8d   %8d", exp_p.Attack , got_p.Attack );
          $display("    DEF     %8d   %8d", exp_p.Defense, got_p.Defense);
          $display("    MON     %8d   %8d", exp_p.M      , got_p.M      );
          $display("    DAY     %8d   %8d", exp_p.D      , got_p.D      );

          SPEC_NO_PASS($sformatf("@ time = %0t, AXI write mismatch! addr=%h",
                              $time, paddr));
        end
      end

      if (inf.out_valid) begin
        seen_out = 1'b1;

        //@(negedge clk);

        if(DEBUG) $display("==================================================");
        if(DEBUG) $display("[GOLDEN CHECK] time=%0t  action=%s", $time, act_name);
        if(DEBUG) $display("  Player_No = %0d  DRAM_addr = %h", cur_pno, paddr);

        unique case (act)
          Login: begin
            if(DEBUG) $display("  Input : Login  date = %0d/%0d", cur_mon, cur_day);
          end
          Level_Up: begin
            if(DEBUG) $display("  Input : Level_Up  type=%0d  mode=%0d", cur_type, cur_mode);
          end
          Battle: begin
            if(DEBUG) $display("  Input : Battle  monster_ATK=%0d  DEF=%0d  HP=%0d",
                     cur_atk, cur_def, cur_hp);
          end
          Use_Skill: begin
            if(DEBUG) $display("  Input : Use_Skill  s0=%0d  s1=%0d  s2=%0d  s3=%0d",
                     cur_s0, cur_s1, cur_s2, cur_s3);
          end
          Check_Inactive: begin
            if(DEBUG) $display("  Input : Check_Inactive  date = %0d/%0d", cur_mon, cur_day);
          end
          default: begin
            if(DEBUG) $display("  Input : (unknown action)");
          end
        endcase

        if(DEBUG) $display("  Player Info:");
        if(DEBUG) print_player_info("BEFORE", pre);
        if(DEBUG) print_player_info("AFTER ", post);

        if(DEBUG) $display("  Result: complete=%0d  warn_msg=%0d", golden_c, golden_w);
        if(DEBUG) $display("==================================================");

        if (inf.complete !== golden_c || inf.warn_msg !== golden_w) begin
          SPEC_NO_PASS($sformatf("Output mismatch: expect {complete=%0d,warn=%0d} got {complete=%0d,warn=%0d}",
                    golden_c, golden_w, inf.complete, inf.warn_msg));
        end

        shadow_dram[addr2idx(paddr)] = post;
        exp_w.valid        = 1'b1;
        exp_w.addr         = paddr;
        exp_w.expect_data  = pack_player(post);
        return;
      end
    end
    if (!seen_out) SPEC_NO_PASS("Latency exceeds 1000 cycles without out_valid.");
  endtask

  // --------------------- Scenarios ---------------------
  task automatic do_login(input Player_No no, input Month mon, input Day day);
    cur_pno=no; cur_mon=mon; cur_day=day;
    drive_action(Login);
    drive_date(mon, day);
    drive_player_no(no);
    wait_out_and_check(Login);
  endtask

  task automatic do_levelup(input Player_No no, input Training_Type tp, input Mode md);
    cur_pno=no; cur_type=tp; cur_mode=md;
    drive_action(Level_Up);
    drive_type(tp);
    drive_mode(md);
    drive_player_no(no);
    wait_out_and_check(Level_Up);
  endtask

  task automatic do_battle(input Player_No no, input Attribute atk, input Attribute def_, input Attribute hp);
    cur_pno=no; cur_atk=atk; cur_def=def_; cur_hp=hp;
    drive_action(Battle);
    drive_player_no(no);
    drive_monster(atk,def_,hp);
    wait_out_and_check(Battle);
  endtask

  task automatic do_skill(input Player_No no, input Attribute s0,input Attribute s1,input Attribute s2,input Attribute s3);
    cur_pno=no; cur_s0=s0; cur_s1=s1; cur_s2=s2; cur_s3=s3;
    drive_action(Use_Skill);
    drive_player_no(no);
    drive_skills(s0,s1,s2,s3);
    wait_out_and_check(Use_Skill);
  endtask

  task automatic do_check_inactive(input Player_No no, input Month mon, input Day day);
    cur_pno=no; cur_mon=mon; cur_day=day;
    drive_action(Check_Inactive);
    drive_date(mon, day);
    drive_player_no(no);
    wait_out_and_check(Check_Inactive);
  endtask

  task reset_task; begin 
      #(0.5);
      inf.rst_n=0;
      #(100);
      if (inf.out_valid !== 1'b0 || inf.complete !== 1'b0 || inf.warn_msg !== No_Warn ||
          inf.AR_VALID !== 1'b0 || inf.AR_ADDR!=='0 || inf.R_READY !== 1'b0 ||
          inf.AW_VALID !== 1'b0 || inf.AW_ADDR!=='0 || inf.W_VALID  !== 1'b0 ||
          inf.W_DATA  !== '0   || inf.B_READY !== 1'b0) begin
        SPEC_NO_PASS("Outputs/AXI master signals must be zero during reset.");
      end    
      inf.rst_n=1;
  end 
  endtask

  task do_something(input Action act, input Player_No pno);
    Month mon; Day day;
    Training_Type tp; Mode md;
    Attribute atk, def_, hp;
    Attribute s0, s1, s2, s3;

    case (act)
      Login: begin
        mon = Month'($urandom_range(1, 12));
        day = Day'($urandom_range(1, days_in_month(mon)));
        do_login(pno, mon, day);
      end

      Level_Up: begin
        tp = Training_Type'($urandom_range(0,3));
        md = Mode'($urandom_range(0,2));
        do_levelup(pno, tp, md);
      end

      Battle: begin
        atk = Attribute'(rand_u16());
        def_= Attribute'(rand_u16());
        hp  = Attribute'(rand_u16());
        do_battle(pno, atk, def_, hp);
      end

      Use_Skill: begin
        s0 = Attribute'(rand_u16());
        s1 = Attribute'(rand_u16());
        s2 = Attribute'(rand_u16());
        s3 = Attribute'(rand_u16());
        do_skill(pno, s0, s1, s2, s3);
      end

      Check_Inactive: begin
        mon = Month'($urandom_range(1, 12));
        day = Day'($urandom_range(1, days_in_month(mon)));
        do_check_inactive(pno, mon, day);
      end
    endcase
  endtask

  // --------------------- MAIN ---------------------
  initial begin : MAIN
    integer pat_num;
    integer latency, total_latency;
    integer rep, idx;

    integer lvlup_cnt;

    Player_No pno_seq;
    Month     month;
    Day       day;
    Attribute a0, a1, a2, a3;

    static Training_Type all_type [4] = '{Type_A, Type_B, Type_C, Type_D};
    static Mode          all_mode [3] = '{Easy, Normal, Hard};

    localparam int ACT_LEVEL_UP       = 0;
    localparam int ACT_LOGIN          = 1;
    localparam int ACT_BATTLE         = 2;
    localparam int ACT_USE_SKILL      = 3;
    localparam int ACT_CHECK_INACTIVE = 4;

    const int base_seq [0:31] = '{
      ACT_LEVEL_UP,       //  0
      ACT_CHECK_INACTIVE, //  4
      ACT_CHECK_INACTIVE, //  4
      ACT_USE_SKILL,      //  3
      ACT_CHECK_INACTIVE, //  4
      ACT_BATTLE,         //  2
      ACT_CHECK_INACTIVE, //  4
      ACT_LOGIN,          //  1
      ACT_CHECK_INACTIVE, //  4
      ACT_LEVEL_UP,       //  0
      ACT_USE_SKILL,      //  3
      ACT_USE_SKILL,      //  3
      ACT_BATTLE,         //  2
      ACT_USE_SKILL,      //  3
      ACT_LOGIN,          //  1
      ACT_USE_SKILL,      //  3
      ACT_LEVEL_UP,       //  0
      ACT_BATTLE,         //  2
      ACT_BATTLE,         //  2
      ACT_LOGIN,
      ACT_BATTLE,
      ACT_LEVEL_UP,
      ACT_LOGIN,
      ACT_LOGIN,
      ACT_LEVEL_UP,
      ACT_LEVEL_UP,
      ACT_LEVEL_UP,
      ACT_LEVEL_UP,
      ACT_LEVEL_UP,
      ACT_LEVEL_UP,
      ACT_LEVEL_UP,
      ACT_LEVEL_UP
    };

    pat_num       = 0;
    latency       = 0;
    total_latency = 0;
    lvlup_cnt     = 0;

    inf.rst_n           = 1'b1;
    inf.sel_action_valid= 1'b0;
    inf.type_valid      = 1'b0;
    inf.mode_valid      = 1'b0;
    inf.date_valid      = 1'b0;
    inf.player_no_valid = 1'b0;
    inf.monster_valid   = 1'b0;
    inf.MP_valid        = 1'b0;
    inf.D               = '0;

    // reset
    reset_task;

    // ===============================================================
    // ==                     Coverage Map                          ==
    // ===============================================================
    for (rep = 0; rep < 200; rep = rep + 1) begin
      for (idx = 0; idx < 32; idx = idx + 1) begin
        pno_seq = Player_No'(pat_num % 256);
        case (base_seq[idx])
          ACT_LEVEL_UP: begin
            int c;
            Training_Type t;
            Mode          m;
            c = lvlup_cnt % 12;
            t = all_type[c / 3];
            m = all_mode[c % 3];
            lvlup_cnt = lvlup_cnt + 1;

            do_levelup(pno_seq, t, m);
          end

          // ---------------------- Login ----------------------
          ACT_LOGIN: begin
            month = Month'($urandom_range(1, 12));
            day   = Day'  ($urandom_range(1, days_in_month(month)));
            do_login(pno_seq, month, day);
          end

          // --------------------- Battle ----------------------
          ACT_BATTLE: begin
            a0 = Attribute'(rand_u16());
            a1 = Attribute'(rand_u16());
            a2 = Attribute'(rand_u16());
            do_battle(pno_seq, a0, a1, a2);
          end

          // ------------------- Use_Skill ---------------------
          ACT_USE_SKILL: begin
            a0 = Attribute'(rand_u16());
            a1 = Attribute'(rand_u16());
            a2 = Attribute'(rand_u16());
            a3 = Attribute'(rand_u16());
            do_skill(pno_seq, a0, a1, a2, a3);
          end

          // ----------------- Check_Inactive ------------------
          ACT_CHECK_INACTIVE: begin
            month = Month'($urandom_range(1, 12));
            day   = Day'  ($urandom_range(1, days_in_month(month)));
            do_check_inactive(pno_seq, month, day);
          end

        endcase

        $display("\033[32mPATTERN %0d PASS\033[0m", pat_num);
        pat_num = pat_num + 1;
      end
    end

    $display("Total patterns = %0d (expected 6400)", pat_num);

    // ===============================================================
    // ===============        random cases     =======================
    // ===============================================================
    /*
    integer who, m_int, d_int;
    for (i = 0; i < PAT_NUM; i = i + 1) begin
      who   = $urandom_range(0,255);
      m_int = $urandom_range(1, 12);
      d_int = $urandom_range(1, days_in_month(m_int));
      case ($urandom_range(0,4))
        0: do_login(Player_No'(who[7:0]), Month'(m_int), Day'(d_int));
        1: do_levelup(Player_No'(who[7:0]),
                      Training_Type'($urandom_range(0,3)),
                      Mode'($urandom_range(0,2)));
        2: do_battle(Player_No'(who[7:0]),
                     Attribute'(rand_u16()),
                     Attribute'(rand_u16()),
                     Attribute'(rand_u16()));
        3: do_skill(Player_No'(who[7:0]),
                    Attribute'(rand_u16()),
                    Attribute'(rand_u16()),
                    Attribute'(rand_u16()),
                    Attribute'(rand_u16()));
        4: do_check_inactive(Player_No'(who[7:0]),
                             Month'(m_int), Day'(d_int));
      endcase
      $display("\033[32mPATTERN %0d PASS\033[0m", pat_num);
      pat_num = pat_num + 1;
    end
    */

    $display("************************************************************");
    $display("                        Congratulations !                   ");
    $display("************************************************************");
    //repeat(CYCLE_BEFORE_FINISH) #(CYCLE);
    $finish;
  end

endprogram
