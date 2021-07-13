nnue :: #foreign_library "nnue-probe/src/libnnueprobe";
nnue_init :: (eval_file: *u8) #c_call #foreign nnue;

main :: () {
  eval_file :: "resources/nn-190f102a22c3.nnue";
  nnue_init(eval_file);
}

