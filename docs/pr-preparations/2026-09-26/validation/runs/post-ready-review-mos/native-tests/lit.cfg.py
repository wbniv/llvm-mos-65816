import os
import lit.formats

config.name = "MOS-native-optimization-review"
config.test_format = lit.formats.ShTest(True)
config.suffixes = [".ll"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.test_source_root, "Output")
config.environment["PATH"] = "/home/will/llvm-mos-65816/build/llvm-mos/bin:" + os.environ["PATH"]
