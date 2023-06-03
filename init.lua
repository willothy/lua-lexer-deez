local Lexer = require("lexer")
local Parser = require("parser")
local Generator = require("generator")

print(arg[2])
local file = io.open(arg[2], "r")
-- io.read(arg[2])
if not file then
	print("Could not open file")
	return
end
local input = file:read("*a")
file:close()

local lexer = Lexer:new(input)
local parser = Parser:new(lexer)
local ast = parser:parse()
local generator = Generator:new(ast)
local output = generator:generate()

print(output)
