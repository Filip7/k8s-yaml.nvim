local M = {}

-- Default configuration
M.defaults = {
	schemas_catalog = "datreeio/CRDs-catalog",
	schema_catalog_branch = "main",
	github_base_api_url = "https://api.github.com/repos",
	github_headers = {
		Accept = "application/vnd.github+json",
		["X-GitHub-Api-Version"] = "2022-11-28",
	},
	kubernetes_schemas_repo = "yannh/kubernetes-json-schema",
	kubernetes_schemas_branch = "master",
	kubernetes_schemas_path = "master",
	schema_cache = {
		trees = nil,
		schemas = {},
	},
	cache_ttl = 86400, -- Cache time-to-live in seconds (24 hours)
	cache_dir = vim.fn.stdpath("cache") .. "/k8s-yaml-schemas", -- Cache directory
	lazy_load_schemas = true, -- Only load schemas when needed for efficiency
	preload_common_schemas = false, -- Preload frequently used schemas on startup
	handle_multi_manifest = true, -- Process multi-manifest YAML files (default: true)
	auto_attach = true, -- Automatically attach schemas when opening YAML files (default: true)
}

-- Current configuration
M.current = {}

-- Initialize the plugin with user configuration
M.setup = function(user_config)
	M.current = vim.tbl_deep_extend("force", M.defaults, user_config or {})

	-- Check Neovim version
	if vim.fn.has("nvim-0.8") == 0 then
		vim.notify("k8s-yaml.nvim requires Neovim 0.8 or higher", vim.log.levels.ERROR)
		return
	end

	M.current.schema_url = "https://raw.githubusercontent.com/"
		.. M.current.schemas_catalog
		.. "/"
		.. M.current.schema_catalog_branch

	-- Create user commands
	vim.api.nvim_create_user_command("K8sYamlAttachSchema", function()
		local bufnr = vim.api.nvim_get_current_buf()
		require("k8s-yaml").init(bufnr)
	end, { desc = "Manually attach Kubernetes schema to current buffer" })

	vim.api.nvim_create_user_command("K8sYamlClearCache", function()
		local cache_dir = M.current.cache_dir
		local success = true
		for file in vim.fs.dir(cache_dir) do
			local path = cache_dir .. "/" .. file
			local ok = os.remove(path)
			if not ok then
				success = false
			end
		end
		if success then
			vim.notify("Cache cleared successfully", vim.log.levels.INFO)
		else
			vim.notify("Failed to clear some cache files", vim.log.levels.WARN)
		end
	end, { desc = "Clear the schema cache directory" })

	vim.api.nvim_create_user_command("K8sYamlPreloadSchemas", function()
		require("k8s-yaml.github").preload_common_schemas()
	end, { desc = "Preload commonly used Kubernetes schemas" })

	vim.api.nvim_create_user_command("K8sYamlShowResources", function()
		local bufnr = vim.api.nvim_get_current_buf()
		local buffer_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
		local schema = require("k8s-yaml.schema")
		local resources = schema.analyze_multi_manifest(buffer_content)

		if #resources == 0 then
			vim.notify("No Kubernetes resources found in current buffer", vim.log.levels.INFO)
			return
		end

		local lines = { "Kubernetes resources in current file:" }
		for _, resource in ipairs(resources) do
			table.insert(lines, string.format("  %d. %s/%s (%s)",
				resource.index, resource.kind, resource.name, resource.api_version))
		end

		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end, { desc = "Show all Kubernetes resources in the current buffer" })

	vim.api.nvim_create_user_command("K8sYamlToggleAutoAttach", function()
		M.current.auto_attach = not M.current.auto_attach
		if M.current.auto_attach then
			vim.notify("Auto-attachment enabled", vim.log.levels.INFO)
		else
			vim.notify("Auto-attachment disabled", vim.log.levels.INFO)
		end
	end, { desc = "Toggle automatic schema attachment on/off" })
end

return M

