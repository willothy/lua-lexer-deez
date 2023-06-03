local ffi = require("ffi")
local C = ffi.C

ffi.cdef([[
	typedef enum {
    TokenTypeIllegal,
    TokenTypeEof,
    TokenTypeIdent,
    TokenTypeInt,
		TokenTypeString,
		TokenTypeBool,
		TokenTypeOp,
		TokenTypeComma,
		TokenTypeColon,
		TokenTypeDot,
		TokenTypeSemicolon,
    TokenTypeLParen,
    TokenTypeRParen,
    TokenTypeLSquirly,
    TokenTypeRSquirly,
		TokenTypeLBracket,
		TokenTypeRBracket,
    TokenTypeFunction,
    TokenTypeLet,
		TokenTypeIf,
		TokenTypeElse,
		TokenTypeReturn,
		TokenTypeWhile,
  } TokenType;

	typedef struct  {
		size_t start_pos;
		size_t end_pos;
	} Span;

	typedef struct {
		TokenType type;
		const char *literal; 
		Span span;
	} Token;
]])

local Token = {}
Token.__index = Token
setmetatable(Token, Token)
ffi.metatype("Token", Token)

function Token:__tostring()
	return string.format(
		"Token(%s, %s%s:%s)",
		Token.type_name[tonumber(self.type)],
		self.literal ~= nil and (ffi.string(self.literal) .. ", ") or "",
		tonumber(self.span.start_pos),
		tonumber(self.span.end_pos)
	)
end

function Token:__eq(other)
	if self.type ~= other.type then
		return false
	end
	if self.type == Token.type.ident or self.type == Token.type.int then
		return self.literal == other.literal
	else
		return false
	end
end

function Token:__call(...)
	return Token:new(...)
end

function Token:new(type, literal)
	local tok = ffi.new("Token")
	tok.type = type
	if literal then
		tok.literal = literal
	end
	return tok
end

function Token:spanned(start_pos, end_pos)
	self.span.start_pos = start_pos
	self.span.end_pos = end_pos
	return self
end

Token.type = {
	illegal = C.TokenTypeIllegal,
	eof = C.TokenTypeEof,
	ident = C.TokenTypeIdent,
	int = C.TokenTypeInt,
	string = C.TokenTypeString,
	bool = C.TokenTypeBool,
	op = C.TokenTypeOp,
	dot = C.TokenTypeDot,
	comma = C.TokenTypeComma,
	colon = C.TokenTypeColon,
	semicolon = C.TokenTypeSemicolon,
	lparen = C.TokenTypeLParen,
	rparen = C.TokenTypeRParen,
	lsquirly = C.TokenTypeLSquirly,
	rsquirly = C.TokenTypeRSquirly,
	lbracket = C.TokenTypeLBracket,
	rbracket = C.TokenTypeRBracket,
	fn = C.TokenTypeFunction,
	let = C.TokenTypeLet,
	if_ = C.TokenTypeIf,
	else_ = C.TokenTypeElse,
	return_ = C.TokenTypeReturn,
	while_ = C.TokenTypeWhile,
}

Token.type_name = {}
for k, v in pairs(Token.type) do
	Token.type_name[tonumber(v)] = k
end

return Token
