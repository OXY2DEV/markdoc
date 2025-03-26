local markdown = {};
local inline = require("nvim-markdoc.parsers.markdown_inline");

local utils = require("nvim-markdoc.utils");

markdown.document = function (buffer, node)
	local content = {};
	local range = { node:range() };

	for child_node in node:iter_children() do
		local _content = markdown.handle(buffer, child_node);
		-- local _range = { child_node:range() };

		-- print(child_node:type())
		content = vim.list_extend(content, _content);
	end

	return content;
end

markdown.section = markdown.document;
markdown.paragraph = markdown.document;

markdown.atx_heading = function (buffer, node)
	local marker = node:child(0);

	if vim.list_contains({ "atx_h1_marker", "atx_h2_marker" }, marker:type()) then
		return markdown.document(buffer, node);
	elseif marker:type() == "atx_h3_marker" and node:child_count() == 2 then
		local _content = markdown.inline(buffer, node:child(1));

		for l, line in ipairs(_content) do
			line = string.gsub(line, "[^%w.()%s]", "");
			line = string.gsub(line, "[^-%w.()_%s]+", "");

			_content[l] = string.upper(line);
		end

		return _content;
	elseif node:child_count() == 2 then
		local _content = markdown.inline(buffer, node:child(1));

		for l, line in ipairs(_content) do
			_content[l] = line .. " ~";
		end

		return _content;
	else
		return {};
	end
end;

markdown.atx_h1_marker = function ()
	return { string.rep("=", 78) };
end

markdown.atx_h2_marker = function ()
	return { string.rep("-", 78) };
end

markdown.block_quote = function (buffer, node)
	local _main = vim.split(vim.treesitter.get_node_text(node, buffer), "\n", {});
	local range = { node:range() };

	for child_node in node:iter_children() do
		local crange = { child_node:range() };
		local ccontent = markdown.handle(buffer, child_node);

		_main = utils.replace(_main, range, ccontent, crange);
	end

	return _main;
end

markdown.inline = function (buffer, node)
	local language_tree = _G.__markdoc_state.language_tree;
	local injected_tree = language_tree:tree_for_range({ node:range() }, { ignore_injections = false });

	return inline.handle(buffer, injected_tree:root());
end

markdown.handle = function (buffer, node)
	local n_type = node:type();

	if markdown[n_type] then
		return markdown[n_type](buffer, node);
	else
		return vim.split(vim.treesitter.get_node_text(node, buffer), "\n", {});
	end
end

return markdown;
