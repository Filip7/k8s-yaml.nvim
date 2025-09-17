local uv = vim.loop
local config = require("k8s-yaml.config")

local M = {}

-- Ensure cache directory exists
M.ensure_cache_dir = function()
	local cache_dir = config.current.cache_dir
	if not uv.fs_stat(cache_dir) then
		uv.fs_mkdir(cache_dir, 493) -- 493 = 0o755 in decimal
	end
end

-- Get cache file path for a schema
M.get_cache_file_path = function(schema_name)
	return config.current.cache_dir .. "/" .. schema_name:gsub("[/:]", "_")
end

-- Check if cache is valid (exists and not expired)
M.is_cache_valid = function(cache_path)
	local file_stat = uv.fs_stat(cache_path)
	if not file_stat or not file_stat.mtime then
		return false
	end

	local current_time = uv.hrtime() / 1e9 -- Convert to seconds
	local file_time = file_stat.mtime.sec

	return (current_time - file_time) < config.current.cache_ttl
end

-- Save content to cache
M.save_to_cache = function(cache_path, content)
	local file = io.open(cache_path, "w")
	if file then
		file:write(content)
		file:close()
	end
end

-- Read content from cache
M.read_from_cache = function(cache_path)
	local file = io.open(cache_path, "r")
	if file then
		local content = file:read("*a")
		file:close()
		return content
	end
	return nil
end

return M

