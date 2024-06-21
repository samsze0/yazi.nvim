local setup = require("yazi.config").setup

local M = {}

---@param opts? YaziSetupOptions
function M.setup(opts) setup(opts) end

return M
