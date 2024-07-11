local Config = require("yazi.config")

local M = {}

---@param config? YaziConfig.config
M.setup = function(config)
  Config:setup(config)
end

return M
