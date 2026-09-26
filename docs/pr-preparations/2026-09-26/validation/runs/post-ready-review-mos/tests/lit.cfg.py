import os
import lit.formats

config.name = "MOS-exact-artifact-review"
config.test_format = lit.formats.ShTest(True)
config.suffixes = [".ll", ".s"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.test_source_root, "Output-" + lit_config.params.get("run", "candidate"))
config.environment["PATH"] = lit_config.params.get("bin", "/home/will/llvm-mos-65816/build/llvm-mos/bin") + ":/home/will/llvm-mos-65816/build/llvm-mos/bin:" + os.environ["PATH"]
