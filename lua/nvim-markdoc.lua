local markdoc = {};
local parser = require("nvim-markdoc.parser");

markdoc.init = function ()
	local content = parser.parse();

	for _, line in ipairs(content) do
		local w = vim.fn.strchars(line);
		vim.print(line .. string.rep(" ", 78 - w) .. "│");
	end
end

markdoc.setup = function ()
end

return markdoc;
