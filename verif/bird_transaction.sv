class bird_transaction extends uvm_sequence_item;

  rand bit          is_remote;
  rand bit [7:0]    payload[];
  rand bit [15:0]   crc;
  rand bit [4:0]    seq_num;
  rand bit [4:0]    frag_num;
  rand bit [31:0]   cfg;

  `uvm_object_utils_begin(bird_transaction)
    `uvm_field_int(is_remote, UVM_ALL_ON)
    `uvm_field_array_int(payload, UVM_ALL_ON)
    `uvm_field_int(crc, UVM_ALL_ON)
    `uvm_field_int(seq_num, UVM_ALL_ON)
    `uvm_field_int(frag_num, UVM_ALL_ON)
    `uvm_field_int(cfg, UVM_ALL_ON)
  `uvm_object_utils_end

  constraint payload_size_c {
    payload.size inside {[1:255]};
  }

  constraint cfg_valid_c {
    cfg[0]     == is_remote;
    cfg[7:1]   == 7'd0;
    cfg[15:8]  == payload.size();
    cfg[20:16] == frag_num;
    cfg[23:21] == 3'd0;
    cfg[28:24] == seq_num;
    cfg[31:29] == 3'd0;
  }

  function new(string name = "bird_transaction");
    super.new(name);
  endfunction

  function void build_local_cfg();
    is_remote = 1'b0;
    seq_num   = 5'd1;
    frag_num  = 5'd1;
    cfg       = make_cfg(is_remote, payload.size(), frag_num, seq_num);
  endfunction

  // Note for the current DUT code:
  // The uploaded design stores remote fragments using cfg[28:24] as the index
  // and cfg[20:16] as the maximum/total fragment count.
  function void build_remote_cfg(int unsigned fragment_index, int unsigned total_fragments);
    is_remote = 1'b1;
    seq_num   = fragment_index[4:0];
    frag_num  = total_fragments[4:0];
    cfg       = make_cfg(is_remote, payload.size(), frag_num, seq_num);
  endfunction

  static function logic [31:0] make_cfg(
    bit          is_remote_i,
    int unsigned payload_len_i,
    int unsigned frag_num_i,
    int unsigned seq_num_i
  );
    logic [31:0] cfg_i;

    cfg_i = 32'd0;
    cfg_i[0]     = is_remote_i;
    cfg_i[15:8]  = payload_len_i[7:0];
    cfg_i[20:16] = frag_num_i[4:0];
    cfg_i[28:24] = seq_num_i[4:0];

    return cfg_i;
  endfunction

endclass
