local Log = {
	level = "debug",
}

function Log.dbg(...)
	if Log.level ~= "debug" then
		return
	end
	print("[DEBUG]", ...)
end

function Log.info(...)
	if Log.level ~= "info" and Log.level ~= "debug" then
		return
	end
	print("[INFO]", ...)
end

function Log.error(...)
	print("[ERROR]", ...)
end

function Log.init(level)
	Log.level = level
end

return Log
