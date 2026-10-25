"""Execute the real plugin with Lua 5.4 and a substitute native API."""
import argparse
from pathlib import Path
import sys
import re

parser = argparse.ArgumentParser()
parser.add_argument("--lua-packages", type=Path, help="Directory containing lupa")
args = parser.parse_args()
if args.lua_packages:
    sys.path.insert(0, str(args.lua_packages.resolve()))
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().pluginRoot = root.as_posix()
dump_variables = {}
for line in (root / "VarPlayer").read_text(encoding="utf-8-sig").splitlines():
    match = re.match(r"^(-?\d+)\s+(\S+)\s+INTEGER(?:\s|$)", line)
    if match:
        dump_variables[match[2]] = int(match[1])
assert re.search(r"^93\s+INV$", (root / "Inv").read_text(encoding="utf-8-sig"), re.M)
lua.globals().dumpVariables = lua.table_from(dump_variables)
lua.execute("package.path = pluginRoot .. '/?.lua;' .. package.path")
lua.execute((root / "tests/runtime.lua").read_text(encoding="utf-8"))
