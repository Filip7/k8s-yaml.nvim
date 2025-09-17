local config = require("k8s-yaml.config")
local schema = require("k8s-yaml.schema")
local github = require("k8s-yaml.github")

local M = {}

-- Setup function - delegate to config module
M.setup = config.setup

-- Initialize schema attachment for a buffer
M.init = function(bufnr)
	if vim.b[bufnr].schema_attached then
		return
	end
	vim.b[bufnr].schema_attached = true

	-- Check if buffer is valid and has content
	if not vim.api.nvim_buf_is_valid(bufnr) then
		vim.notify("Invalid buffer, skipping schema attachment", vim.log.levels.DEBUG)
		return
	end

	local buffer_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
	if buffer_content == "" or buffer_content:match("^%s*$") then
		vim.notify("Buffer is empty, skipping schema attachment", vim.log.levels.DEBUG)
		return
	end

	-- Check if this looks like YAML content
	if not buffer_content:match("apiVersion:") and not buffer_content:match("kind:") then
		vim.notify("Buffer doesn't appear to contain Kubernetes YAML, skipping schema attachment", vim.log.levels.DEBUG)
		return
	end

	local success = false

	-- Check for multi-manifest files if enabled
	if config.current.handle_multi_manifest then
		local resources = schema.analyze_multi_manifest(buffer_content)
		if #resources > 1 then
			vim.notify(
				string.format("Found %d Kubernetes resources in file. Using schema for first resource (%s/%s)",
					#resources, resources[1].kind, resources[1].name),
				vim.log.levels.INFO
			)
		end
	end

	local crd = schema.match_crd(buffer_content)
	if crd then
		local schema_url = config.current.schema_url .. "/" .. crd
		if schema.attach_schema(schema_url, "CRD schema for " .. crd) then
			success = true
		end
	else
		local api_version, kind = schema.extract_api_version_and_kind(buffer_content)
		if api_version and kind then
			local kubernetes_schema_url = github.get_kubernetes_schema_url(api_version, kind)
			if kubernetes_schema_url then
				if schema.attach_schema(kubernetes_schema_url, "Kubernetes schema for " .. kind) then
					success = true
				end
			else
				vim.notify(
					"No Kubernetes schema found for " .. kind .. " with apiVersion " .. api_version .. ". This might be a custom resource.",
					vim.log.levels.WARN
				)
			end
		else
			vim.notify(
				"Could not extract apiVersion and kind from YAML. Ensure the file contains valid Kubernetes YAML.",
				vim.log.levels.WARN
			)
		end
	end

	if not success then
		vim.notify(
			"Schema attachment failed. The file will use default YAML LSP validation.",
			vim.log.levels.INFO
		)
	end
end

-- Health check function - delegate to health module
M.health = function()
	require("k8s-yaml.health").check()
end

-- Debounce mechanism to prevent multiple rapid calls
local debounce_timers = {}

local function debounce_init(bufnr, delay)
	local timer_key = tostring(bufnr)
	if debounce_timers[timer_key] then
		vim.fn.timer_stop(debounce_timers[timer_key])
	end

	debounce_timers[timer_key] = vim.fn.timer_start(delay or 100, function()
		debounce_timers[timer_key] = nil
		if vim.api.nvim_buf_is_valid(bufnr) then
			require("k8s-yaml").init(bufnr)
		end
	end)
end

-- Enhanced autocommand setup for automatic schema attachment
local function setup_autocommands()
	if not config.current.auto_attach then
		return
	end

	-- FileType event for when filetype is set
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "yaml", "yaml.ansible", "helm" },
		callback = function(args)
			local bufnr = args.buf
			local clients = vim.lsp.get_clients({ name = "yamlls", bufnr = bufnr })
			if #clients > 0 then
				debounce_init(bufnr)
			else
				-- Wait for LSP to attach
				vim.api.nvim_create_autocmd("LspAttach", {
					once = true,
					buffer = bufnr,
					callback = function(lsp_args)
						local client = vim.lsp.get_client_by_id(lsp_args.data.client_id)
						if client and client.name == "yamlls" then
							debounce_init(bufnr)
						end
					end,
				})
			end
		end,
	})

	-- BufReadPost for files that are read after being opened
	vim.api.nvim_create_autocmd("BufReadPost", {
		pattern = { "*.yaml", "*.yml" },
		callback = function(args)
			local bufnr = args.buf
			local filetype = vim.bo[bufnr].filetype
			if filetype == "yaml" or filetype == "yaml.ansible" or filetype == "helm" then
				local clients = vim.lsp.get_clients({ name = "yamlls", bufnr = bufnr })
				if #clients > 0 then
					debounce_init(bufnr, 200) -- Slightly longer delay for BufReadPost
				end
			end
		end,
	})

	-- BufWritePost to re-attach schemas after saving (in case content changed)
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = { "*.yaml", "*.yml" },
		callback = function(args)
			local bufnr = args.buf
			local filetype = vim.bo[bufnr].filetype
			if filetype == "yaml" or filetype == "yaml.ansible" or filetype == "helm" then
				-- Clear the attached flag to allow re-attachment
				vim.b[bufnr].schema_attached = nil
				debounce_init(bufnr, 300) -- Longer delay for file writes
			end
		end,
	})
end

-- Initialize autocommands
setup_autocommands()

return M

