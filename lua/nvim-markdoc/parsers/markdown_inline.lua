local inline = {};
local utils = require("nvim-markdoc.utils");

inline.inline = function (buffer, node)
	local _main = vim.split(vim.treesitter.get_node_text(node, buffer), "\n", {});
	local range = { node:range() };

	for c = node:child_count() - 1, 0, -1 do
		local child_node = node:child(c);

		local crange = { child_node:range() };
		local ccontent = inline.handle(buffer, child_node);

		_main = utils.replace(_main, range, ccontent, crange);
	end

	return _main;
end

inline.emphasis = function (buffer, node)
	local text = vim.treesitter.get_node_text(node, buffer);
	text = string.gsub(text, "^%*+", "");
	text = string.gsub(text, "%*+$", "");

	return { text };
end

inline.strong_emphasis = inline.emphasis;

inline.handle = function (buffer, node)
	local n_type = node:type();

	if inline[n_type] then
		return inline[n_type](buffer, node);
	else
		return vim.split(vim.treesitter.get_node_text(node, buffer), "\n", {});
	end
end

return inline;
