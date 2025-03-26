local parser = {};
local markdown = require("nvim-markdoc.parsers.markdown")

parser.parse = function (buffer)
	buffer = buffer or vim.api.nvim_get_current_buf();

	if pcall(vim.treesitter.get_parser, buffer) == false or vim.treesitter.get_parser(buffer) == nil then
		return {};
	end

	local root_parser = vim.treesitter.get_parser(buffer);
	local TSTrees = root_parser:parse();
	local TSTree = TSTrees[1];

	_G.__markdoc_state = {
		language_tree = root_parser,
		ts_trees = TSTrees
	};

	if root_parser:lang() ~= "markdown" then
		return {};
	end

	return markdown.handle(buffer, TSTree:root());
end

return parser;
