#!/usr/bin/bash
prove -l -Ilib

cd ../MarpaX-Regex
prove -l -Ilib -I../MarpaX-AST/lib

cd ../MarpaX-Languages-Lua-AST
prove -l -Ilib -I../MarpaX-AST/lib

