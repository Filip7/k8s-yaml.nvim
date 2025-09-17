# k8s-yaml.nvim

A Neovim plugin for Kubernetes YAML file support.

Found this discussion on Reddit <https://www.reddit.com/r/neovim/comments/1iykmqc/improving_kubernetes_yaml_support_in_neovim_crds/>.  
In the comments, there is a link to the repo of the plugin that implements this. The repo does not seem very active (even though it is a very fresh project, so give it benefit of the doubt), and the project does not have any licence, which is very concerning to me.

So I've decided to copy the original code from the poster and run it through AI models to create this nvim plugin and add some functionality that was missing.

I would like to understand neovim plugins more then I do, so I might refactor parts of this code to better understand it.

## Installation

### Using lazy.nvim

Add the following to your `lua/plugins.lua` or equivalent configuration file:

```lua
return {
  {
    "Filip7/k8s-yaml.nvim",
    config = function()
      require("k8s-yaml").setup()
    end,
    health = "k8s-yaml",
  },
}
```

Then run `:Lazy` to install the plugin.

## Usage

This plugin automatically attaches appropriate JSON schemas to Kubernetes YAML files when opened, providing validation and autocompletion through yaml-language-server.

### Multi-Manifest Support

The plugin handles YAML files containing multiple Kubernetes manifests (separated by `---`). It will:

- Detect all resources in the file
- Use the schema from the first valid Kubernetes resource found
- Display a notification when multiple resources are detected

### Automatic Schema Attachment

The plugin automatically attaches schemas when you open YAML files through multiple events:

- **FileType**: When a file's filetype is set to `yaml`, `yaml.ansible`, or `helm`
- **BufReadPost**: When a `.yaml` or `.yml` file is read
- **BufWritePost**: Re-attaches schemas after saving (in case content changed)

Features:
- **Debounced execution**: Prevents multiple rapid schema attachments
- **LSP-aware**: Waits for yaml-language-server to be available
- **Configurable**: Can be disabled with `auto_attach = false`
- **Multi-filetype support**: Works with YAML, Ansible YAML, and Helm files

Example multi-manifest file:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  key: value
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  # ... deployment spec
```

### Commands

- `:K8sYamlAttachSchema` - Manually attach schema to the current buffer
- `:K8sYamlClearCache` - Clear the cached schemas
- `:K8sYamlPreloadSchemas` - Preload commonly used Kubernetes schemas
- `:K8sYamlShowResources` - Show all Kubernetes resources in the current buffer
- `:K8sYamlToggleAutoAttach` - Toggle automatic schema attachment on/off

### Health Check

Run `:checkhealth k8s-yaml` to verify the plugin is properly configured.

## Configuration

You can customize the plugin by passing options to the `setup` function:

```lua
require("k8s-yaml").setup({
  -- Cache time-to-live in seconds (default: 86400 - 24 hours)
  cache_ttl = 86400,

  -- Cache directory for schemas (default: stdpath('cache') .. '/k8s-yaml-schemas')
  cache_dir = vim.fn.stdpath('cache') .. '/k8s-yaml-schemas',

  -- Note: Schemas are cached for 24 hours by default since they don't change frequently.
  -- Set to 0 to disable caching, or a smaller value for development.

  -- CRD catalog repository (default: "datreeio/CRDs-catalog")
  schemas_catalog = "datreeio/CRDs-catalog",

  -- CRD catalog branch (default: "main")
  schema_catalog_branch = "main",

  -- Kubernetes schemas repository (default: "yannh/kubernetes-json-schema")
  kubernetes_schemas_repo = "yannh/kubernetes-json-schema",

  -- Kubernetes schemas branch (default: "master")
  kubernetes_schemas_branch = "master",

  -- Path within the repo where schemas are located (default: "master")
  kubernetes_schemas_path = "master",

  -- Performance options
  lazy_load_schemas = true, -- Only load schemas when needed (default: true)
  preload_common_schemas = false, -- Preload frequently used schemas (default: false)

  -- Multi-manifest support
  handle_multi_manifest = true, -- Process YAML files with multiple manifests (default: true)

  -- Auto-attachment
  auto_attach = true, -- Automatically attach schemas when opening YAML files (default: true)
})
```

### Dependencies

This plugin requires:

- `plenary.nvim` for HTTP requests
- `nvim-lspconfig` for LSP integration
- `yaml-language-server` for YAML schema validation

### LazyVim Integration

For LazyVim users, add this to your `lua/plugins/kubernetes.lua`:

```lua
return {
  {
    "Filip7/k8s-yaml.nvim",
    ft = "yaml",
    config = function()
      require("k8s-yaml").setup({
        -- LazyVim compatible settings
        lazy_load_schemas = true,
        preload_common_schemas = true,
      })
    end,
  },
}
```

This ensures the plugin only loads for YAML files and preloads common schemas for better performance.

## Contributing

Contributions are welcome!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

