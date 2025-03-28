local markdown = {};

local inline = require("nvim-markdoc.parsers.markdown_inline");
local yaml = require("nvim-markdoc.parsers.yaml");

local spec = require("nvim-markdoc.spec");
local utils = require("nvim-markdoc.utils");

local function wrap(text, width)
	---|fS

	width = width or 78;
	local _output = "";

	local tokens = {};

	local code_at;

	local function merge_tokens ()
		local merged = "";

		for t, _ in ipairs(tokens) do
			if t > code_at then
				merged = merged .. tokens[t];
				tokens[t] = nil;
			end
		end

		table.insert(tokens, merged .. "`");
	end

	for c = 0, vim.fn.strchars(text) - 1 do
		local char = vim.fn.strcharpart(text, c, 1);
		local is_whitespace = string.match(char, "%s") ~= nil;

		if is_whitespace then
			if char == "\n" then
				table.insert(tokens, "");
			elseif #tokens > 0 and (tokens[#tokens] == "" or string.match(tokens[#tokens], "^%s+$") ~= nil) then
				tokens[#tokens] = tokens[#tokens] .. char;
			else
				table.insert(tokens, char);
			end
		elseif char == "`" then
			if not code_at then
				code_at = #tokens;

				if #tokens > 0 and string.match(tokens[#tokens], "^%S+$") then
					tokens[#tokens] = tokens[#tokens] .. char;
				else
					table.insert(tokens, char);
				end
			else
				merge_tokens();
				code_at = nil;
			end
		else
			if #tokens > 0 and string.match(tokens[#tokens], "^%S+$") then
				tokens[#tokens] = tokens[#tokens] .. char;
			else
				table.insert(tokens, char);
			end
		end
	end

	for _, token in ipairs(tokens) do
		local line_length = vim.fn.strchars(string.match(_output, "\n?([^\n]-)$"));
		local len = vim.fn.strchars(token) or 0;

		if string.match(token, "^%s+") then
			---|fS

			--- Only add whitespace if we aren't in a new line
			--- and the output isn't empty.
			--- Also check if we have enough space
			if (line_length + len) <= width and _output ~= "" and string.match(_output, "[^%s]$") then
				_output = _output .. token;
				line_length = line_length + len;
			end

			---|fE
		elseif string.match(token, "^`[^`]+`") then
			---|fS

			--- Discard inline codes that are very big.
			if len <= width then
				if line_length + len <= width then
					_output = _output .. token;
					line_length = line_length + len;
				else
					_output = _output .. "\n" .. token;
					line_length = len;
				end
			end

			---|fE
		else
			---|fS

			if len > width then
				local chars = 0;

				for c = 0, vim.fn.strchars(token) - 1 do
					local char = vim.fn.strcharpart(token, c, 1)

					if chars == width then
						_output = _output .. "\n";
						chars = 0;
					end

					_output = _output .. char;
					chars = chars + 1;
				end

				line_length = char;
			elseif (line_length + len) > width then
				_output = _output .. "\n" .. token;
				line_length = len;
			elseif _output == "" then
				line_length = line_length + len;
				_output = _output .. token;
			else
				line_length = line_length + 1 + len;
				_output = _output .. token;
			end

			---|fE
		end
	end

	--- Remove spaces that come before
	--- the end of lines.
	--- Fixes text alignment issues.
	_output = _output:gsub(" *\n", "\n")

	return _output;

	---|fE
end

local function add_space(content, node)
	local amount = utils.spaces_above(node);

	for i = 1, amount do
		table.insert(content, 1, "");
	end

	return content;
end

local function get_usable_width(node)
	local width = spec.config.textwidth or 78;
	local parent = node:parent();

	while parent do
		if parent:type() == "block_quote" then
			width = width - 2;
		end

		parent = parent:parent();
	end

	return width;
end

markdown.document = function (buffer, node)
	local content = {};

	for child_node in node:iter_children() do
		local _content = markdown.handle(buffer, child_node);
		content = vim.list_extend(content, _content);
	end

	return content;
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
		_content = add_space(_content, node);

		for l, line in ipairs(_content) do
			line = string.gsub(line, "[^%w.()%s]", "");
			line = string.gsub(line, "[^-%w.()_%s]+", "");

			_content[l] = string.upper(line);
		end

		return _content;
	elseif node:child_count() == 2 then
		local _content = markdown.inline(buffer, node:child(1));
		_content = add_space(_content, node);

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
	---|fS

	local config = spec.block_quote_config(vim.treesitter.get_node_text(node, buffer));
	local width = get_usable_width(node) - 1 - vim.fn.strdisplaywidth(config.border or "");

	if width <= 1 then
		return {};
	end

	local _content = vim.split(vim.treesitter.get_node_text(node, buffer), "\n", {});
	local range = { node:range() };

	for child_node in node:iter_children() do
		if child_node:type() == "block_continuation" then
			--- BUG, Block continuations are kinda
			--- bugged at the moment.
			goto continue;
		end

		local crange = { child_node:range() };
		local ccontent = markdown.handle(buffer, child_node);

		_content = utils.replace(_content, range, ccontent, crange);
	    ::continue::
	end

	local output = {};
	local within_code = false;

	for l, line in ipairs(_content) do
		local _line = line or "";
		_line = string.gsub(_line, "^> ?", "");

		if l == 1 then
			if config.title then
				_line = (config.border or " ") .. " " .. (config.icon or "") .. " " .. config.title;
			elseif config.callout then
				_line = config.callout or "";
			end
		end

		if within_code == false and string.match(_line, "^>") then
			within_code = true;
			table.insert(output, "  " .. _line);
		elseif within_code == true and string.match(_line, "^<") then
			--- NOTE, Closing < can't have spaces before it!
			within_code = false;
			table.insert(output, _line);
		elseif within_code or string.match(_line, "^%-+$") then
			table.insert(output, _line);
		else
			local _wrapped = wrap(_line, width - vim.fn.strdisplaywidth(config.border or ""));

			for _, wline in ipairs(vim.split(_wrapped, "\n")) do
				if l == 1 then
					table.insert(output, wline);
				else
					table.insert(output, (config.border or " ") .. " " .. wline);
				end
			end
		end
	end

	return output;

	---|fE
end

markdown.block_quote_marker = function (buffer, node)
	return { vim.treesitter.get_node_text(node, buffer, { ignore_injections = false }) }
end

markdown.indented_code_block = function (buffer, node)
	local text = vim.treesitter.get_node_text(node, buffer);
	local _content = vim.split(text, "\n");
	_content = add_space(_content, node);

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

	return _content;
end

markdown.thematic_break = function (buffer, node)
	---|fS

	local text = vim.treesitter.get_node_text(node, buffer);
	text = text:gsub("%-+", string.rep("-", spec.config.textwidth));

	local _content = vim.split(text, "\n");
	local range = { node:range() };

	for child_node in node:iter_children() do
		vim.print(child_node:type())
		local crange = { child_node:range() };
		local ccontent = markdown.handle(buffer, child_node);

		_content = utils.replace(_content, range, ccontent, crange);
	end

	return _content;

	---|fE
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
