local Log = require("log")

local Generator = {}
Generator.__index = Generator

function Generator:new(ast)
	return setmetatable({
		ast = ast,
	}, Generator)
end

function Generator:generate()
	return self:gen_block(self.ast, 0)
end

function Generator:gen_block(block, indent)
	Log.dbg("gen_block")
	local stmts = {}
	for _, stmt in ipairs(block.stmts) do
		table.insert(stmts, self:gen_stmt(stmt, indent))
	end
	return table.concat(stmts, "\n")
end

function Generator:gen_stmt(stmt, indent)
	indent = indent or 0
	Log.dbg("gen_stmt")
	local indent_str = string.rep("  ", indent)
	if stmt.type == "return" then
		return indent_str .. "return " .. self:gen_expr(stmt.value, indent)
	elseif stmt.type == "expr" then
		return indent_str .. self:gen_expr(stmt.expr, indent)
	elseif stmt.type == "if" then
		local str = indent_str
			.. "if "
			.. self:gen_expr(stmt.cond, indent)
			.. " then\n"
			.. self:gen_block(stmt.block, indent + 1)
		if stmt.else_block then
			str = str .. " else \n" .. self:gen_block(stmt.else_block, indent + 1) .. "\nend"
		else
			str = str .. "\nend"
		end
		return str
	elseif stmt.type == "while" then
		return indent_str
			.. "while "
			.. self:gen_expr(stmt.cond, indent)
			.. " do\n"
			.. self:gen_block(stmt.block, indent + 1)
			.. "\nend"
	elseif stmt.type == "let" then
		return indent_str .. "local " .. stmt.name .. " = " .. self:gen_expr(stmt.value, indent)
	elseif stmt.type == "func_decl" then
		return indent_str
			.. "function "
			.. self:gen_expr(stmt.name, indent)
			.. "("
			.. table.concat(stmt.params, ", ")
			.. ")\n"
			.. self:gen_block(stmt.body, indent + 1)
			.. "\nend\n"
	else
		return "unknown stmt type " .. stmt.type
	end
end

function Generator:gen_expr(expr, indent)
	Log.dbg("gen_expr")
	local indent_str = string.rep("  ", indent)
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
			table.insert(elems, self:gen_expr(elem, indent))
		end
		return "{" .. table.concat(elems, ", ") .. "}"
	elseif expr.type == "dict" then
		local elems = {}
		for k, v in pairs(expr.values) do
			table.insert(elems, "\n  " .. indent_str .. k .. " = " .. self:gen_expr(v, indent + 1))
		end
		return "{" .. table.concat(elems, ", ") .. "\n" .. indent_str .. "}"
	elseif expr.type == "call" then
		local args = {}
		for _, arg in ipairs(expr.args) do
			table.insert(args, self:gen_expr(arg, indent))
		end
		return self:gen_expr(expr.func, indent) .. "(" .. table.concat(args, ", ") .. ")"
	elseif expr.type == "index" then
		return self:gen_expr(expr.table, indent) .. "[" .. self:gen_expr(expr.index, indent) .. "]"
	elseif expr.type == "binop" then
		return self:gen_expr(expr.left, indent) .. " " .. expr.operator .. " " .. self:gen_expr(expr.right, indent)
	elseif expr.type == "unop" then
		return expr.op .. self:gen_expr(expr.expr, indent)
	elseif expr.type == "member" then
		return self:gen_expr(expr.lhs, indent) .. "." .. expr.rhs
	elseif expr.type == "ident" then
		return expr.value
	elseif expr.type == "parenthesized" then
		return "(" .. self:gen_expr(expr.expr, indent) .. ")"
	elseif expr.type == "method" then
		return self:gen_expr(expr.lhs, indent) .. ":" .. expr.rhs
	elseif expr.type == "assign" then
		return self:gen_expr(expr.lhs, indent) .. " = " .. self:gen_expr(expr.rhs, indent)
	elseif expr.type == "func" then
		local args = {}
		for _, arg in ipairs(expr.params) do
			table.insert(args, arg.value)
		end
		return "function("
			.. table.concat(args, ", ")
			.. ")\n"
			.. self:gen_block(expr.body, indent)
			.. "\n"
			.. indent_str
			.. "end"
	else
		return "unknown expr type " .. expr.type
	end
end

-- local test = function()
-- 	local parser = Parser:new(Lexer:new([[
-- 	fn a:x() {
-- 		print("test")
-- 	};
-- 	let x = a:y({ a :  { x: fn() {} } });
-- ]]))
-- 	local ast = parser:parse()
-- 	-- print(program)
-- 	if #parser.errors > 0 then
-- 		for _, err in ipairs(parser.errors) do
-- 			print(err)
-- 		end
-- 	end
-- 	local gen = Generator:new(ast)
-- 	print(gen:generate())
-- end

return Generator
