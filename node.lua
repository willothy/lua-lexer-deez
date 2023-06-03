local Node = {}
Node.__index = Node

function Node:display(indent)
	local indent_str = string.rep("  ", indent)
	if self.type == "binop" then
		return "("
			.. self.left:display(indent + 1)
			.. " "
			.. self.operator
			.. " "
			.. self.right:display(indent + 1)
			.. ")"
	elseif self.type == "int" then
		return tostring(self.value)
	elseif self.type == "ident" then
		return self.value
	elseif self.type == "func" then
		local params = {}
		for _, param in ipairs(self.params) do
			table.insert(params, param.value)
		end
		return "fn(" .. table.concat(params, ", ") .. ") " .. self.body:display(indent)
	elseif self.type == "block" then
		local stmts = {}
		for _, stmt in ipairs(self.stmts) do
			table.insert(stmts, stmt:display(indent + 1))
		end
		return "{\n" .. table.concat(stmts, "\n") .. "\n" .. indent_str .. "}"
	elseif self.type == "program" then
		local stmts = {}
		for _, stmt in ipairs(self.stmts) do
			table.insert(stmts, stmt:display(indent))
		end
		return table.concat(stmts, "\n")
	elseif self.type == "member" then
		return self.lhs:display(indent) .. "." .. self.rhs
	elseif self.type == "func_decl" then
		return indent_str
			.. "fn "
			.. self.name:display(indent)
			.. "("
			.. table.concat(self.params, ", ")
			.. ") "
			.. self.body:display(indent)
	elseif self.type == "parenthesized" then
		return "(" .. self.expr:display(indent) .. ")"
	elseif self.type == "index" then
		return self.lhs:display(indent) .. "[" .. self.rhs:display(indent) .. "]"
	elseif self.type == "let" then
		return indent_str .. "let " .. self.name .. " = " .. self.value:display(indent) .. ";"
	elseif self.type == "return" then
		return indent_str .. "return " .. self.value:display(indent + 1) .. ";"
	elseif self.type == "string" then
		return '"' .. self.value .. '"'
	elseif self.type == "expr" then
		if not self.expr then
			return ""
		end
		return self.expr:display(indent) .. ";"
	elseif self.type == "call" then
		local args = {}
		for _, arg in ipairs(self.args) do
			table.insert(args, arg:display(indent))
		end
		return self.func:display(indent) .. "(" .. table.concat(args, ", ") .. ")"
	elseif self.type == "list" then
		local elems = {}
		for _, elem in ipairs(self.values) do
			table.insert(elems, "\n" .. indent_str .. elem:display(indent + 1))
		end
		return "[" .. table.concat(elems, "," .. indent_str) .. "\n" .. string.rep("  ", indent - 1) .. "]"
	elseif self.type == "dict" then
		local elems = {}
		for k, v in pairs(self.values) do
			table.insert(elems, "\n" .. indent_str .. k:display(indent) .. ": " .. v:display(indent))
		end
		return "{" .. table.concat(elems, "," .. indent_str .. "  ") .. "\n" .. string.rep("  ", indent - 1) .. "}"
	elseif self.type == "if" then
		local stmts = {}
		for _, stmt in ipairs(self.stmts) do
			table.insert(stmts, stmt:display(indent + 1))
		end
		local str = indent_str .. "if " .. self.cond:display(indent + 1) .. " {\n" .. table.concat(stmts, "\n") .. "\n}"
		if self.else_stmts then
			local else_stmts = {}
			for _, stmt in ipairs(self.else_stmts) do
				table.insert(else_stmts, stmt:display(indent + 1))
			end
			str = str .. " else {\n" .. table.concat(else_stmts, "\n") .. "\n}"
		end
		return str
	else
		return "unknown node type " .. self.type
	end
end

function Node:__tostring()
	return self:display(0)
end

setmetatable(Node, {
	__call = function(_, ...)
		return Node:new(...)
	end,
})

function Node:new(obj)
	return setmetatable(obj, Node)
end

return Node
