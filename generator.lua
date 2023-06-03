local Lexer = require("lexer")
local Parser = require("parser")
local Node = require("node")
local Log = require("log")

local Generator = {}
Generator.__index = Generator

function Generator:new(ast)
	return setmetatable({
		ast = ast,
	}, Generator)
end

function Generator:generate()
	return self:gen_block(self.ast)
end

function Generator:gen_block(block)
	Log.dbg("gen_block")
	local stmts = {}
	for _, stmt in ipairs(block.stmts) do
		table.insert(stmts, self:gen_stmt(stmt))
	end
	return table.concat(stmts, "\n")
end

function Generator:gen_stmt(stmt)
	Log.dbg("gen_stmt")
	if stmt.type == "return" then
		return "return " .. self:gen_expr(stmt.value)
	elseif stmt.type == "expr" then
		return self:gen_expr(stmt.expr)
	elseif stmt.type == "if" then
		local str = "if " .. self:gen_expr(stmt.cond) .. " then\n" .. self:gen_block(stmt.block)
		if stmt.else_block then
			str = str .. " else \n" .. self:gen_block(stmt.else_block) .. "\nend"
		else
			str = str .. "\nend"
		end
		return str
	elseif stmt.type == "while" then
		return "while " .. self:gen_expr(stmt.cond) .. " do\n" .. self:gen_block(stmt.block) .. "\nend"
	elseif stmt.type == "let" then
		return "local " .. stmt.name .. " = " .. self:gen_expr(stmt.value)
	elseif stmt.type == "func_decl" then
		return "function "
			.. self:gen_expr(stmt.name)
			.. "("
			.. table.concat(stmt.params, ", ")
			.. ")\n"
			.. self:gen_block(stmt.body)
			.. "\nend"
	else
		return "unknown stmt type " .. stmt.type
	end
end

function Generator:gen_expr(expr)
	Log.dbg("gen_expr")
	if expr.type == "string" then
		return '"' .. expr.value .. '"'
	elseif expr.type == "int" then
		return expr.value
	elseif expr.type == "bool" then
		return expr.value and "true" or "false"
	elseif expr.type == "nil" then
		return "nil"
	elseif expr.type == "list" then
		local elems = {}
		for _, elem in ipairs(expr.values) do
			table.insert(elems, self:gen_expr(elem))
		end
		return "{" .. table.concat(elems, ", ") .. "}"
	elseif expr.type == "dict" then
		local elems = {}
		for k, v in pairs(expr.values) do
			table.insert(elems, k.value .. " = " .. self:gen_expr(v))
		end
		return "{" .. table.concat(elems, ", ") .. "}"
	elseif expr.type == "call" then
		local args = {}
		for _, arg in ipairs(expr.args) do
			table.insert(args, self:gen_expr(arg))
		end
		return self:gen_expr(expr.func) .. "(" .. table.concat(args, ", ") .. ")"
	elseif expr.type == "index" then
		return self:gen_expr(expr.table) .. "[" .. self:gen_expr(expr.index) .. "]"
	elseif expr.type == "binop" then
		return self:gen_expr(expr.left) .. " " .. expr.operator .. " " .. self:gen_expr(expr.right)
	elseif expr.type == "unop" then
		return expr.op .. self:gen_expr(expr.expr)
	elseif expr.type == "member" then
		return self:gen_expr(expr.lhs) .. "." .. expr.rhs
	elseif expr.type == "ident" then
		return expr.value
	elseif expr.type == "parenthesized" then
		return "(" .. self:gen_expr(expr.expr) .. ")"
	elseif expr.type == "method" then
		return self:gen_expr(expr.lhs) .. ":" .. expr.rhs
	elseif expr.type == "func" then
		local args = {}
		for _, arg in ipairs(expr.params) do
			table.insert(args, arg.value)
		end
		return "function(" .. table.concat(args, ", ") .. ")\n" .. self:gen_block(expr.body) .. "\nend"
	else
		return "unknown expr type " .. expr.type
	end
end

local test = function()
	local parser = Parser:new(Lexer:new([[
	fn a:x() {

	};
	let x = { x = 10, y = 25 };
	let x = a:y();
]]))
	local ast = parser:parse()
	-- print(program)
	if #parser.errors > 0 then
		for _, err in ipairs(parser.errors) do
			print(err)
		end
	end
	local gen = Generator:new(ast)
	print(gen:generate())
end
test()

return Generator
