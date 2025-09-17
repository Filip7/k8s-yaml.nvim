# k8s-yaml.nvim Agent Guidelines

## Build/Lint/Test Commands
- No specific build commands needed (Lua plugin)
- Linting: Use `luacheck` for Lua code
- Testing: No dedicated test framework; manually test in Neovim

## Code Style Guidelines
- **Imports**: Use `local` for module imports at file top
- **Formatting**: 4-space indentation, consistent spacing
- **Types**: Use Lua's dynamic typing; add type comments for complex structures
- **Naming**: snake_case for variables/functions, PascalCase for modules
- **Error Handling**: Use `vim.notify()` for user-facing errors
- **Error Codes**: Use `vim.log.levels` constants (ERROR, WARN, INFO)
- **Documentation**: Add comments for non-obvious logic

## Plugin Structure
- Main module in `lua/k8s-yaml/init.lua`
- Configuration via `setup()` function
- Schema caching in Neovim's cache directory
- GitHub API integration for CRD schemas