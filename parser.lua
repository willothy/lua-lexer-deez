local ffi = require("ffi")

local Token = require("token")
local Node = require("node")
local Log = require("log")

local Parser = {}

function Parser:new(lexer)
	local parser = {
		lexer = lexer,
		cur_token = lexer:next(),
		peek_token = lexer:next(),
		errors = {},
	}
	setmetatable(parser, self)
	self.__index = self
	return parser
end

function Parser:expected_token(expected)
	local expected_str = Token.type_name[tonumber(expected)]
	local found_str = Token.type_name[tonumber(self.cur_token.type)]
	local msg = string.format("expected %s, got %s at %s", expected_str, found_str, self.cur_token.span.start_pos)
	Log.error(msg)
	table.insert(self.errors, msg)
end

function Parser:next_token()
	self.cur_token = self.peek_token
	self.peek_token = self.lexer:next()
end

function Parser:parse()
	return self:parse_block(true)
end

function Parser:parse_block(root)
	Log.dbg("parse_block")
	local program = Node({
		type = root and "program" or "block",
		stmts = {},
	})
	while self.cur_token.type ~= Token.type.eof and self.cur_token.type ~= Token.type.rsquirly do
		local stmt = self:parse_stmt()
		if stmt then
			table.insert(program.stmts, stmt)
		end
	end
	return program
end

function Parser:parse_stmt()
	Log.dbg("parse_stmt")
	if self.cur_token.type == Token.type.let then
		return self:parse_let_stmt()
	elseif self.cur_token.type == Token.type.return_ then
		return self:parse_return_stmt()
	elseif self.cur_token.type == Token.type.if_ then
		return self:parse_if_stmt()
	elseif self.cur_token.type == Token.type.while_ then
		return self:parse_while_stmt()
	elseif self.cur_token.type == Token.type.fn then
		return self:parse_fn_decl()
	else
		return self:parse_expr_stmt()
	end
end

function Parser:parse_while_stmt()
	Log.dbg("parse_while_stmt")
	local stmt = Node({
		type = "while",
	})
	self:next_token()
	stmt.cond = self:parse_expr(0)
	if self.cur_token.type ~= Token.type.lsquirly then
		self:expected_token(Token.type.lsquirly)
		return nil
	end
	stmt.block = self:parse_block()
	if self.cur_token.type ~= Token.type.rsquirly then
		self:expected_token(Token.type.rsquirly)
		return nil
	end
	return stmt
end

function Parser:parse_let_stmt()
	Log.dbg("parse_let_stmt")
	local stmt = Node({
		type = "let",
	})
	self:next_token()
	if self.cur_token.type ~= Token.type.ident then
		self:expected_token(Token.type.ident)
		return nil
	end
	stmt.name = ffi.string(self.cur_token.literal)
	self:next_token()
	if self.cur_token.type ~= Token.type.op or ffi.string(self.cur_token.literal) ~= "=" then
		self:expected_token(Token.type.op)
		return nil
	end
	self:next_token()
	stmt.value = self:parse_expr(0)
	if self.cur_token.type == Token.type.semicolon then
		self:next_token()
	else
		self:expected_token(Token.type.semicolon)
	end
	return stmt
end

function Parser:parse_return_stmt()
	Log.dbg("parse_return_stmt")
	local stmt = Node({
		type = "return",
	})
	self:next_token()
	if self.cur_token.type == Token.type.semicolon then
		self:next_token()
	else
		stmt.value = self:parse_expr(0)
	end
	if self.cur_token.type == Token.type.semicolon then
		self:next_token()
	else
		self:expected_token(Token.type.semicolon)
		return nil
	end
	return stmt
end

function Parser:parse_if_stmt()
	Log.dbg("parse_if_stmt")
	local stmt = Node({
		type = "if",
	})
	self:next_token()
	stmt.cond = self:parse_expr(0)
	if self.cur_token.type ~= Token.type.lsquirly then
		self:expected_token(Token.type.lsquirly)
		return nil
	end
	stmt.conseq = self:parse_block()
	if self.cur_token.type ~= Token.type.rsquirly then
		self:expected_token(Token.type.rsquirly)
		return nil
	end
	if self.cur_token.type == Token.type.else_ then
		self:next_token()
		if self.cur_token.type ~= Token.type.lsquirly then
			self:expected_token(Token.type.lsquirly)
			return nil
		end
		stmt.alt = self:parse_block()
		if self.cur_token.type ~= Token.type.rsquirly then
			self:expected_token(Token.type.rsquirly)
			return nil
		end
	end
	return stmt
end

function Parser:parse_expr_stmt()
	Log.dbg("parse_expr_stmt")
	local stmt = Node({
		type = "expr",
	})
	stmt.expr = self:parse_expr(0)
	if self.cur_token.type == Token.type.semicolon then
		self:next_token()
	end
	return stmt
end

function Parser:parse_expr(precedence)
	Log.dbg("parse_expr " .. tostring(self.cur_token))
	local prefix = self.prefix_parse_fns[tonumber(self.cur_token.type)]
	if not prefix then
		Log.error("no prefix parse function for " .. tostring(self.cur_token))
		self:expected_token(Token.type.eof)
		return nil
	end
	local left = prefix(self)
	while
		self.cur_token.type ~= Token.type.semicolon
		and precedence < self:peek_precedence()
		and self:peek_precedence() >= 0
	do
		local infix = self.infix_parse_fns[ffi.string(self.cur_token.literal)]
		if not infix then
			return left
		end
		self:next_token()
		left = infix(self, left)
	end
	return self:parse_assignment(left)
end

function Parser:parse_assignment(lhs)
	Log.dbg("parse_assignment " .. tostring(self.cur_token))
	if self.cur_token.type ~= Token.type.op then
		if self.cur_token.type == Token.type.lparen then
			return self:parse_call_expr(lhs)
		end
		return lhs
	end
	local expr = Node({
		type = "assign",
		lhs = lhs,
	})
	self:next_token()
	expr.rhs = self:parse_expr(0)
	return expr
end

function Parser:peek_precedence()
	Log.dbg("peek_precedence " .. tostring(self.cur_token))
	if self.cur_token.literal == nil then
		return -1
	end
	local precedence = self.precedences[ffi.string(self.cur_token.literal)]
	if precedence then
		return precedence
	end
	return -1
end

Parser.precedences = {
	["*"] = 4,
	["/"] = 4,
	["%"] = 4,
	["+"] = 3,
	["-"] = 3,
	["=="] = 2,
	["!="] = 2,
	["<"] = 1,
	[">"] = 1,
	["<="] = 1,
	[">="] = 1,
	["&&"] = 0,
	["||"] = 0,
}
Parser.infix_parse_fns = {
	["("] = function(self)
		return self:parse_call_expr()
	end,
	["*"] = function(self, left)
		return self:parse_infix_expr("*", left, 0)
	end,
	["/"] = function(self, left)
		return self:parse_infix_expr("/", left, 0)
	end,
	["+"] = function(self, left)
		return self:parse_infix_expr("+", left, 1)
	end,
	["-"] = function(self, left)
		return self:parse_infix_expr("-", left, 1)
	end,
	["=="] = function(self, left)
		return self:parse_infix_expr("==", left, 2)
	end,
	["!="] = function(self, left)
		return self:parse_infix_expr("/=", left, 2)
	end,
	["<"] = function(self, left)
		return self:parse_infix_expr("<", left, 3)
	end,
	[">"] = function(self, left)
		return self:parse_infix_expr(">", left, 3)
	end,
	["<="] = function(self, left)
		return self:parse_infix_expr("<=", left, 3)
	end,
	[">="] = function(self, left)
		return self:parse_infix_expr(">=", left, 3)
	end,
	["&&"] = function(self, left)
		return self:parse_infix_expr("&&", left, 4)
	end,
	["||"] = function(self, left)
		return self:parse_infix_expr("||", left, 4)
	end,
}

function Parser:parse_infix_expr(op, left, precedence)
	Log.dbg("binop " .. tostring(self.cur_token))
	local expr = Node({
		type = "binop",
		operator = op,
		left = left,
	})
	expr.right = self:parse_expr(precedence)
	return expr
end
Parser.prefix_parse_fns = {
	[tonumber(Token.type.ident)] = function(self)
		return self:parse_ident_expr()
	end,
	[tonumber(Token.type.int)] = function(self)
		return self:parse_int()
	end,
	[tonumber(Token.type.string)] = function(self)
		return self:parse_string()
	end,
	[tonumber(Token.type.lparen)] = function(self)
		return self:parse_grouped_expr()
	end,
	[tonumber(Token.type.lbracket)] = function(self)
		return self:parse_list_expr()
	end,
	[tonumber(Token.type.lsquirly)] = function(self)
		return self:parse_dict_expr()
	end,
	[tonumber(Token.type.fn)] = function(self)
		return self:parse_func_expr()
	end,
}

function Parser:parse_list_expr()
	Log.dbg("parse_list_expr")
	local expr = Node({
		type = "list",
	})
	expr.values = {}
	self:next_token()
	while self.cur_token.type ~= Token.type.rbracket do
		local value = self:parse_expr(0)
		if not value then
			self:expected_token(Token.type.rbracket)
			return nil
		end
		table.insert(expr.values, value)
		if self.cur_token.type == Token.type.comma then
			self:next_token()
		else
			break
		end
	end
	if self.cur_token.type ~= Token.type.rbracket then
		self:expected_token(Token.type.rbracket)
		return nil
	end
	self:next_token()
	return expr
end

function Parser:parse_dict_expr()
	local expr = Node({
		type = "dict",
	})
	expr.values = {}
	if self.cur_token.type ~= Token.type.lsquirly then
		self:expected_token(Token.type.lsquirly)
		return nil
	end
	self:next_token()
	while self.cur_token.type ~= Token.type.rsquirly do
		local key = ffi.string(self.cur_token.literal)
		self:next_token()
		if self.cur_token.type ~= Token.type.colon then
			self:expected_token(Token.type.colon)
			return nil
		end
		self:next_token()

		local value = self:parse_expr(0)
		if not value then
			self:expected_token(Token.type.rsquirly)
			return nil
		end
		expr.values[key] = value
		if self.cur_token.type == Token.type.comma then
			self:next_token()
		else
			break
		end
	end
	if self.cur_token.type ~= Token.type.rsquirly then
		self:expected_token(Token.type.rsquirly)
		return nil
	end
	self:next_token()
	return expr
end

function Parser:parse_string()
	local expr = Node({
		type = "string",
	})
	expr.value = ffi.string(self.cur_token.literal)
	self:next_token()
	return expr
end

function Parser:parse_int()
	local expr = Node({
		type = "int",
	})
	expr.value = tonumber(ffi.string(self.cur_token.literal))
	self:next_token()
	return expr
end

function Parser:parse_grouped_expr()
	self:next_token()
	local expr = self:parse_expr(0)
	if self.cur_token.type ~= Token.type.rparen then
		self:expected_token(Token.type.rparen)
		return nil
	end
	self:next_token()
	return Node({
		type = "parenthesized",
		expr = expr,
	})
end

function Parser:parse_ident_expr(no_call)
	local expr = Node({
		type = "ident",
	})
	expr.value = ffi.string(self.cur_token.literal)
	self:next_token()
	while
		self.cur_token.type == Token.type.dot
		or self.cur_token.type == Token.type.colon
		or self.cur_token.type == Token.type.lbracket
		or self.cur_token.type == Token.type.lparen
	do
		if self.cur_token.type == Token.type.dot then
			self:next_token()
			expr = Node({
				type = "member",
				lhs = expr,
				rhs = ffi.string(self.cur_token.literal),
			})
			self:next_token()
		elseif self.cur_token.type == Token.type.lbracket then
			self:next_token()
			local index = self:parse_expr(0)
			if self.cur_token.type ~= Token.type.rbracket then
				self:expected_token(Token.type.rbracket)
				return nil
			end
			self:next_token()
			expr = Node({
				type = "index",
				lhs = expr,
				rhs = index,
			})
		elseif self.cur_token.type == Token.type.colon then
			self:next_token()
			expr = Node({
				type = "method",
				lhs = expr,
				rhs = ffi.string(self.cur_token.literal),
			})
			self:next_token()
		elseif not no_call then
			expr = self:parse_call_expr(expr)
		else
			return expr
		end
	end
	return expr
end

function Parser:parse_fn_decl()
	Log.dbg("func")
	local expr = Node({
		type = "func_decl",
	})
	self:next_token()
	expr.name = self:parse_ident_expr(true)
	if self.cur_token.type == Token.type.colon then
		self:next_token()
		expr.name = Node({
			type = "method",
			lhs = expr.name,
			rhs = ffi.string(self.cur_token.literal),
		})
		self:next_token()
	end

	if self.cur_token.type ~= Token.type.lparen then
		self:expected_token(Token.type.lparen)
		return nil
	else
		self:next_token()
	end
	expr.params = self:parse_func_params()
	if self.cur_token.type ~= Token.type.lsquirly then
		self:expected_token(Token.type.lsquirly)
		return nil
	else
		self:next_token()
	end
	expr.body = self:parse_block()
	if self.cur_token.type ~= Token.type.rsquirly then
		self:expected_token(Token.type.rsquirly)
		return nil
	else
		self:next_token()
	end
	if self.cur_token.type == Token.type.semicolon then
		self:next_token()
	end
	return expr
end

function Parser:parse_func_expr()
	Log.dbg("func")
	local expr = Node({
		type = "func",
	})
	self:next_token()
	if self.cur_token.type ~= Token.type.lparen then
		self:expected_token(Token.type.lparen)
		return nil
	else
		self:next_token()
	end
	expr.params = self:parse_func_params()
	if self.cur_token.type ~= Token.type.lsquirly then
		self:expected_token(Token.type.lsquirly)
		return nil
	else
		self:next_token()
	end
	expr.body = self:parse_block()
	if self.cur_token.type ~= Token.type.rsquirly then
		self:expected_token(Token.type.rsquirly)
		return nil
	else
		self:next_token()
	end
	return expr
end

function Parser:parse_func_params()
	local params = {}
	if self.cur_token.type == Token.type.rparen then
		self:next_token()
		return params
	end
	table.insert(params, ffi.string(self.cur_token.literal))
	self:next_token()
	while self.cur_token.type == Token.type.comma do
		self:next_token()
		table.insert(params, ffi.string(self.cur_token.literal))
		self:next_token()
	end
	if self.cur_token.type ~= Token.type.rparen then
		self:expected_token(Token.type.rparen)
		return nil
	end
	self:next_token()
	return params
end

function Parser:parse_call_expr(callee)
	local expr = Node({
		type = "call",
	})
	if callee then
		expr.func = callee
	else
		expr.func = self:parse_expr(0)
	end
	if self.cur_token.type == Token.type.colon then
		self:next_token()
		expr.func = Node({
			type = "method",
			lhs = expr.func,
			rhs = ffi.string(self.cur_token.literal),
		})
		self:next_token()
	end
	if self.cur_token.type ~= Token.type.lparen then
		self:expected_token(Token.type.lparen)
		return nil
	end
	self:next_token()
	expr.args = self:parse_call_args()
	if self.cur_token.type ~= Token.type.rparen then
		self:expected_token(Token.type.rparen)
		return nil
	end
	self:next_token()
	return expr
end

function Parser:parse_call_args()
	local args = {}
	if self.cur_token.type == Token.type.rparen then
		return args
	end
	table.insert(args, self:parse_expr(0))
	while self.cur_token.type == Token.type.comma do
		self:next_token()
		table.insert(args, self:parse_expr(0))
	end
	return args
end

return Parser
