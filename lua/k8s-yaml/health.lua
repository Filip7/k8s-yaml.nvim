local uv = vim.loop
local curl = require("plenary.curl")
local config = require("k8s-yaml.config")

local M = {}

-- Health check function for :checkhealth
M.check = function()
	local health = vim.health or require("health")
	health.start("k8s-yaml.nvim")

	-- Check Neovim version
	if vim.fn.has("nvim-0.8") == 0 then
		health.error("Neovim version 0.8 or higher is required")
	else
		health.ok("Neovim version: " .. vim.version().major .. "." .. vim.version().minor)
	end

	-- Check plenary dependency
	local ok, _ = pcall(require, "plenary")
	if ok then
		health.ok("plenary.nvim is available")
	else
		health.error("plenary.nvim is required but not found")
	end

	-- Check yaml-language-server
	local clients = vim.lsp.get_clients({ name = "yamlls" })
	if #clients > 0 then
		health.ok("yaml-language-server is running")
	else
		health.warn("yaml-language-server is not running. Install and configure it for schema validation.")
	end

	-- Check cache directory
	local cache_dir = config.current.cache_dir
	local stat = uv.fs_stat(cache_dir)
	if stat then
		if stat.type == "directory" then
			health.ok("Cache directory exists: " .. cache_dir)
			-- Check if writable
			local test_file = cache_dir .. "/.test"
			local file = io.open(test_file, "w")
			if file then
				file:close()
				os.remove(test_file)
				health.ok("Cache directory is writable")
			else
				health.error("Cache directory is not writable: " .. cache_dir)
			end
		else
			health.error("Cache path exists but is not a directory: " .. cache_dir)
		end
	else
		health.warn("Cache directory does not exist yet. It will be created when needed: " .. cache_dir)
	end

	-- Check GitHub API accessibility (optional)
	local url = config.current.github_base_api_url .. "/" .. config.current.schemas_catalog
	local response = curl.get(url, { headers = config.current.github_headers, timeout = 5000 })
	if response.status == 200 then
		health.ok("GitHub API is accessible")
	else
		health.warn("GitHub API is not accessible. CRD schema fetching may fail.")
	end
end

return M

