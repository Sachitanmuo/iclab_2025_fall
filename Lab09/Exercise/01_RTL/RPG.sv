//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : RPG.sv
//   	Module Name : RPG
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module RPG(
    input clk,
    INF.RPG_inf inf
);

    // ==============================================
    //               PARAMETER & INT
    // ==============================================
    parameter IDLE           = 4'd0,
              IN_LOGIN       = 4'd1,
              IN_LEVEL_UP    = 4'd2,
              IN_BATTLE      = 4'd3,
              IN_USE_SKILL   = 4'd4,
              IN_CHECK_ACT   = 4'd5,
              AXI            = 4'd6,  
              OUTPUT         = 4'd7,
              LOGIN          = 4'd8,
              LEVEL_UP       = 4'd9,
              BATTLE         = 4'd10,
              USE_SKILL      = 4'd11,
              CHECK_ACT      = 4'd12,
              CALC_DELTA     = 4'd13,
              SORT           = 4'd14;
    
    parameter AXI_IDLE       = 3'd0,
              AXI_R          = 3'd1,
              AXI_AR         = 3'd2,
              AXI_W          = 3'd3,
              AXI_AW         = 3'd4,
              AXI_B          = 3'd5;

    parameter DRAM_BASE      = 17'h10000;


    integer i, j;
    // ==============================================
    //                  REG & WIRE
    // ==============================================
    wire        rst_n           = inf.rst_n;
    wire        sel_action_valid= inf.sel_action_valid;
    wire        type_valid      = inf.type_valid;
    wire        mode_valid      = inf.mode_valid;
    wire        date_valid      = inf.date_valid;
    wire        player_no_valid = inf.player_no_valid;
    wire        monster_valid   = inf.monster_valid;
    wire        MP_valid        = inf.MP_valid;
    Data        D_in            = inf.D;
         

    reg         out_valid_n;
    Warn_Msg    warn_msg_n;
    Warn_Msg    warn_msg_reg;
    reg         complete_n;
    reg         complete_reg;

    reg         AR_VALID_n;
    reg [16:0]  AR_ADDR_n;
    reg         R_READY_n;
    reg         AW_VALID_n;
    reg [16:0]  AW_ADDR_n;
    reg         W_VALID_n;
    reg [95:0]  W_DATA_n;
    reg         B_READY_n;
    Action      ACT, ACT_n;
    Date        dt, dt_n;
    Player_Info p_info, p_info_n;
    Player_Info updated_info, updated_info_n;
    Player_No   player_idx, player_idx_n;
    Mode        md, md_n;
    Training_Type tp, tp_n;

    Attribute mon_atk,  mon_atk_n;
    Attribute mon_def,  mon_def_n;
    Attribute mon_hp,   mon_hp_n;
    reg [1:0] mon_cnt,  mon_cnt_n;

    reg [17:0] skill      [0:3];
    reg [17:0] skill_n    [0:3];
    reg [1:0] order   [0:3];
    reg [1:0] order_n [0:3];
    reg [2:0] type_b_cnt, type_b_cnt_n;
    reg [2:0] skill_cnt, skill_cnt_n;

    reg [3:0] cs;
    reg [3:0] ns;

    reg [2:0] axi_cs;
    reg [2:0] axi_ns;
    reg burst_write;
    reg [15:0] delta_MP, delta_MP_n;
    reg [15:0] delta_HP, delta_HP_n;
    reg [15:0] delta_ATK, delta_ATK_n;
    reg [15:0] delta_DEF, delta_DEF_n;


    reg has_player_info, has_player_info_n;

    // ==============================================
    //                  FUNCTION
    // ==============================================
    function automatic Player_Info unpack_player_info(input logic [95:0] x);
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

    function automatic logic [95:0] pack_player_info(input Player_Info p);
        logic [7:0] mon8, day8;
        logic [95:0] x;
        mon8 = logic'(p.M); 
        day8 = logic'(p.D);
        x = {p.HP, mon8, day8, p.Attack, p.Defense, p.Exp, p.MP};
        return x;
    endfunction

    function automatic logic [16:0] to_addr(input Player_No no);
        return 17'h10000 | (no * 12);
    endfunction

    function automatic reg [4:0] days_in_month(input Month mon);
        case (mon)
            8'd1, 8'd3, 8'd5, 8'd7, 8'd8, 8'd10, 8'd12:  days_in_month = 31;
            8'd4, 8'd6, 8'd9, 8'd11:                     days_in_month = 30;
            8'd2:                                        days_in_month = 28;
            default:                                     days_in_month = 0;
        endcase
    endfunction

    function automatic reg signed [9:0] dti(input Month mon, input Day day);
        reg [4:0] dpm;
        reg signed [9:0] idx;
        dpm = days_in_month(mon);
        if (dpm == 0)       return -1;
        if (day < 1 || day > dpm) return -1;

        idx = 0;
        /*
        for (int m = 1; m < mon; m++) begin
            idx += days_in_month(Month'(m[7:0]));
        end
        idx += (day - 1);
        */
        case (mon)
             1: idx =       day;
             2: idx =  31 + day;
             3: idx =  59 + day;
             4: idx =  90 + day;
             5: idx = 120 + day;
             6: idx = 151 + day;
             7: idx = 181 + day;
             8: idx = 212 + day;
             9: idx = 243 + day;
            10: idx = 273 + day;
            11: idx = 304 + day;
            12: idx = 334 + day;
            default: idx = 0;
        endcase   
        return idx;
    endfunction

    function automatic logic [15:0] check_add_saturation(
        input logic [15:0] a,
        input int unsigned b,
        output bit         sat
    );
        logic [16:0] sum;
        sum = {1'b0, a} + b[16:0];
        if (sum > 17'h0_FFFF) begin
            sat       = 1'b1;
            check_add_saturation = 16'hFFFF;
        end
        else begin
            sat       = 1'b0;
            check_add_saturation = sum[15:0];
        end
    endfunction

    function automatic logic [15:0] check_sub_saturation(
        input  logic [15:0] a,
        input  int   unsigned b, 
        output bit   sat
    );
        int unsigned ua, ub;

        ua = a;
        ub = b[15:0];

        if (ub > ua) begin
            sat        = 1'b1;
            check_sub_saturation  = 16'd0;
        end
        else begin
            sat        = 1'b0;
            check_sub_saturation  = ua - ub;
        end
    endfunction
    

    // ==============================================
    //               FSM
    // ==============================================
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cs <= IDLE;
        end else begin
            cs <= ns;
        end
    end

    always_comb begin : FSM
        ns = cs;
        case (cs)
            IDLE: begin
                if(inf.sel_action_valid) begin
                    case (inf.D.d_act[0])
                        Login:             ns = IN_LOGIN;
                        Level_Up:          ns = IN_LEVEL_UP;
                        Battle:            ns = IN_BATTLE;
                        Use_Skill:         ns = IN_USE_SKILL;
                        Check_Inactive:    ns = IN_CHECK_ACT;
                    endcase
                end else begin
                    ns = cs;
                end
            end
            IN_LOGIN: begin
                if(inf.player_no_valid) begin
                    ns = LOGIN;
                end else begin
                    ns = cs;
                end
            end
            IN_LEVEL_UP: begin
               if(inf.player_no_valid) begin
                    ns = CALC_DELTA;
               end else begin
                    ns = cs;
               end
            end
            IN_BATTLE: begin
                if(mon_cnt == 3) begin
                    ns = BATTLE;
                end else begin
                    ns = cs;
                end
            end
            IN_USE_SKILL: begin
                if(skill_cnt == 4) begin
                    ns = SORT;
                end else begin
                    ns = cs;
                end
            end

            IN_CHECK_ACT: begin
                if(inf.player_no_valid) begin
                    ns = CHECK_ACT;
                end else begin
                    ns = cs;
                end
            end
            SORT: begin
                ns = USE_SKILL;
            end
            LOGIN: begin
                if(has_player_info) begin
                    ns = AXI;
                end else begin
                    ns = cs;
                end
            end
            LEVEL_UP: begin
                if(has_player_info) begin
                    ns = AXI;
                end else begin
                    ns = cs;
                end
            end
            BATTLE: begin
                if(has_player_info) begin
                    ns = AXI;
                end else begin
                    ns = cs;
                end
            end
            USE_SKILL: begin
                if(has_player_info) begin
                    ns = AXI;
                end else begin
                    ns = cs;
                end
            end
            CHECK_ACT: begin
                if(has_player_info) begin
                    ns = IDLE;
                end else begin
                    ns = cs;
                end
            end
            CALC_DELTA: begin
                if(has_player_info && tp != Type_B) begin
                    ns = LEVEL_UP;
                end else if(has_player_info && type_b_cnt == 3) begin
                    ns = LEVEL_UP;
                end else begin
                    ns = cs;
                end
            end
            AXI: begin
                if(inf.B_VALID && inf.B_READY) begin
                    ns = IDLE;
                end else begin
                    ns = cs;
                end
            end
        endcase
    end

    // ==============================================
    //               AXI FSM
    // ==============================================
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            axi_cs <= AXI_IDLE;
        end else begin
            axi_cs <= axi_ns;
        end
    end

    always_comb begin : AXI_FSM
        axi_ns = axi_cs;
        case (axi_cs)
            AXI_IDLE: begin
                if(inf.player_no_valid) begin
                    axi_ns = AXI_AR;
                end else if(burst_write) begin
                    axi_ns = AXI_AW;
                end else begin
                    axi_ns = axi_cs;
                end
            end
            AXI_AR: begin
                if(inf.AR_READY) begin
                    axi_ns = AXI_R;
                end else begin
                    axi_ns = axi_cs;
                end
            end
            AXI_R: begin
                if(inf.R_VALID) begin
                    axi_ns = AXI_IDLE;
                end else begin
                    axi_ns = axi_cs;
                end
            end
            AXI_AW: begin
                if(inf.AW_READY) begin
                    axi_ns = AXI_W;
                end else begin
                    axi_ns = axi_cs;
                end
            end
            AXI_W: begin
                if(inf.W_READY) begin
                    axi_ns = AXI_B;
                end else begin
                    axi_ns = axi_cs;
                end
            end
            AXI_B: begin
                if(inf.B_VALID && inf.B_READY) begin
                    axi_ns = AXI_IDLE;
                end else begin
                    axi_ns = axi_cs;
                end
            end
        endcase
    end

    // ==============================================
    //               SEQUENTIAL
    // ==============================================

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            inf.out_valid    <= '0;
            inf.warn_msg     <= No_Warn;
            inf.complete     <= '0;
            inf.AR_VALID     <= '0;
            inf.AR_ADDR      <= '0;
            inf.R_READY      <= '0;
            inf.AW_VALID     <= '0;
            inf.AW_ADDR      <= '0;
            inf.W_VALID      <= '0;
            inf.W_DATA       <= '0;
            inf.B_READY      <= '0;
            ACT              <= Login;
            dt               <= '0;
            p_info           <= '0;
            mon_cnt          <= '0;
            mon_atk          <= '0;
            mon_def          <= '0;
            mon_hp           <= '0;
            skill_cnt        <= '0;
            for(i = 0; i < 4; i = i + 1) begin
                skill[i]     <= '0;
                order[i]     <= '0;
            end
            player_idx       <= '0;
            md               <= Easy;
            tp               <= Type_A;
            has_player_info  <= '0;
            updated_info     <= '0;
            delta_MP         <= '0;
            delta_HP         <= '0;
            delta_ATK        <= '0;
            delta_DEF        <= '0;
            complete_reg     <= '0;
            warn_msg_reg     <= No_Warn;
            type_b_cnt         <= '0;
        end else begin
            inf.out_valid    <= out_valid_n;
            inf.warn_msg     <= out_valid_n ? warn_msg_n : No_Warn;
            inf.AR_VALID     <= AR_VALID_n;
            inf.AR_ADDR      <= AR_ADDR_n;
            inf.R_READY      <= R_READY_n;
            inf.AW_VALID     <= AW_VALID_n;
            inf.AW_ADDR      <= AW_ADDR_n;
            inf.W_VALID      <= W_VALID_n;
            inf.W_DATA       <= W_DATA_n;
            inf.B_READY      <= B_READY_n;
            inf.complete     <= out_valid_n ? complete_n : 0;
            ACT              <= ACT_n;
            dt               <= dt_n;
            p_info           <= p_info_n;
            mon_cnt          <= mon_cnt_n;
            mon_atk          <= mon_atk_n;
            mon_def          <= mon_def_n;
            mon_hp           <= mon_hp_n;
            skill            <= skill_n;
            skill_cnt        <= skill_cnt_n;
            player_idx       <= player_idx_n;
            md               <= md_n;
            tp               <= tp_n;
            has_player_info  <= has_player_info_n;
            updated_info     <= updated_info_n;
            delta_MP         <= delta_MP_n;
            delta_HP         <= delta_HP_n;
            delta_ATK        <= delta_ATK_n;
            delta_DEF        <= delta_DEF_n;
            complete_reg     <= complete_n;
            warn_msg_reg     <= warn_msg_n;
            type_b_cnt       <= type_b_cnt_n;
            order            <= order_n;
        end
    end

    // ==============================================
    //               COMBINATIONAL
    // ==============================================
    always_comb begin : comb
        out_valid_n         = 0;
        warn_msg_n          = warn_msg_reg;
        ACT_n               = ACT;
        dt_n                = dt;
        skill_cnt_n         = skill_cnt;
        skill_n             = skill;
        mon_cnt_n           = mon_cnt;
        md_n                = md;
        tp_n                = tp;
        mon_atk_n           = mon_atk;
        mon_def_n           = mon_def;
        mon_hp_n            = mon_hp;
        complete_n          = complete_reg;
        updated_info_n      = updated_info;
        delta_MP_n          = delta_MP;
        delta_HP_n          = delta_HP;
        delta_ATK_n         = delta_ATK;
        delta_DEF_n         = delta_DEF;
        burst_write         = 0;
        type_b_cnt_n        = 0;
        order_n             = order;



        if(cs == IDLE) begin
            skill_cnt_n = 0;
            mon_cnt_n   = 0;
            for(j = 0; j < 4; j = j + 1) begin
                skill_n[j] = 0;
            end
            if(inf.sel_action_valid) begin
                ACT_n = inf.D.d_act[0];
                complete_n  = 0;
            end
        end

        if(cs == IN_LOGIN && inf.date_valid) begin
                dt_n = inf.D.d_date[0];
        end

        if(cs == IN_LEVEL_UP) begin
            if(inf.type_valid) begin
                tp_n = inf.D.d_type[0];
            end
            if(inf.mode_valid) begin
                md_n = inf.D.d_mode[0];
            end
        end

        if(cs == IN_BATTLE && inf.monster_valid) begin
            mon_cnt_n = mon_cnt + 1;
            if(mon_cnt == 0) begin
                mon_atk_n = inf.D.d_attribute[0];
            end
            if(mon_cnt == 1) begin
                mon_def_n = inf.D.d_attribute[0];
            end
            if(mon_cnt == 2) begin
                mon_hp_n  = inf.D.d_attribute[0];
            end
        end

        if(cs == IN_USE_SKILL) begin
            if(inf.MP_valid) begin
                skill_cnt_n = skill_cnt + 1;
                //if(skill_cnt < 4) skill_n[skill_cnt] = inf.D.d_attribute[0];
                if(skill_cnt == 0) skill_n[0] = inf.D.d_attribute[0];
                if(skill_cnt == 1) skill_n[1] = inf.D.d_attribute[0];
                if(skill_cnt == 2) begin
                    if(inf.D.d_attribute[0] < skill[0]) begin
                        skill_n[0] = inf.D.d_attribute[0];
                        skill_n[2] = skill[0];
                    end else begin
                        skill_n[2] = inf.D.d_attribute[0];
                    end 
                end
                if(skill_cnt == 3) begin
                    if(inf.D.d_attribute[0] < skill[1]) begin
                        skill_n[1] = inf.D.d_attribute[0];
                        skill_n[3] = skill[1];
                    end else begin
                        skill_n[3] = inf.D.d_attribute[0];
                    end 
                end
            end
            if(skill_cnt == 4) begin
                if(skill[0] > skill[1]) begin
                    skill_n[0] = skill[1];
                    skill_n[1] = skill[0];
                end
                if(skill[2] > skill[3]) begin
                    skill_n[2] = skill[3];
                    skill_n[3] = skill[2];
                end
            end
        end

        if(cs == IN_CHECK_ACT && inf.date_valid) begin
                dt_n = inf.D.d_date[0];
        end

        if(cs == LOGIN) begin
            if(has_player_info) begin
                logic signed [8:0] diff;
                complete_n                   = 1;
                warn_msg_n                   = No_Warn;
                updated_info_n               = p_info;
                updated_info_n.M             = dt.M;
                updated_info_n.D             = dt.D;
                burst_write                  = 1;
                diff = dti(dt.M, dt.D) - dti(p_info.M, p_info.D) < 0 ? dti(dt.M, dt.D) - dti(p_info.M, p_info.D) + 365 : dti(dt.M, dt.D) - dti(p_info.M, p_info.D);
                if(diff == 1) begin
                    if(p_info.Exp + 512 > 65535) begin
                        updated_info_n.Exp   = 65535;
                        warn_msg_n           = Saturation_Warn;
                        complete_n           = 0;
                    end else begin
                        updated_info_n.Exp   = p_info.Exp + 512;
                    end
                    if(p_info.MP + 1024 > 65535) begin
                        updated_info_n.MP    = 65535;
                        warn_msg_n           = Saturation_Warn;
                        complete_n           = 0;
                    end else begin
                        updated_info_n.MP    = p_info.MP  + 1024;
                    end
                end
            end
        end

        if(cs == CALC_DELTA) begin
            logic [17:0] sum;
            sum = p_info.MP + p_info.HP + p_info.Attack + p_info.Defense;
            if(has_player_info) begin
                case (tp)
                    Type_A: begin
                        delta_MP_n  = sum >> 3;
                        delta_HP_n  = sum >> 3;
                        delta_ATK_n = sum >> 3;
                        delta_DEF_n = sum >> 3;
                    end
                    Type_B: begin
                        case (type_b_cnt)
                            0: begin
                                delta_HP_n  = 0;
                                delta_MP_n  = 0;
                                delta_ATK_n = 0;
                                delta_DEF_n = 0;
                                if(p_info.MP <= p_info.Attack) begin
                                    skill_n[0] = p_info.MP;
                                    skill_n[2] = p_info.Attack;
                                    order_n[0] = 0;
                                    order_n[2] = 2;
                                end else begin
                                    skill_n[0] = p_info.Attack;
                                    skill_n[2] = p_info.MP;
                                    order_n[0] = 2;
                                    order_n[2] = 0;
                                end
                                if(p_info.HP <= p_info.Defense) begin
                                    skill_n[1] = p_info.HP;
                                    skill_n[3] = p_info.Defense;
                                    order_n[1] = 1;
                                    order_n[3] = 3;
                                end else begin
                                    skill_n[1] = p_info.Defense;
                                    skill_n[3] = p_info.HP;
                                    order_n[1] = 3;
                                    order_n[3] = 1;
                                end
                                type_b_cnt_n = 1;
                            end
                            1: begin
                                if({skill[0], order[0]} < {skill[1], order[1]}) begin
                                    skill_n[0] = skill[0];
                                    skill_n[1] = skill[1];
                                    order_n[0] = order[0];
                                    order_n[1] = order[1];
                                end else begin
                                    skill_n[0] = skill[1];
                                    skill_n[1] = skill[0];
                                    order_n[0] = order[1];
                                    order_n[1] = order[0];
                                end

                                if({skill[2], order[2]} < {skill[3], order[3]}) begin
                                    skill_n[2] = skill[2];
                                    skill_n[3] = skill[3];
                                    order_n[2] = order[2];
                                    order_n[3] = order[3];
                                end else begin
                                    skill_n[2] = skill[3];
                                    skill_n[3] = skill[2];
                                    order_n[2] = order[3];
                                    order_n[3] = order[2];
                                end
                                type_b_cnt_n = 2;
                            end

                            2: begin
                                if({skill[1], order[1]} < {skill[2], order[2]}) begin
                                    skill_n[1] = skill[1];
                                    skill_n[2] = skill[2];
                                    order_n[1] = order[1];
                                    order_n[2] = order[2];
                                end else begin
                                    skill_n[2] = skill[1];
                                    skill_n[1] = skill[2];
                                    order_n[2] = order[1];
                                    order_n[1] = order[2];
                                end
                                type_b_cnt_n = 3;
                            end
                            3: begin
                                case (order[0])
                                    0: delta_MP_n  = skill[2] - p_info.MP;
                                    1: delta_HP_n  = skill[2] - p_info.HP;
                                    2: delta_ATK_n = skill[2] - p_info.Attack;
                                    3: delta_DEF_n = skill[2] - p_info.Defense; 
                                endcase
                                case (order[1])
                                    0: delta_MP_n  = skill[3] - p_info.MP;
                                    1: delta_HP_n  = skill[3] - p_info.HP;
                                    2: delta_ATK_n = skill[3] - p_info.Attack;
                                    3: delta_DEF_n = skill[3] - p_info.Defense; 
                                endcase

                            end
                        endcase
                    end
                    Type_C: begin
                        if (p_info.MP      < 16'd16383)  delta_MP_n  = 16'd16383 - p_info.MP;      else  delta_MP_n  = 0;
                        if (p_info.HP      < 16'd16383)  delta_HP_n  = 16'd16383 - p_info.HP;      else  delta_HP_n  = 0;
                        if (p_info.Attack  < 16'd16383)  delta_ATK_n = 16'd16383 - p_info.Attack;  else  delta_ATK_n = 0;
                        if (p_info.Defense < 16'd16383)  delta_DEF_n = 16'd16383 - p_info.Defense; else  delta_DEF_n = 0;
                    end
                    Type_D: begin
                        delta_MP_n  = (3000 + ((16'hFFFF - p_info.MP)     >> 4) > 5047) ? 5047 : 3000 + ((16'hFFFF - p_info.MP)     >> 4);
                        delta_HP_n  = (3000 + ((16'hFFFF - p_info.HP)     >> 4) > 5047) ? 5047 : 3000 + ((16'hFFFF - p_info.HP)     >> 4);
                        delta_ATK_n = (3000 + ((16'hFFFF - p_info.Attack) >> 4) > 5047) ? 5047 : 3000 + ((16'hFFFF - p_info.Attack) >> 4);
                        delta_DEF_n = (3000 + ((16'hFFFF - p_info.Defense)>> 4) > 5047) ? 5047 : 3000 + ((16'hFFFF - p_info.Defense)>> 4);
                    end 
                endcase
            end
        end

        if(cs == LEVEL_UP) begin
            if(has_player_info) begin
                logic sat_mp, sat_hp, sat_atk, sat_def;
                logic sat_any;
                logic [17:0] d_mp_adj, d_hp_adj, d_atk_adj, d_def_adj;
                warn_msg_n     = No_Warn;
                complete_n     = 1;
                updated_info_n = p_info;
                d_mp_adj       = delta_MP;
                d_hp_adj       = delta_HP;
                d_atk_adj      = delta_ATK;
                d_def_adj      = delta_DEF;
                burst_write    = 1;

                case (md)
                    Easy: begin
                        if (p_info.Exp < 16'd4095) begin
                            warn_msg_n = Exp_Warn;
                            complete_n = 0;
                        end else begin
                            updated_info_n.Exp = p_info.Exp;

                            d_mp_adj  = delta_MP  - (delta_MP  >> 2);
                            d_hp_adj  = delta_HP  - (delta_HP  >> 2);
                            d_atk_adj = delta_ATK - (delta_ATK >> 2);
                            d_def_adj = delta_DEF - (delta_DEF >> 2);

                            updated_info_n.MP      = check_add_saturation(p_info.MP,      d_mp_adj,  sat_mp);
                            updated_info_n.HP      = check_add_saturation(p_info.HP,      d_hp_adj,  sat_hp);
                            updated_info_n.Attack  = check_add_saturation(p_info.Attack,  d_atk_adj, sat_atk);
                            updated_info_n.Defense = check_add_saturation(p_info.Defense, d_def_adj, sat_def);

                            sat_any = sat_mp | sat_hp | sat_atk | sat_def;
                            if (sat_any) begin
                                warn_msg_n = Saturation_Warn;
                                complete_n = 0;
                            end
                        end
                    end

                    Normal: begin
                        if (p_info.Exp < 16'd16383) begin
                            warn_msg_n = Exp_Warn;
                            complete_n = 0;
                        end else begin
                            updated_info_n.Exp = p_info.Exp;

                            d_mp_adj  = delta_MP;
                            d_hp_adj  = delta_HP;
                            d_atk_adj = delta_ATK;
                            d_def_adj = delta_DEF;

                            updated_info_n.MP      = check_add_saturation(p_info.MP,      d_mp_adj,  sat_mp);
                            updated_info_n.HP      = check_add_saturation(p_info.HP,      d_hp_adj,  sat_hp);
                            updated_info_n.Attack  = check_add_saturation(p_info.Attack,  d_atk_adj, sat_atk);
                            updated_info_n.Defense = check_add_saturation(p_info.Defense, d_def_adj, sat_def);

                            sat_any = sat_mp | sat_hp | sat_atk | sat_def;
                            if (sat_any) begin
                                warn_msg_n = Saturation_Warn;
                                complete_n = 0;
                            end
                        end
                    end

                    Hard: begin
                        if (p_info.Exp < 16'd32767) begin
                            warn_msg_n = Exp_Warn;
                            complete_n = 0;
                        end else begin
                            updated_info_n.Exp = p_info.Exp;

                            d_mp_adj  = delta_MP  + (delta_MP  >> 2);
                            d_hp_adj  = delta_HP  + (delta_HP  >> 2);
                            d_atk_adj = delta_ATK + (delta_ATK >> 2);
                            d_def_adj = delta_DEF + (delta_DEF >> 2);

                            updated_info_n.MP      = check_add_saturation(p_info.MP,      d_mp_adj,  sat_mp);
                            updated_info_n.HP      = check_add_saturation(p_info.HP,      d_hp_adj,  sat_hp);
                            updated_info_n.Attack  = check_add_saturation(p_info.Attack,  d_atk_adj, sat_atk);
                            updated_info_n.Defense = check_add_saturation(p_info.Defense, d_def_adj, sat_def);

                            sat_any = sat_mp | sat_hp | sat_atk | sat_def;
                            if (sat_any) begin
                                warn_msg_n = Saturation_Warn;
                                complete_n = 0;
                            end
                        end
                    end
                endcase
            end
        end

        if (cs == BATTLE) begin
            updated_info_n = p_info;
            warn_msg_n     = No_Warn;
            complete_n     = 1;
            burst_write    = has_player_info;

            if (!has_player_info) begin
                complete_n = 0;

            end else if (p_info.HP == 16'd0) begin
                warn_msg_n = HP_Warn;
                complete_n = 0;

            end else begin
                logic signed [16:0] dmg_to_player;
                logic signed [16:0] dmg_to_monster;
                logic signed [17:0] player_hp_tmp;
                logic signed [17:0] monster_hp_tmp;

                bit sat_exp, sat_mp, sat_hp, sat_atk, sat_def;
                bit sat;

                dmg_to_player  = $signed({1'b0, mon_atk})       - $signed({1'b0, p_info.Defense});
                dmg_to_monster = $signed({1'b0, p_info.Attack}) - $signed({1'b0, mon_def});

                if (dmg_to_player > 0)
                    player_hp_tmp = $signed({1'b0, p_info.HP}) - dmg_to_player;
                else
                    player_hp_tmp = $signed({1'b0, p_info.HP});

                if (dmg_to_monster > 0)
                    monster_hp_tmp = $signed({1'b0, mon_hp}) - dmg_to_monster;
                else
                    monster_hp_tmp = $signed({1'b0, mon_hp});

                if ((player_hp_tmp > 0) && (monster_hp_tmp <= 0)) begin
                    // ========= Win =========
                    updated_info_n.Exp = check_add_saturation(p_info.Exp, 16'd2048, sat_exp);
                    updated_info_n.MP  = check_add_saturation(p_info.MP,  16'd2048, sat_mp);

                    if (player_hp_tmp <= 0)
                        updated_info_n.HP = 16'd0;
                    else if (player_hp_tmp > 17'd65535)
                        updated_info_n.HP = 16'hFFFF;
                    else
                        updated_info_n.HP = player_hp_tmp[15:0];

                    updated_info_n.Attack  = p_info.Attack;
                    updated_info_n.Defense = p_info.Defense;

                    sat_hp  = (player_hp_tmp <= 0) || (player_hp_tmp > 17'd65535);
                    sat_atk = 1'b0;
                    sat_def = 1'b0;

                end else if (player_hp_tmp <= 0) begin
                    // ========= Lose =========

                    updated_info_n.HP      = 16'd0;
                    updated_info_n.Exp     = check_sub_saturation(p_info.Exp,     16'd2048, sat_exp);
                    updated_info_n.Attack  = check_sub_saturation(p_info.Attack,  16'd2048, sat_atk);
                    updated_info_n.Defense = check_sub_saturation(p_info.Defense, 16'd2048, sat_def);
                    updated_info_n.MP      = p_info.MP;

                    sat_mp = 1'b0;
                    sat_hp = 1'b0;

                end else begin
                    // ========= Tie ========= 
                    if (player_hp_tmp <= 0)
                        updated_info_n.HP = 16'd0;
                    else if (player_hp_tmp > 17'd65535)
                        updated_info_n.HP = 16'hFFFF;
                    else
                        updated_info_n.HP = player_hp_tmp[15:0];

                    updated_info_n.Exp     = p_info.Exp;
                    updated_info_n.MP      = p_info.MP;
                    updated_info_n.Attack  = p_info.Attack;
                    updated_info_n.Defense = p_info.Defense;

                    sat_exp = 1'b0;
                    sat_mp  = 1'b0;
                    sat_atk = 1'b0;
                    sat_def = 1'b0;
                    sat_hp  = (player_hp_tmp <= 0) || (player_hp_tmp > 17'd65535);
                end
                sat = sat_exp | sat_mp | sat_hp | sat_atk | sat_def;
                if(sat) begin
                    warn_msg_n = Saturation_Warn;
                    complete_n = 0;
                end
            end
        end

        if (cs == USE_SKILL) begin
            logic [17:0] mp_u;
            logic [17:0] sum;
            logic [2:0]  used_cnt;
            bit          sat_mp;
            updated_info_n = p_info;
            warn_msg_n     = No_Warn;
            complete_n     = 1'b1;
            burst_write    = 1'b1;
            mp_u     = {2'b0, p_info.MP};
            sum      = 18'd0;
            used_cnt = 3'd0;

            if ({2'b0, skill[3]} <= mp_u) begin
                used_cnt = 3'd4;
                sum      = {2'b0, skill[3]};
            end
            else if ({2'b0, skill[2]} <= mp_u) begin
                used_cnt = 3'd3;
                sum      = {2'b0, skill[2]};
            end
            else if ({2'b0, skill[1]} <= mp_u) begin
                used_cnt = 3'd2;
                sum      = {2'b0, skill[1]};
            end
            else if ({2'b0, skill[0]} <= mp_u) begin
                used_cnt = 3'd1;
                sum      = {2'b0, skill[0]};
            end

            if (used_cnt == 3'd0) begin
                warn_msg_n = MP_Warn;
                complete_n = 1'b0;
            end
            else begin
                updated_info_n.MP = check_sub_saturation(p_info.MP, sum[15:0], sat_mp);
                if (sat_mp) begin
                    warn_msg_n = Saturation_Warn;
                    complete_n = 1'b0;
                end
            end
        end

        if (cs == CHECK_ACT) begin
            updated_info_n = p_info;
            warn_msg_n     = No_Warn;
            complete_n     = 1;
            //burst_write    = 1;
            

            if (!has_player_info) begin
                complete_n = 0;
            end else begin
                int last_idx, today_idx;
                int diff;
                out_valid_n    = 1;
                last_idx  = dti(p_info.M, p_info.D);
                today_idx = dti(dt.M, dt.D);

                if (last_idx < 0 || today_idx < 0) begin
                    warn_msg_n = Date_Warn;
                    complete_n = 0;
                end else begin
                    diff = today_idx - last_idx;
                    if (diff < 0)
                        diff = diff + 365;

                    if (diff > 90) begin
                        warn_msg_n = Date_Warn;
                        complete_n = 0;
                    end
                end
            end
        end

        if(cs == AXI) begin
            if(inf.B_READY && inf.B_VALID) begin
                out_valid_n = 1;
            end
        end
        /*
        if (cs == SORT) begin
            Attribute x0, x1, x2, x3;
            Attribute tmp;
            x0 = skill[0];
            x1 = skill[1];
            x2 = skill[2];
            x3 = skill[3];

            // Layer 1: (0,2), (1,3)
            if (x0 > x2) begin
                tmp = x0; x0 = x2; x2 = tmp;
            end
            if (x1 > x3) begin
                tmp = x1; x1 = x3; x3 = tmp;
            end

            // Layer 2: (0,1), (2,3)
            if (x0 > x1) begin
                tmp = x0; x0 = x1; x1 = tmp;
            end
            if (x2 > x3) begin
                tmp = x2; x2 = x3; x3 = tmp;
            end

            // Layer 3: (1,2)
            if (x1 > x2) begin
                tmp = x1; x1 = x2; x2 = tmp;
            end

            skill_n[0] = x0;
            skill_n[1] = x0 + x1;
            skill_n[2] = x0 + x1 + x2;
            skill_n[3] = skill[0] + skill[1] + skill[2] + skill[3];
        end
        */
        if(cs == SORT) begin
            if(skill[1] > skill[2]) begin
                skill_n[1] = skill[2];
                skill_n[2] = skill[1];
            end
            skill_n[1] = skill[0] + skill_n[1];
            skill_n[2] = skill[0] + skill[1] + skill[2];
            skill_n[3] = skill[0] + skill[1] + skill[2] + skill[3];
        end
    end


    always_comb begin: AXI_COMB
        has_player_info_n = has_player_info;
        AR_VALID_n   = 0;
        AR_ADDR_n    = inf.AR_ADDR;
        R_READY_n    = 0;
        AW_VALID_n   = 0;
        AW_ADDR_n    = inf.AW_ADDR;
        W_VALID_n    = 0;
        W_DATA_n     = inf.W_DATA;
        B_READY_n    = 0;
        p_info_n     = p_info;
        player_idx_n = player_idx;
        if(axi_cs == AXI_IDLE) begin
            if(cs == IDLE) has_player_info_n = 0;
            AR_VALID_n = 0;
            if(player_no_valid) begin
                AR_ADDR_n  = to_addr(inf.D.d_player_no[0]);
                player_idx_n = inf.D.d_player_no[0];
                AR_VALID_n = 1;
            end
        end

        if(axi_cs == AXI_AR) begin
            AR_VALID_n = 1;
            if(inf.AR_READY) begin
                R_READY_n = 1;
                AR_VALID_n = 0;
            end
        end

        if(axi_cs == AXI_R) begin
            R_READY_n = 1;
            if(inf.R_VALID) begin
                p_info_n = unpack_player_info(inf.R_DATA);
                has_player_info_n = 1;
                R_READY_n = 0;
            end
        end

        if(axi_cs == AXI_AW) begin
            AW_VALID_n = 1;
            AW_ADDR_n  = to_addr(player_idx);
            if(inf.AW_READY) begin
                W_VALID_n = 1;
                W_DATA_n = {updated_info.HP, 4'b0, updated_info.M, 3'b0, updated_info.D, updated_info.Attack, updated_info.Defense, updated_info.Exp, updated_info.MP};
            end
        end

        if(axi_cs == AXI_W) begin
            W_VALID_n = 1;
            W_DATA_n = {updated_info.HP, 4'b0, updated_info.M, 3'b0, updated_info.D, updated_info.Attack, updated_info.Defense, updated_info.Exp, updated_info.MP};
            if(inf.W_READY) begin
                B_READY_n = 1;
            end
        end

        if(axi_cs == AXI_B) begin
            B_READY_n = 1;
        end

    end

endmodule
