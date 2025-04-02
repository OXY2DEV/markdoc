local markdoc = {};
local parser = require("nvim-markdoc.parser");

markdoc.init = function ()
	local content = parser.parse();

	for _, line in ipairs(content) do
		vim.print(string.format("%-78s│", line));
	end
end

markdoc.setup = function ()
end

return markdoc;
