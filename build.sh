rm -rf build
mkdir build
echo "#!/usr/bin/env lua" > build/lcpio
luaroll -o- lcpio json=json.lua/json.lua argparse=$(lua -e "print(select(2, require('argparse')))") -mlcpio >> build/lcpio