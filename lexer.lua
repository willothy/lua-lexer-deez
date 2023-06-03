local ffi = require("ffi")
local Token = require("token")

ffi.cdef([[
	typedef struct {
		const char* input;
		char ch;
		size_t len;
		size_t lookahead;
		size_t pos;
	} Lexer;
]])

local Lexer = {}

Lexer.__index = Lexer
function Lexer:__call(...)
	return Lexer:new(...)
end
setmetatable(Lexer, Lexer)
ffi.metatype("Lexer", Lexer)

Lexer.keywords = {
	["let"] = Token(Token.type.let),
	["fn"] = Token(Token.type.fn),
	["true"] = Token(Token.type.bool, "true"),
	["false"] = Token(Token.type.bool, "false"),
	["while"] = Token(Token.type.while_),
	["if"] = Token(Token.type.if_),
	["else"] = Token(Token.type.else_),
	["return"] = Token(Token.type.return_),
}

Lexer.symbols = {
	["{"] = Token(Token.type.lsquirly, "{"),
	["}"] = Token(Token.type.rsquirly, "}"),
	["("] = Token(Token.type.lparen, "("),
	[")"] = Token(Token.type.rparen, ")"),
	["["] = Token(Token.type.lbracket, "["),
	["]"] = Token(Token.type.rbracket, "]"),
	[","] = Token(Token.type.comma, ","),
	[";"] = Token(Token.type.semicolon, ";"),
	[":"] = Token(Token.type.colon, ":"),
	["."] = Token(Token.type.dot, "."),
	["+"] = Token(Token.type.op, "+"),
	["-"] = Token(Token.type.op, "-"),
	["*"] = Token(Token.type.op, "*"),
	["/"] = Token(Token.type.op, "/"),
	["%"] = Token(Token.type.op, "%"),
	["!"] = Token(Token.type.op, "!"),
	["<"] = Token(Token.type.op, "<"),
	[">"] = Token(Token.type.op, ">"),
	["="] = Token(Token.type.op, "="),
	["=="] = Token(Token.type.op, "=="),
	["!="] = Token(Token.type.op, "!="),
	["<="] = Token(Token.type.op, "<="),
	[">="] = Token(Token.type.op, ">="),
	["&&"] = Token(Token.type.op, "&&"),
	["||"] = Token(Token.type.op, "||"),
	["\0"] = Token(Token.type.eof),
}

function Lexer:new(input)
	local new = ffi.new("Lexer")
	new.input = input
	new.len = #input
	new.ch = 0
	new.lookahead = 0
	new.pos = 0
	new:read_char()
	return new
end

function Lexer:next()
	self:skip_whitespace()

	local str = string.char(self.ch)
	local start_pos = self.pos

	local tok = Token(Token.type.illegal)

	if str:match("[a-zA-Z_]") ~= nil then
		local ident = self:read_ident()

		if self.keywords[ffi.string(ident)] then
			return self.keywords[ffi.string(ident)]:spanned(start_pos, self.pos)
		end

		return Token(Token.type.ident, ffi.string(ident)):spanned(start_pos, self.pos)
	end

	if str:match("[0-9]") ~= nil then
		local int = self:read_int()
		return Token(Token.type.int, ffi.string(int)):spanned(start_pos, self.pos)
	end

	if str:match('"') ~= nil then
		local string = self:read_string()
		return Token(Token.type.string, ffi.string(string)):spanned(start_pos, self.pos)
	end

	if self.symbols[str] then
		self:read_char()
		if self.symbols[str .. string.char(self.ch)] then
			str = str .. string.char(self.ch)
		end
		tok = self.symbols[str]
	else
		self:read_char()
	end

	return tok:spanned(start_pos, self.pos)
end

function Lexer:read_char()
	if self.lookahead >= self.len then
		self.ch = 0
	else
		self.ch = self.input[self.lookahead]
	end

	self.pos = self.lookahead
	self.lookahead = self.lookahead + 1
end

function Lexer:read_string()
	self:read_char()
	local position = self.pos

	while self.ch ~= 0 and self.ch ~= string.byte('"') do
		self:read_char()
	end

	local out_str = ffi.new("char[?]", (self.pos - position) + 1)
	ffi.copy(out_str, self.input + position, (self.pos - position))

	self:read_char()
	return out_str
end

function Lexer:read_ident()
	local position = self.pos

	while string.char(self.ch):match("([a-zA-Z_])") ~= nil do
		self:read_char()
	end

	local out_str = ffi.new("char[?]", (self.pos - position) + 1)
	ffi.copy(out_str, self.input + position, (self.pos - position))

	return out_str
end

function Lexer:read_int()
	local position = self.pos

	while string.char(self.ch):match("[0-9]") do
		self:read_char()
	end

	local out_str = ffi.new("char[?]", (self.pos - position) + 1)
	ffi.copy(out_str, self.input + position, (self.pos - position))

	return out_str
end

function Lexer:skip_whitespace()
	while string.char(self.ch):match("[ \t\n]") do
		self:read_char()
	end
end

return Lexer
