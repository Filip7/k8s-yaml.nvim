local curl = require("plenary.curl")
local config = require("k8s-yaml.config")

local M = {}

-- Download and cache the list of CRDs
M.list_github_tree = function()
	if config.current.schema_cache.trees then
		return config.current.schema_cache.trees
	end

	local url = config.current.github_base_api_url
		.. "/"
		.. config.current.schemas_catalog
		.. "/git/trees/"
		.. config.current.schema_catalog_branch
	local response = curl.get(url, {
		headers = config.current.github_headers,
		query = { recursive = 1 },
	})

	if response.status == 200 then
		local success, body = pcall(vim.fn.json_decode, response.body)
		if not success then
			vim.notify("Failed to parse CRD list JSON from GitHub", vim.log.levels.ERROR)
			return {}
		end
		local trees = {}
		for _, tree in ipairs(body.tree or {}) do
			if tree.type == "blob" and tree.path:match("%.json$") then
				table.insert(trees, tree.path)
			end
		end
		config.current.schema_cache.trees = trees
		return trees
	else
		vim.notify("Failed to fetch CRD list from GitHub (status: " .. response.status .. ")", vim.log.levels.ERROR)
		return {}
	end
end

-- Get the correct Kubernetes schema URL based on apiVersion and kind
M.get_kubernetes_schema_url = function(api_version, kind)
	local cache = require("k8s-yaml.cache")
	cache.ensure_cache_dir()

	local version = api_version:match("/([%w%-]+)$") or api_version
	local schema_name = kind:lower() .. "-" .. version .. ".json"
	local base_url = "https://raw.githubusercontent.com/"
		.. config.current.kubernetes_schemas_repo
		.. "/refs/heads/"
		.. config.current.kubernetes_schemas_branch
		.. "/"
		.. config.current.kubernetes_schemas_path
		.. "/"
	local url_with_version = base_url .. schema_name
	local url_without_version = base_url .. kind:lower() .. ".json"

	-- Try with version first
	local cache_path = cache.get_cache_file_path(schema_name)
	if cache.is_cache_valid(cache_path) then
		return "file://" .. cache_path
	end

	-- Download and cache if not in cache or expired
	local response = curl.get(url_with_version, { headers = config.current.github_headers })
	if response.status == 200 then
		cache.save_to_cache(cache_path, response.body)
		return "file://" .. cache_path
	end

	-- Try without version
	local schema_name_no_version = kind:lower() .. ".json"
	local cache_path_no_version = cache.get_cache_file_path(schema_name_no_version)

	if cache.is_cache_valid(cache_path_no_version) then
		return "file://" .. cache_path_no_version
	end

	local response_no_version = curl.get(url_without_version, { headers = config.current.github_headers })
	if response_no_version.status == 200 then
		cache.save_to_cache(cache_path_no_version, response_no_version.body)
		return "file://" .. cache_path_no_version
	end

	return nil
end

-- Preload commonly used Kubernetes schemas for better performance
M.preload_common_schemas = function()
	local cache = require("k8s-yaml.cache")
	cache.ensure_cache_dir()

	local common_resources = {
		"pod",
		"service",
		"deployment",
		"configmap",
		"secret",
		"namespace",
		"persistentvolumeclaim",
		"ingress",
		"job",
		"cronjob"
	}

	vim.notify("Preloading common Kubernetes schemas...", vim.log.levels.INFO)

	local loaded = 0
	local failed = 0

	for _, resource in ipairs(common_resources) do
		local schema_url = M.get_kubernetes_schema_url("v1", resource)
		if schema_url then
			loaded = loaded + 1
		else
			failed = failed + 1
		end
	end

	vim.notify(string.format("Preloaded %d schemas (%d failed)", loaded, failed),
		failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
end

return M

