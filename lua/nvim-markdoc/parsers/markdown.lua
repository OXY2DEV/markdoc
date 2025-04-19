local markdown = {};

local inline = require("nvim-markdoc.parsers.markdown_inline");
local yaml = require("nvim-markdoc.parsers.yaml");

local spec = require("nvim-markdoc.spec");
local utils = require("nvim-markdoc.utils");

---@type integer
local wrap_buffer = vim.api.nvim_create_buf(false, true);

--- Wraps the given text.
---@param text string
---@param width integer
---@return string[]
local function wrap(text, width)
	---|fS

	if not wrap_buffer or not vim.api.nvim_buf_is_valid(wrap_buffer) then
		wrap_buffer = vim.api.nvim_create_buf(false, true);
	end

	vim.bo[wrap_buffer].ft = "markdown";
	vim.bo[wrap_buffer].textwidth = width or vim.o.columns;

	vim.api.nvim_buf_set_lines(wrap_buffer, 0, -1, false, { text });
	vim.api.nvim_buf_call(wrap_buffer, function ()
		vim.cmd("%normal gqq");
	end)

	return vim.api.nvim_buf_get_lines(wrap_buffer, 0, -1, false);

	---|fE
end

local function align (text, alignment, width)
	alignment = alignment or "left";
	width = width or vim.o.columns;

	local lines = wrap(text, width);
	vim.api.nvim_buf_set_lines(wrap_buffer, 0, -1, false, lines);

	vim.api.nvim_buf_call(wrap_buffer, function ()
		if alignment == "left" then
			vim.cmd("%left")
		elseif alignment == "right" then
			vim.cmd("%right")
		else
			vim.cmd("%center")
		end
	end);

	return vim.api.nvim_buf_get_lines(wrap_buffer, 0, -1, false);
end

--- Adds empty lines before text
---@param content string[]
---@param node table
---@return string[]
local function add_space(content, node)
	---|fS

	local amount = utils.spaces_above(node);

	for _ = 1, amount do
		table.insert(content, 1, " ");
	end

	return content;

	---|fE
end

--- Gets the amount of columns an element
--- can span.
---@param node table
---@return integer
local function get_usable_width(node)
	---|fS

	local width = spec.config.textwidth or 78;
	local parent = node:parent();

	while parent do
		if parent:type() == "block_quote" then
			width = width - 2;
		elseif parent:type() == "list_item" then
			width = width - (spec.config.tabstop or 4);
		end

		parent = parent:parent();
	end

	return width;

	---|fE
end

markdown.document = function (buffer, node)
	local _content = vim.split(vim.treesitter.get_node_text(node, buffer), "\n", {});
	local range = { node:range() };

	for c = node:child_count() - 1, 0, -1 do
		local child_node = node:child(c);

		local crange = { child_node:range() };
		local ccontent = markdown.handle(buffer, child_node);

		_content = utils.replace(_content, range, ccontent, crange);
	end

	return _content;
end

markdown.minus_metadata = function (buffer, node)
	local range = { node:range() };
	range[1] = range[1] + 1;
	range[3] = range[3] - 1;

	local language_tree = _G.__markdoc_state.language_tree;
	local injected_tree = language_tree:tree_for_range(range, { ignore_injections = false });

	yaml.parse(buffer, injected_tree);
	return {};
end

markdown.section = markdown.document;
markdown.paragraph = markdown.document;

markdown.atx_heading = function (buffer, node)
	local marker = node:child(0);

	if vim.list_contains({ "atx_h1_marker", "atx_h2_marker" }, marker:type()) then
		return {};
		-- return markdown.handle(buffer, node);
	elseif marker:type() == "atx_h3_marker" and node:child_count() == 2 then
		local _content = markdown.inline(buffer, node:child(1));

		for l, line in ipairs(_content) do
			line = string.gsub(line, "[^%w.()%s]", "");
			line = string.gsub(line, "[^-%w.()_%s]+", "");

			_content[l] = string.upper(line);
		end

		_content = add_space(_content, node);
		return _content;
	elseif node:child_count() == 2 then
		local _content = markdown.inline(buffer, node:child(1));

		for l, line in ipairs(_content) do
			_content[l] = line .. " ~";
		end

		_content = add_space(_content, node);
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
	---|fS

	local config = spec.block_quote_config(vim.treesitter.get_node_text(node, buffer));
	local width = get_usable_width(node) - 1 - vim.fn.strdisplaywidth(config.border or "");

	if width <= 1 then
		return {};
	end

	local _content = vim.split(vim.treesitter.get_node_text(node, buffer), "\n", {});
	local range = { node:range() };

	vim.g.__markdoc_block_quote = config;

	for c = node:child_count() - 1, 0, -1 do
		local child_node = node:child(c);

		local crange = { child_node:range() };
		local ccontent = markdown.handle(buffer, child_node);

		_content = utils.replace(_content, range, ccontent, crange);
	end

	vim.g.__markdoc_block_quote = spec.config.block_quotes;

	if _content[#_content] == "" then
		table.remove(_content);
	end

	for l, line in ipairs(_content) do
		if string.match(line, "^%s*>") == nil then
			_content[l] = "> " .. line;
		end
	end

	local output = {};
	local within_code = false;

	for l, line in ipairs(_content) do
		if l == #_content and line == "" then
			break;
		end

		local extra, text = "", "";

		if range[2] ~= 0 then
			if l ~= 1 then
				extra, text = string.sub(line, 0, range[2]), string.sub(line, range[2], #line);
				text = vim.fn.strcharpart(text, 1, vim.fn.strchars(text));
			else
				extra, text = "", line;
			end
		elseif string.match(line, "^%s") then
			extra, text = string.match(line, "^(%s*)(.*)$");
		else
			extra, text = "", line;
		end

		text = string.gsub(text, "^> ?", "");

		if l == 1 then
			if config.title then
				table.insert(output, extra .. (config.border or " ") .. " " .. (config.icon or "") .. " " .. config.title);
				goto continue;
			elseif config.callout then
				table.insert(output, extra .. (config.callout or ""));
				goto continue;
			end
		end

		if within_code == false and string.match(text, "^>") then
			within_code = true;
			table.insert(output, text);
		elseif within_code == true and string.match(text, "^<") then
			--- NOTE, Closing < can't have spaces before it!
			within_code = false;
			table.insert(output, text);
		elseif within_code or string.match(line, "^%-+$") then
			table.insert(output, text);
		else
			local _wrapped = wrap(text, width - vim.fn.strdisplaywidth(config.border or ""));

			for _, wline in ipairs(_wrapped) do
				table.insert(output, extra .. (config.border or " ") .. " " .. wline);
			end
		end

		::continue::
	end

	return output;

	---|fE
end

markdown.block_quote_marker = function (buffer, node)
	return { vim.treesitter.get_node_text(node, buffer) }
end

markdown.block_continuation = markdown.block_quote_marker;

markdown.indented_code_block = function (buffer, node)
	---|fS

	local text = vim.treesitter.get_node_text(node, buffer);
	local _content = vim.split(text, "\n");

	local ft = vim.filetype.match({ contents = _content });
	local tabstop = vim.bo[buffer].tabstop or 4;

	for l, line in ipairs(_content) do
		local _line = string.gsub(line, "^\t+", function (val)
			return string.rep(" ", vim.fn.strchars(val) * tabstop);
		end);

		_content[l] = _line;
	end

	table.insert(_content, 1, string.format(">%s", ft or ""));
	table.insert(_content, "<");

	_content = add_space(_content, node);
	return _content;

	---|fE
end

markdown.fenced_code_block = function (buffer, node)
	---|fS

	local text = vim.treesitter.get_node_text(node, buffer);
	local _content = vim.split(text, "\n");

	local tabstop = vim.bo[buffer].tabstop or 4;

	for l, line in ipairs(_content) do
		if l == 1 then
			_content[l] = string.gsub(line, "`+", ">");
		elseif l == #_content then
			_content[l] = string.gsub(line, "`+", "<");
		else
			_content[l] = string.rep(" ", tabstop) .. line;
		end
	end

	_content = add_space(_content, node);
	return _content;

	---|fE
end

markdown.thematic_break = function (buffer, node)
	---|fS

	local text = vim.treesitter.get_node_text(node, buffer);
	text = text:gsub("%-+", string.rep("-", spec.config.textwidth));

	local _content = vim.split(text, "\n");
	local range = { node:range() };

	for c = node:child_count() - 1, 0, -1 do
		local child_node = node:child(c);

		local crange = { child_node:range() };
		local ccontent = markdown.handle(buffer, child_node);

		_content = utils.replace(_content, range, ccontent, crange);
	end

	return _content;

	---|fE
end

markdown.list = function (buffer, node)
	local text = vim.treesitter.get_node_text(node, buffer);
	local _content = vim.split(text, "\n");

	local range = { node:range() };

	for c = node:child_count() - 1, 0, -1 do
		local child_node = node:child(c);

		local crange = { child_node:range() };
		local ccontent = markdown.handle(buffer, child_node);

		_content = utils.replace(_content, range, ccontent, crange);
	end

	_content = add_space(_content, node);
	return _content;
end

markdown.list_item = function (buffer, node)
	---|fS

	local tabstop = spec.config.tabstop or 4;
	local width = get_usable_width(node) - (2 + tabstop); -- Reserve some extra space(for syntax)

	if width <= 1 then
		return {};
	end

	local _text = vim.treesitter.get_node_text(node, buffer);
	local _content = vim.split(_text, "\n");
	_content = add_space(_content, node);

	local marker;
	local range = { node:range() };

	for c = node:child_count() - 1, 0, -1 do
		local child_node = node:child(c);

		local crange = { child_node:range() };
		local ccontent = markdown.handle(buffer, child_node);

		if string.match(child_node:type(), "^list_marker_") then
			marker = ccontent[1];
		end

		_content = utils.replace(_content, range, ccontent, crange);
	end

	if _content[#_content] == "" then
		table.remove(_content);
	end

	local output = {};

	for l, line in ipairs(_content) do
		if string.match(line, "^[%s>]*$") then
			--- If the line just contains indentations
			--- then don't pad it.
			table.insert(output, line);
			goto continue;
		end

		local extra, text = "", "";

		if range[2] ~= 0 then
			if l ~= 1 then
				extra, text = string.sub(line, 0, range[2]), string.sub(line, range[2], #line);
				text = vim.fn.strcharpart(text, 1, vim.fn.strchars(text));
			else
				extra, text = "", line;
			end
		elseif string.match(line, "^%s") then
			extra, text = string.match(line, "^(%s*)(.*)$");
		else
			extra, text = "", line;
		end

		local _marker = "";

		if l == 1 then
			if string.match(text, "^%s*[%-%+%+]%s?") then
				_marker = string.match(text, "^%s*[%-%+%+]%s?"):gsub("[%-%+%*]", "•");
				text = string.gsub(text, "^%s*[%-%+%+]%s?", "");
			else
				_marker = string.match(text, "^%s*%d+[%.%)]%s?");
				text = string.gsub(text, "^%s*%d+[%.%)]%s?", "");
			end

			_marker = string.gsub(_marker, "^%s+", "");
		end

		---@type string[]
		local wrapped = wrap(text, width - vim.fn.strdisplaywidth(marker));

		for w, wline in ipairs(wrapped) do
			if w ~= 1 then
				table.insert(output, extra .. string.rep(" ", tabstop) .. string.rep(" ", vim.fn.strchars(_marker)) .. wline);
			else
				table.insert(output, extra .. string.rep(" ", tabstop) .. _marker .. wline);
			end
		end

	    ::continue::
	end

	return output;

	---|fE
end

markdown.inline = function (buffer, node)
	local language_tree = _G.__markdoc_state.language_tree;
	local injected_tree = language_tree:tree_for_range({ node:range() }, { ignore_injections = false });

	return inline.handle(buffer, injected_tree:root());
end

--- Gets row count of a table.
---@param tbl table
---@return integer
local function get_rowcount (tbl)
	---|fS

	local R = 0;
	local rows = { "pipe_table_header", "pipe_table_row" };

	for child in tbl:iter_children() do
		local type = child:type();

		if vim.list_contains(rows, type) then
			R = R + 1;
		end
	end

	return R;

	---|fE
end

--- Gets table column size.
---@param row_count integer
---@return integer
local function get_colsize (row_count)
	---|fS

	local C = 1;

	local width = spec.config.textwidth or 78;
	local min_width = spec.config.table.col_minwidth or 1;

	if row_count % 2 ~= 0 then
		C = (row_count - 1) / 2;
	else
		C = row_count / 2;
	end

	width = width - C;

	return math.min(
		math.floor(width / C),
		min_width
	);

	---|fE
end

--- Gets table column alignments.
---@param buffer integer
---@param tbl table
---@return ( "left" | "right" | "center" )[]
local function get_alignments (buffer, tbl)
	---|fS

	if not tbl:child(1) then
		return {};
	end

	local alignments = {};

	for child in tbl:child(1):iter_children() do
		if child:type() == "pipe_table_delimiter_cell" then
			local text = vim.treesitter.get_node_text(child, buffer);

			if string.match(text, "^:%-+:$") then
				table.insert(alignments, "center");
			elseif string.match(text, "%-+:$") then
				table.insert(alignments, "right");
			else
				table.insert(alignments, "left");
			end
		end
	end

	return alignments;

	---|fE
end

--- Creates table borders.
---@param row table
---@param as string
---@return string[]
markdown.__create_border = function (row, as)
	---|fS

	as = as or "header";

	local cols = row:child_count();
	local C = 1;

	if cols % 2 ~= 0 then
		C = (cols - 1) / 2;
	else
		C = cols / 2;
	end

	local col_size = get_colsize(cols);
	local borders = spec.config.table[as] or { "", "", "", "" };

	local output = borders[1] or " ";

	for c = 1, C, 1 do
		output = output .. string.rep(borders[2] or " ", col_size);

		if c == C then
			output = output .. (borders[3] or " ")
		else
			output = output .. (borders[4] or " ")
		end
	end

	return output;

	---|fE
end

--- Creates a row of a table.
---@param buffer integer
---@param row table
---@param as string
---@param alignments ( "left" | "right" | "center" )[]
---@return string[]
markdown.__create_row = function (buffer, row, as, alignments)
	---|fS

	as = as or "header";
	alignments = alignments or {};

	local col_size = get_colsize(row:child_count());
	local row_span = 1;

	local cols = {};
	local C = 1;

	for col in row:iter_children() do
		if col:type() == "pipe_table_cell" then
			local cell_content = markdown.inline(buffer, col);
			local wrapped = align(cell_content[1], alignments[C], col_size - 2);

			row_span = math.max(row_span, #wrapped);
			table.insert(cols, wrapped);

			C = C + 1;
		end
	end

	local borders = spec.config.table[as] or { "", "", "" };
	local output = {};

	for l = 1, row_span, 1 do
		local line = borders[1] or "";

		for c, col in ipairs(cols) do
			if col[l] then
				line = line .. " ";
				line = line .. string.format("%-" .. (col_size - 1) .. "s", col[l]);
			else
				line = line .. string.rep(" ", col_size);
			end

			if c == #cols then
				line = line .. (borders[3] or "");
			else
				line = line .. (borders[2] or "");
			end
		end

		table.insert(output, line);
	end

	return output;

	---|fE
end

markdown.pipe_table = function (buffer, node)
	---|fS

	local text = vim.treesitter.get_node_text(node, buffer);
	local lines = vim.split(text, "\n", { trimempty = true });
	local before = string.match(lines[2] or "", "^([^|]*)|");

	local alignments = get_alignments(buffer, node);
	local output = {};

	table.insert(output, markdown.__create_border(
		node:child(0), "top"
	));

	local rows = get_rowcount(node);
	local R = 1;

	for row in node:iter_children() do
		local node_type = row:type();

		if node_type == "pipe_table_header" then
			output = vim.list_extend(output, markdown.__create_row(buffer, row, "header", alignments));

			table.insert(output, markdown.__create_border(
				node:child(0), "separator"
			));

			R = R + 1;
		elseif node_type == "pipe_table_row" then
			output = vim.list_extend(output, markdown.__create_row(buffer, row, "row", alignments));

			if R ~= rows then
				table.insert(output, markdown.__create_border(
					node:child(0), "row_separator"
				));
			end

			R = R + 1;
		end
	end

	table.insert(output, markdown.__create_border(
		node:child(0), "bottom"
	));

	local range = { node:range() };

	for l, line in ipairs(output) do
		if range[2] ~= 0 and l ~= 1 then
			output[l] = before .. line;
		elseif range[2] == 0 then
			output[l] = before .. line;
		end
	end

	return output;

	---|fE
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
