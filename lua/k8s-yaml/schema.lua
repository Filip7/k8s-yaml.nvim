local github = require("k8s-yaml.github")

local M = {}

-- Extract apiVersion and kind from YAML content, handling multi-manifest files
M.extract_api_version_and_kind = function(buffer_content)
	-- Split content by --- separators to handle multi-manifest files
	local manifests = {}
	local current_manifest = {}

	for line in buffer_content:gmatch("([^\r\n]*)\r?\n?") do
		if line:match("^%-%-%-%s*$") then
			-- Found separator, save current manifest if it has content
			if #current_manifest > 0 then
				table.insert(manifests, table.concat(current_manifest, "\n"))
				current_manifest = {}
			end
		else
			table.insert(current_manifest, line)
		end
	end

	-- Don't forget the last manifest
	if #current_manifest > 0 then
		table.insert(manifests, table.concat(current_manifest, "\n"))
	end

	-- Process each manifest to find the first valid Kubernetes resource
	for _, manifest in ipairs(manifests) do
		if manifest:match("apiVersion:") and manifest:match("kind:") then
			local api_version = manifest:match("apiVersion:%s*([%w%.%/%-]+)")
			local kind = manifest:match("kind:%s*([%w%-]+)")
			if api_version and kind then
				return api_version, kind
			end
		end
	end

	-- Fallback to original approach if no manifests found
	buffer_content = buffer_content:gsub("^%-%-%-%s*\n", "")
	local api_version = buffer_content:match("apiVersion:%s*([%w%.%/%-]+)")
	local kind = buffer_content:match("kind:%s*([%w%-]+)")
	return api_version, kind
end

-- Analyze multi-manifest YAML files and return information about all resources
M.analyze_multi_manifest = function(buffer_content)
	local resources = {}
	local manifests = {}
	local current_manifest = {}

	for line in buffer_content:gmatch("([^\r\n]*)\r?\n?") do
		if line:match("^%-%-%-%s*$") then
			-- Found separator, save current manifest if it has content
			if #current_manifest > 0 then
				table.insert(manifests, table.concat(current_manifest, "\n"))
				current_manifest = {}
			end
		else
			table.insert(current_manifest, line)
		end
	end

	-- Don't forget the last manifest
	if #current_manifest > 0 then
		table.insert(manifests, table.concat(current_manifest, "\n"))
	end

	-- Analyze each manifest
	for i, manifest in ipairs(manifests) do
		if manifest:match("apiVersion:") and manifest:match("kind:") then
			local api_version = manifest:match("apiVersion:%s*([%w%.%/%-]+)")
			local kind = manifest:match("kind:%s*([%w%-]+)")
			local name = manifest:match("name:%s*([%w%-]+)") or "unnamed"

			if api_version and kind then
				table.insert(resources, {
					index = i,
					api_version = api_version,
					kind = kind,
					name = name,
					manifest = manifest
				})
			end
		end
	end

	return resources
end

-- Normalize apiVersion and kind to match CRD schema naming convention
M.normalize_crd_name = function(api_version, kind)
	if not api_version or not kind then
		return nil
	end

	local group, version = api_version:match("([^/]+)/([^/]+)")
	if not group or not version then
		return nil
	end

	local normalized_kind = kind:lower()
	return group .. "/" .. normalized_kind .. "_" .. version .. ".json"
end

-- Match the CRD schema based on apiVersion and kind
M.match_crd = function(buffer_content)
	local api_version, kind = M.extract_api_version_and_kind(buffer_content)
	if not api_version or not kind then
		return nil
	end

	local crd_name = M.normalize_crd_name(api_version, kind)
	if not crd_name then
		return nil
	end

	local all_crds = github.list_github_tree()
	for _, crd in ipairs(all_crds) do
		if crd:match(crd_name) then
			return crd
		end
	end
	return nil
end

-- Attach a schema to the buffer
M.attach_schema = function(schema_url, description)
	local clients = vim.lsp.get_clients({ name = "yamlls" })
	if #clients == 0 then
		vim.notify("yaml-language-server is not active.", vim.log.levels.WARN)
		return false
	end

	local yaml_client = clients[1]
	if not yaml_client.config or not yaml_client.notify then
		vim.notify("yaml-language-server client is not properly configured", vim.log.levels.ERROR)
		return false
	end

	yaml_client.config.settings = yaml_client.config.settings or {}
	yaml_client.config.settings.yaml = yaml_client.config.settings.yaml or {}
	yaml_client.config.settings.yaml.schemas = yaml_client.config.settings.yaml.schemas or {}

	-- Support multiple schemas per buffer by using an array of file patterns
	local current_schemas = yaml_client.config.settings.yaml.schemas[schema_url]
	if not current_schemas then
		-- First schema for this URL
		yaml_client.config.settings.yaml.schemas[schema_url] = { "*.yaml" }
	elseif type(current_schemas) == "string" then
		-- Convert single pattern to array
		yaml_client.config.settings.yaml.schemas[schema_url] = { current_schemas, "*.yaml" }
	elseif type(current_schemas) == "table" then
		-- Add to existing array if not already present
		local found = false
		for _, pattern in ipairs(current_schemas) do
			if pattern == "*.yaml" then
				found = true
				break
			end
		end
		if not found then
			table.insert(current_schemas, "*.yaml")
		end
	end

	local success = pcall(function()
		yaml_client.notify("workspace/didChangeConfiguration", {
			settings = yaml_client.config.settings,
		})
	end)

	if success then
		vim.notify("Attached schema: " .. description, vim.log.levels.INFO)
		return true
	else
		vim.notify("Failed to attach schema: " .. description, vim.log.levels.ERROR)
		return false
	end
end

return M

