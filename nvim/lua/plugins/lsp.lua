-- https://www.lazyvim.org/plugins/lsp
-- NOTE: don't forget to update treesitter for languages
-- NOTE: see lazy.lua for extras that configure LSPs, formatters, linters and code actions.

local function prefer_bin_from_venv(executable_name)
  -- Return the path to the executable if $VIRTUAL_ENV is set and the binary exists somewhere beneath the $VIRTUAL_ENV path, otherwise get it from Mason
  if vim.env.VIRTUAL_ENV then
    local paths = vim.fn.glob(vim.env.VIRTUAL_ENV .. "/**/bin/" .. executable_name, true, true)
    local executable_path = table.concat(paths, ", ")
    if executable_path ~= "" then
      -- vim.api.nvim_echo(
      -- 	{ { "Using path for " .. executable_name .. ": " .. executable_path, "None" } },
      -- 	false,
      -- 	{}
      -- )
      return executable_path
    end
  end

  local mason_registry = require("mason-registry")
  local mason_path = mason_registry.get_package(executable_name):get_install_path() .. "/venv/bin/" .. executable_name
  -- vim.api.nvim_echo({ { "Using path for " .. executable_name .. ": " .. mason_path, "None" } }, false, {})
  return mason_path
end

return {

  {
    "williamboman/mason.nvim",

    opts = function(_, opts)
      local ensure_installed = {
        -- python
        "ruff-lsp", -- lsp
        "ruff",     -- linter (but used as formatter)
        "pyright",  -- lsp
        "black",    -- formatter
        "mypy",     -- linter

        -- lua
        "lua-language-server", -- lsp
        "stylua",              -- formatter

        -- shell
        "bash-language-server", -- lsp
        "shfmt",                -- formatter
        -- "shellcheck",           -- linter

        -- yaml
        "yamllint", -- linter

        -- sql
        "sqlfluff", -- linter

        -- containers
        -- "hadolint", -- linter
        "dockerfile-language-server",
        "docker-compose-language-service",
      }

      -- extend opts.ensure_installed
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, ensure_installed)

      -- remove from opts.ensure_installed
      -- NOTE: this removes tooling because Mason provides a version
      -- built for intel machines on macOS. Instead, these are provided
      -- with the proper architecture via brew.
      local ensure_not_installed = { "shellcheck", "hadolint" }
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return not vim.tbl_contains(ensure_not_installed, tool)
      end, opts.ensure_installed)
    end,
  },

  {
    "nvimtools/none-ls.nvim",
    enabled = false,
    dependencies = { "mason.nvim" },
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      local null_ls = require("null-ls")
      local formatting = null_ls.builtins.formatting
      local diagnostics = null_ls.builtins.diagnostics
      local code_actions = null_ls.builtins.code_actions

      local sources = {
        -- list of supported sources:
        -- https://github.com/nvimtools/none-ls.nvim/blob/main/doc/BUILTINS.md

        -- python
        formatting.black.with({
          filetypes = { "python" },
          command = prefer_bin_from_venv("black"),
        }),
        diagnostics.ruff.with({
          filetypes = { "python" },
          command = prefer_bin_from_venv("ruff"),
        }),

        -- lua
        formatting.stylua.with({
          extra_args = { "--indent-type", "Spaces", "--indent-width", "2" },
        }),

        -- shell
        formatting.shfmt,
        diagnostics.shellcheck,
        code_actions.shellcheck,

        -- yaml
        diagnostics.yamllint,

        -- sql
        diagnostics.sqlfluff.with({
          extra_args = { "--dialect", "postgres" },
        }),
      }

      -- extend opts.sources
      for _, source in ipairs(sources) do
        table.insert(opts.sources, source)
      end

      -- always remove from opts.sources (e.g. added by lazy.lua extras)
      local remove_sources = { "goimports_reviser" }
      opts.sources = vim.tbl_filter(function(source)
        return not vim.tbl_contains(remove_sources, source.name)
      end, opts.sources)
    end,
  },

  {
    "stevearc/conform.nvim",
    -- https://github.com/stevearc/conform.nvim
    enabled = true,
    opts = function(_, opts)
      local formatters = require("conform.formatters")
      formatters.ruff_fix.command = prefer_bin_from_venv("ruff")
      formatters.ruff_format.command = prefer_bin_from_venv("ruff")
      formatters.isort.command = prefer_bin_from_venv("isort")
      formatters.black.command = prefer_bin_from_venv("black")
      formatters.stylua.args =
          vim.list_extend({ "--indent-type", "Spaces", "--indent-width", "2" }, formatters.stylua.args)

      local remove_from_formatters = {}
      local extend_formatters_with = {
        python = { "ruff_fix", "ruff_format" },
      }

      -- NOTE: conform.nvim can use a sub-list to run only the first available formatter (see docs)

      -- remove from opts.formatters_by_ft
      for ft, formatters_ in pairs(remove_from_formatters) do
        opts.formatters_by_ft[ft] = vim.tbl_filter(function(formatter)
          return not vim.tbl_contains(formatters_, formatter)
        end, opts.formatters_by_ft[ft])
      end
      -- extend opts.formatters_by_ft
      for ft, formatters_ in pairs(extend_formatters_with) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        vim.list_extend(opts.formatters_by_ft[ft], formatters_)
      end
      -- review opts.formatters_by_ft by uncommenting the below
      -- vim.api.nvim_echo(
      --   { { "opts.formatters_by_ft", "None" }, { vim.inspect(opts.formatters_by_ft), "None" } },
      --   false,
      --   {}
      -- )
    end,
  },

  {
    "mfussenegger/nvim-lint",
    -- https://github.com/mfussenegger/nvim-lint
    enabled = true,
    opts = function(_, opts)
      local linters = require("lint").linters
      -- linters.mypy.cmd = prefer_bin_from_venv("mypy")
      linters.sqlfluff.args = vim.list_extend({ "--dialect", "postgres" }, linters.sqlfluff.args)

      local linters_by_ft = {
        -- this extends lazyvim's nvim-lint setup
        -- https://www.lazyvim.org/extras/linting/nvim-lint
        protobuf = { "buf", "protolint" },
        -- python = { "mypy" },
        sh = { "shellcheck" },
        sql = { "sqlfluff" },
        yaml = { "yamllint" },
      }

      -- extend opts.linters_by_ft
      for ft, linters_ in pairs(linters_by_ft) do
        opts.linters_by_ft[ft] = opts.linters_by_ft[ft] or {}
        vim.list_extend(opts.linters_by_ft[ft], linters_)
      end
    end,
  },
}
