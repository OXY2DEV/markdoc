local markdoc = {};
local parser = require("nvim-markdoc.parser");

markdoc.init = function ()
	local content = parser.parse();
	vim.print(content)
end

markdoc.setup = function ()
end

return markdoc;
