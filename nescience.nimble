mode = ScriptMode.Verbose

packageName   = "nescience"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "A Nim Framework for Zero Knowledge"
license       = "Apache License 2.0 or MIT"
skipDirs      = @["tests", "examples"]

# Dependencies

requires "nim >= 1.2.4",
    "bncurve",
    "nimcrypto",
    "stint",
    "nim-stew"

proc buildBinary(name: string, srcDir = "./", params = "", lang = "c") =
  if not dirExists "bin":
    mkDir "bin"
  # allow something like "nim nimbus --verbosity:0 --hints:off nimbus.nims"
  var extra_params = params
  for i in 2..<paramCount():
    extra_params &= " " & paramStr(i)
  exec "nim " & lang & " --out:bin/" & name & " " & extra_params & " " & srcDir & name & ".nim"

proc test(name: string, lang = "c") =
  buildBinary name, "tests/", "-d:chronicles_log_level=ERROR"
  exec "bin/" & name

task test, "Run tests":
  # test "all_tests"
  # test "test_r1cs"
  test "test_dsl"

task nimbus, "Build Nescience":
  buildBinary "nescience", "nescience/", "-d:chronicles_log_level=TRACE"