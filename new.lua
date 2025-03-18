--- Generic markdown to Vimdoc transformer.
local markdoc = {};
local inspect = require("inspect")

--- Bade configuration table
--- for markdoc.
---@class markdoc.config
---
--- Heading text pattern & the corresponding
--- tag.
---@field tags table<string, string | string[]>
markdoc.config = {
	width = 78,
	tags = {
		[".nvim"] = "Hi"
	},
	block_quotes = {
		default = {
			border = "▌"
		},
		note = {
			callout = "▌ Note"
		}
	},
	table = {
		width = 10,

		top = { "╭", "─", "╮", "┬" },
		header = { "│", "│", "│" },

		separator = { "├", "─", "┤", "┼" },
		header_separator = { "├", "─", "┤", "┼" },
		row_separator = { "├", "─", "┤", "┼" },

		row = { "│", "│", "│" },
		bottom = { "╰", "─", "╯", "┴" }
	}
};

markdoc.state = {
	depth = 0,
};



--- Turns other data types to string.
---@param data any
---@return string
local function str(data)
	---|fS

	local pandoc = require("pandoc");

	if type(data) ~= "table" then
		return tostring(data);
	else
		return pandoc.utils.stringify(data);
	end

	---|fE
end

--- Escapes magic characters from a string
---@param input string
---@return string
local function escape (input)
	input = input:gsub("%%", "%%%%");

	input = input:gsub("%(", "%%(");
	input = input:gsub("%)", "%%)");

	input = input:gsub("%.", "%%.");
	input = input:gsub("%+", "%%+");
	input = input:gsub("%-", "%%-");
	input = input:gsub("%*", "%%*");
	input = input:gsub("%?", "%%?");
	input = input:gsub("%^", "%%^");
	input = input:gsub("%$", "%%$");

	input = input:gsub("%[", "%%[");
	input = input:gsub("%]", "%%]");

	return input;
end
local function wrap(text, width)
	---|fS

	width = width or markdoc.config.width;
	local _output = "";
	local line_length = 0;

	--- Wrapping should be only for single lines.
	--- If there's a newline then that's a
	--- mistake.
	local _text = string.gsub(text, "\n", "");

	while string.match(_text, "^%s+") or string.match(_text, "^`[^`]`") or string.match(_text, "^%S+") do
		if string.match(_text, "^%s+") then
			---|fS

			local token = string.match(_text, "^%s+");
			local len = utf8.len(token) or 0;

			--- Only add whitespace if we aren't in a new line
			--- and the output isn't empty.
			--- Also check if we have enough space
			if (line_length + len) < width and _output ~= "" and string.match(_output, "[^%s]$") then
				_output = _output .. token;
				line_length = line_length + len;
			end

			_text = string.gsub(_text, "^" .. escape(token), "", 1);

			---|fE
		elseif string.match(_text, "^`[^`]+`") then
			---|fS

			local token = string.match(_text, "^`[^`]+`");
			local len = utf8.len(token) or 0;

			--- Discard inline codes that are very big.
			if line_length <= width then
				if line_length + len <= width then
					_output = _output .. token;
					line_length = line_length + len;
				else
					_output = _output .. "\n" .. token;
					line_length = len;
				end
			end

			_text = string.gsub(_text, "^" .. escape(token), "", 1);

			---|fE
		else
			---|fS

			local token = string.match(_text, "^%S+");
			local len = utf8.len(token) or 0;

			if len >= width then
				local times = (len // width) + 1;

				for i = 1, times do
					local start = utf8.offset(token, (i - 1) * width);
					local till = utf8.offset(token, i * width);

					_output = _output .. "\n" .. string.sub(token, start, till);
				end
			elseif (line_length + len) >= width then
				line_length = len;
				_output = _output .. "\n" .. token;
			elseif _output == "" then
				line_length = line_length + len;
				_output = _output .. token;
			else
				line_length = line_length + 1 + len;
				_output = _output .. token;
			end

			_text = string.gsub(_text, "^" .. escape(token), "", 1);

			---|fE
		end
	end

	return _output;

	---|fE
end

local function split(text, pat)
	---|fS

	if string.match(text, pat .. "$") == nil then text = text .. pat; end

	local _split = {};

	for match in string.gmatch(text, "(.-)" .. pat) do
		table.insert(_split, match);
	end

	return _split;

	---|fE
end

local function align(alignment, text, width)
	---|fS

	text = text or "";
	alignment = alignment or "l";
	width = math.floor(width or markdoc.config.width);

	local LEN = utf8.len(text)

	if alignment == "l" then
		return text .. string.rep(" ", width - LEN)
	elseif alignment == "r" then
		return string.rep(" ", width - LEN) .. text
	else
	end

	---|fE
end

local function filter(text, pattern)
	---|fS


	local _output = "";

	for _, point in utf8.codes(text) do
		local char = utf8.char(point);

		if string.match(char, pattern) then
			_output = _output .. char;
		end
	end

	return _output;


	---|fE
end

local function extend(src, apply)
	---|fS

	local _tmp = src;

	for k, v in pairs(apply) do
		if src[k] and type(v) ~= type(src[k]) then
			_tmp[k] = src[k];
			goto continue;
		end

		if type(v) == "table" then
			_tmp[k] = extend(src[k] or {}, v)
		else
			_tmp[k] = v;
		end

	    ::continue::
	end

	return _tmp;

	---|fE
end




--- Block quotes & callouts.
---@param node table
---@param width integer
---@return string
markdoc.BlockQuote = function (node, _, width)
	---|fS

	local _output = "";
	local config = markdoc.config.block_quotes.default;

	--- Updates block quote config.
	---@param line string
	local function update_config(line)
		---|fS

		if string.match(line, "^%s*%[!") == nil then
			return;
		end

		local callout, title = line:match("^%s*%[%!([^%]]+)%]%s*(.-)$");
		local keys = {};

		for k, _ in pairs(markdoc.config.block_quotes) do
			if k ~= "default" then
				table.insert(keys, k);
			end
		end

		table.sort(keys);

		for _, key in ipairs(keys) do
			if string.match(string.lower(callout), string.lower(key)) then
				config = extend(config, markdoc.config.block_quotes[key]);

				if title ~= "" then
					config.title = title;
				end

				return;
			end
		end

		---|fE
	end

	local next_draw = false;

	--- Can we draw the border?
	---@param drawable boolean
	---@param line string
	---@return boolean
	local border_drawable = function (drawable, line)
		---|fS

		if next_draw == true then
			next_draw = false;
			return true;
		elseif drawable == true and string.match(line, "%>.-$") then
			return false;
		elseif drawable == false and string.match(line, "^%<") then
			next_draw = true;
			return false;
		end

		return drawable;

		---|fE
	end

	--- Should we wrap this paragraph?
	---@param entry table
	---@return boolean
	local function should_wrap(entry)
		---|fS

		if entry.t == "CodeBlock" then
			return false;
		elseif entry.t == "Table" then
			return false;
		end

		return true;

		---|fE
	end

	for e, entry in ipairs(node.content) do
		local content;

		if should_wrap(entry) == false then
			content = markdoc.traverse({ entry }, "", 9999):gsub("^\n", "");
		else
			content = markdoc.traverse({ entry }, "", width - 2):gsub("^\n", "");
		end

		local paragraph = split(content, "\n");

		--- Should we draw the border?
		---@type boolean
		local border = true;

		for l, line in ipairs(paragraph) do
			if e == 1 and l == 1 then
				update_config(line);

				if config.title then
					_output = _output .. "\n" .. (config.border or "") .. " " .. (config.icon or "") .. (config.title or "");
				elseif config.callout then
					_output = _output .. "\n" .. (config.callout or "");
				else
					_output = _output .. "\n" .. (config.border or "") .. " " .. line;
				end
			else
				border = border_drawable(border, line);

				if border == false then
					_output = _output .. "\n" .. "  " .. line;
				else
					_output = _output .. "\n" .. (config.border or "") .. " " .. line;
				end
			end
		end
	end

	return _output .. "\n\n";

	---|fE
end

--- Bullet list(+, -, *);
---@param node table
---@param width integer
---@return string
markdoc.BulletList = function (node, _, width)
	---|fS

	--- Handles unordered list candidates.
	---@param candidate table
	---@return string
	local function handle_candidate (candidate)
		---|fS

		local _output = "";

		local W = width or markdoc.config.width;
		local indent = markdoc.state.depth * 2;

		local content = markdoc.traverse(candidate):gsub("^\n", "");
		local should_wrap = true;
		local within_table = false;

		local function update_state (line)
			local blck = markdoc.config.block_quotes.default.border;

			local top = markdoc.config.table.top;
			local bot = markdoc.config.table.bottom;

			if should_wrap == true and string.match(line, "%>.*") then
				should_wrap = false;
			elseif should_wrap == true and string.match(line, "^%<") then
				should_wrap = true;
			elseif should_wrap == true and string.match(line, blck) then
				should_wrap = false;
			elseif within_table == false and string.match(line, top[1] .. top[2]) then
				should_wrap = false;
				within_table = true;
			elseif within_table == true and string.match(line, bot[1] .. bot[2]) then
				should_wrap = false;
				within_table = false;
			elseif within_table == false then
				should_wrap = true;
			end
		end

		for p, paragraph in ipairs(split(content, "\n")) do
			local wrapped = wrap(paragraph, W - (indent + 2));

			for l, line in ipairs(split(wrapped, "\n")) do
				update_state(line);
				_output = _output .. string.rep(" ", indent);

				if should_wrap then
					if l == 1 and p == 1 then
						_output = _output .. "• " .. line;
					else
						_output = _output .. "  " .. line;
					end

					_output = _output .. "\n";
				else
					_output = _output .. "  " .. line .. "\n";
				end
			end
		end

		return _output;

		---|fE
	end

	local _output = "";

	for _, candidate in ipairs(node.content) do
		_output = _output .. handle_candidate(candidate)
	end

	return (markdoc.state.depth > 1 and "\n\n" or "\n") .. _output .. (markdoc.state.depth > 1 and "\n" or "");

	---|fE
end

--- Inline code
---@param node table
---@param width integer
---@return string
markdoc.Code = function (node, _, width)
	---|fS

	local len = utf8.len(node.text)

	if len >= width * 0.4 then
		return node.text;
	else
		return string.format("`%s`", node.text)
	end

	---|fE
end

--- Code block.
---@param node table
---@return string
markdoc.CodeBlock = function (node)
	---|fS

	---@type string
	local language = node.classes[1] or "";
	local lines = split(node.text, "\n");

	print(node.text)

	local _output = string.format("\n>%s\n", language);

	for _, line in ipairs(lines) do
		_output = _output .. "  " .. line .. "\n";
	end

	return _output .. "<\n";

	---|fE
end

--- Emphasized text.
---@param node table
---@return string
markdoc.Emph = function (node)
	return markdoc.traverse(node.content, " ");
end

--- Markdown heading
---@param node table
---@param width integer
---@return string
markdoc.Header = function (node, _, width)
	---|fS

	local function get_tags(text)
		---|fS

		local keys = {};

		for k, _ in pairs(markdoc.config.tags) do
			table.insert(keys, k);
		end

		table.sort(keys);

		for _, key in ipairs(keys) do
			if string.match(text, key) then
				return type(markdoc.config.tags[key]) == "string" and { markdoc.config.tags[key] } or markdoc.config.tags[key]
			end
		end

		return {};

		---|fE
	end

	local function tag_lines(tags, _width)
		---|fS

		local _output = {};
		local line_length = 0;

		for _, tag in ipairs(tags) do
			local _tag = string.format(" *%s*", tag);
			local tag_length = utf8.len(_tag)  --[[ @as integer ]];

			if tag_length > width then
				goto continue;
			end

			if #_output == 0 or tag_length == _width then
				table.insert(_output, _tag);
				line_length = tag_length;
			elseif (line_length + tag_length) > _width then
				table.insert(_output, _tag);
				line_length = tag_length;
			else
				_output[#_output] = _output[#_output] .. _tag;
				line_length = line_length + tag_length;
			end

		    ::continue::
		end

		return _output;

		---|fE
	end

	local txt = markdoc.traverse(node.content, " ");
	local tags = get_tags(txt);

	if node.level == 1 or node.level == 2 then
		---|fS

		local _o = "\n" .. string.rep(node.level == 1 and "=" or "-", width) .. "\n";

		if #tags > 0 then
			local L = math.ceil((width - 2) / 2);
			local R = math.floor((width - 2) / 2);

			local tmp = wrap(txt, L);
			local txt_l = split(tmp, "\n");
			local tag_l = tag_lines(tags, R);

			local lines = {};

			for i = 1, math.max(#txt_l, #tag_l) do
				if txt_l[i] and tag_l[i] then
					table.insert(lines, align("l", txt_l[i], L) .. "  " .. align("r", tag_l[i], R));
				elseif tag_l[i] then
					table.insert(lines, align("r", tag_l[i], width));
				elseif txt_l[i] then
					table.insert(lines, txt_l[i]);
				end
			end

			_o = _o .. table.concat(lines, "\n");
		else
			_o = _o .. wrap(txt);
		end

		return _o;

		---|fE
	elseif node.level == 3 then
		---|fS

		local tmp = wrap(txt, width - 3);
		local _o = "\n" .. tmp .. " ~\n";

		if #tags > 0 then
			local R = math.floor((width - 2) / 2);
			local tag_l = tag_lines(tags, R);

			local lines = {};

			for i = 1, #tag_l do
				table.insert(lines, align("r", tag_l[i], width));
			end

			_o = _o .. table.concat(lines, "\n");
		end

		return _o;

		---|fE
	else
		---|fS

		local filtered = string.upper(filter(txt, "[a-zA-Z%d%s%._%-]"));
		local tmp = wrap(filtered, width - 3);
		local _o = "\n" .. tmp .. "\n";

		if #tags > 0 then
			local R = math.floor((width - 2) / 2);
			local tag_l = tag_lines(tags, R);

			local lines = {};

			for i = 1, #tag_l do
				table.insert(lines, align("r", tag_l[i], width));
			end

			_o = _o .. table.concat(lines, "\n");
		end

		return _o;

		---|fE
	end

	---|fE
end

--- Horizontal rule.
---@param width integer
---@return string
markdoc.HorizontalRule = function (_, _, width)
	return "\n" .. string.rep("-", width) .. "\n";
end

--- Numbered list(1., 1));
---@param node table
---@param width integer
---@return string
markdoc.OrderedList = function (node, _, width)
	---|fS

	local function get_marker(lnum)
		---|fS

		if node.style == "Decimal" then
			return tostring(lnum), tostring(lnum):len();
		elseif node.style == "LowerAlpha" then
			local _alpha = {
				"a", "b", "c", "d", "e",
				"f", "g", "h", "i", "j",
				"k", "l", "m", "n", "o",
				"p", "q", "r", "s", "t",
				"u", "v", "w", "x", "y",
				"z"
			};

			local _o = "";

			while lnum > #_alpha do
				_o = _o .. _alpha[#_alpha];
				lnum = lnum - #_alpha;
			end

			_o = _o .. _alpha[lnum];
			return _o, #_o;
		elseif node.style == "UpperAlpha" then
			local _alpha = {
				"A", "B", "C", "D", "E",
				"F", "G", "H", "I", "J",
				"K", "L", "M", "N", "O",
				"P", "Q", "R", "S", "T",
				"U", "V", "W", "X", "Y",
				"Z"
			};

			local _o = "";

			while lnum > #_alpha do
				_o = _o .. _alpha[#_alpha];
				lnum = lnum - #_alpha;
			end

			_o = _o .. _alpha[lnum];
			return _o, #_o;
		elseif node.style == "UpperRoman" then
			local roman_nums = {
				{ "M",  1000 },
				{ "CM", 900  },
				{ "D",  500  },
				{ "CD", 400  },
				{ "C",  100  },
				{ "XC", 90   },
				{ "L",  50   },
				{ "XL", 40   },
				{ "X",  10   },
				{ "IX", 9    },
				{ "V",  5    },
				{ "IV", 4    },
				{ "I",  1    },
			};

			local _s = "";

			for _, tuple in ipairs(roman_nums) do
				while number >= tuple[2] do
					lnum = lnum - tuple[2];
					_s = _s .. tuple[1]
				end
			end

			return _s, #_s;
		else
			local roman_nums = {
				{ "m",  1000 },
				{ "cm", 900  },
				{ "d",  500  },
				{ "cd", 400  },
				{ "c",  100  },
				{ "xc", 90   },
				{ "l",  50   },
				{ "xl", 40   },
				{ "x",  10   },
				{ "ix", 9    },
				{ "v",  5    },
				{ "iv", 4    },
				{ "i",  1    },
			};

			local _s = "";

			for _, tuple in ipairs(roman_nums) do
				while number >= tuple[2] do
					lnum = lnum - tuple[2];
					_s = _s .. tuple[1]
				end
			end

			return _s, #_s;
		end

		---|fE
	end

	--- Handles ordered list candidates.
	---@param candidate table
	---@param L integer
	---@return string
	local function handle_candidate (candidate, L)
		---|fS

		local delim = str(node.listAttributes.delimiter) == "Period" and "." or ")";
		local _output = "";

		local W = width or markdoc.config.width;
		local indent = markdoc.state.depth * 2;

		local content = markdoc.traverse(candidate);
		local lnum, lnum_len = get_marker(L);

		local should_wrap = true;
		local within_table = false;

		local function update_state (line)
			local blck = markdoc.config.block_quotes.default.border;

			local top = markdoc.config.table.top;
			local bot = markdoc.config.table.bottom;

			if should_wrap == true and string.match(line, "%>.*") then
				should_wrap = false;
			elseif should_wrap == true and string.match(line, "^%<") then
				should_wrap = true;
			elseif should_wrap == true and string.match(line, blck) then
				should_wrap = false;
			elseif within_table == false and string.match(line, top[1] .. top[2]) then
				should_wrap = false;
				within_table = true;
			elseif within_table == true and string.match(line, bot[1] .. bot[2]) then
				should_wrap = false;
				within_table = false;
			elseif within_table == false then
				should_wrap = true;
			end
		end

		for p, paragraph in ipairs(split(content, "\n")) do
			update_state(paragraph)

			if should_wrap == true then
				local wrapped = wrap(paragraph, W - (indent + 2));

				for l, line in ipairs(split(wrapped, "\n")) do
					_output = _output .. string.rep(" ", indent);

					if l == 1 and p == 1 then
						_output = _output .. lnum .. (delim or ".") .. " " .. line;
					else
						_output = _output .. string.rep(" ", lnum_len) .. "  " .. line;
					end

					_output = _output .. "\n";
				end
			else
				_output = _output .. string.rep(" ", indent);
				_output = _output .. string.rep(" ", lnum_len) .. "  " .. paragraph .. "\n";
			end
		end

		return _output;

		---|fE
	end

	local _output = "";
	local S = node.start or 1;

	for c, candidate in ipairs(node.content) do
		_output = _output .. handle_candidate(candidate, S + (c - 1));
	end

	return (markdoc.state.depth > 1 and "\n\n" or "\n") .. _output .. (markdoc.state.depth > 1 and "\n" or "");

	---|fE
end

--- A paragraph.
---@param node table
---@return string
markdoc.Para = function (node, _, width)
	return "\n" .. wrap(markdoc.traverse(node.content), width) .. "\n";
end

--- Plain text
---@param node table
---@return string
markdoc.Plain = function (node, _, width)
	return wrap(markdoc.traverse(node.content), width);
end

--- Regular string.
---@param node table
---@return string
markdoc.Str = function (node)
	return node.text;
end

--- Striked text.
---@param node table
---@return string
markdoc.Strikeout = function (node)
	return markdoc.traverse(node.content, " ");
end

--- Bold text.
---@param node table
---@return string
markdoc.Strong = function (node)
	return markdoc.traverse(node.content, " ");
end

--- Subscript text.
---@param node table
---@return string
markdoc.Subscript = function (node)
	return markdoc.traverse(node.content, " ");
end

--- Superscript text.
---@param node table
---@return string
markdoc.Superscript = function (node)
	return markdoc.traverse(node.content, " ");
end

--- Table
---@param node table
---@return string
markdoc.Table = function (node)
	---|fS

	local alignments = {};
	local widths = {};

	for _, col in ipairs(node.colspecs) do
		---|fS

		if col[1] == "AlignDefault" then
			table.insert(alignments, "l");
		elseif col[1] == "AlignLeft" then
			table.insert(alignments, "l");
		elseif col[1] == "AlignRight" then
			table.insert(alignments, "r");
		else
			table.insert(alignments, "c");
		end

		if type(col[2]) == "number" then
			table.insert(widths, col[2]);
		else
			table.insert(widths, markdoc.config.table.width);
		end

		---|fE
	end

	local W = (markdoc.config.table.width or 10) - 2;

	local function handle_row (as, row)
		---|fS

		local borders = markdoc.config.table[as] or {};

		local columns = {};
		local row_height = 1;

		for _, cell in ipairs(row) do
			local tmp = markdoc.traverse(cell.content, nil, W);
			local lines = split(tmp, "\n");

			if #lines > row_height then
				row_height = #lines;
			end

			table.insert(columns, lines);
		end

		local _output = "";

		for h = 1, row_height do
			local _line = "";

			for c, col in ipairs(columns) do
				_line = _line .. (c == 1 and borders[1] or borders[2]) .. " " .. align(alignments[c], col[h] or "", W) .. " ";
			end

			_output = _output .. _line .. borders[3] .. "\n";
		end

		return _output;

		---|fE
	end

	local top = markdoc.config.table.top;
	local h_s = markdoc.config.table.header_separator;
	local sep = markdoc.config.table.separator;
	local bot = markdoc.config.table.bottom;

	local function get_border(borders, index)
		---|fS

		if type(borders) ~= "table" then
			return " ";
		elseif borders[index] == nil then
			return " ";
		end

		return borders[index];

		---|fE
	end

	local _output = "";

	local function decorators(src)
		---|fS

		_output = _output .. get_border(src, 1);
		for c, _ in ipairs(alignments) do
			_output = _output .. (c ~= 1 and get_border(src, 4) or "") .. string.rep(get_border(src, 2), W + 2);
		end
		_output = _output .. get_border(src, 3) .. "\n";

		---|fE
	end

	--- Top section
	decorators(top)

	for r, row in ipairs(node.head.rows or {}) do
		---|fS

		_output = _output .. handle_row("header", row.cells);

		if r ~= #node.head.rows then
			_output = _output .. get_border(h_s, 1);
			for c, _ in ipairs(alignments) do
				_output = _output .. (c ~= 1 and get_border(h_s, 4) or " ") .. string.rep(get_border(h_s, 2) or " ", W + 2);
			end
			_output = _output .. get_border(h_s, 3) .. "\n";
		end

		---|fE
	end

	--- Separator
	decorators(sep)

	--- Table bodies(yeah, there can be multiple bodies).
	for _, row in ipairs(node.bodies or {}) do
		---|fS

		--- Bodies are just lists of rows.
		for i, item in ipairs(row.body) do
			_output = _output .. handle_row("row", item.cells);

			if i ~= #row.body then
				_output = _output .. get_border(h_s, 1);
				for c, _ in ipairs(alignments) do
					_output = _output .. (c ~= 1 and get_border(h_s, 4) or "") .. string.rep(get_border(h_s, 2) or " ", W + 2);
				end
				_output = _output .. get_border(h_s, 3) .. "\n";
			end
		end

		---|fE
	end

	--- Bottom section
	decorators(bot)

	return _output;

	---|fE
end




--- Common whitespace.
---@return string
markdoc.Space = function ()
	return " ";
end

--- Soft line breaks.
---@return string
markdoc.SoftBreak = function ()
	return "\n";
end








--- Turns metadata to configuration table.
markdoc.metadata_to_config = function (metadata)
	---|fS

	if not metadata or not metadata.markdoc then
		--- Markdoc configuration not found!
		return;
	end

	for option, value in pairs(metadata.markdoc) do
		if option == "tags" then
			--- Structure.
			--- tags = {
			---	    ["^.nvim"] = "Hi",
			---	    ["^.txt"] = { "Hello", "Bye" },
			--- }
			local tags =  {};

			for k, v in pairs(value) do
				if type(v) == "table" then
					local _o = {};

					for _, entry in ipairs(v) do
						table.insert(_o, str(entry))
					end

					tags[k] = _o;
				else
					tags[k] = str(v);
				end
			end

			markdoc.config.tags = tags;
		elseif option == "block_quotes" then
			--- Structure.
			--- block_quotes = {
			---     note = { border = "|", top = "→ Note" }
			--- }
			markdoc.config.block_quotes = value;
		elseif option == "table" then
			markdoc.config.table = value;
		elseif option == "width" then
			markdoc.config.width = value;
		end
	end

	---|fE
end

---@param val any
---@return boolean
local is_list = function (val)
	---|fS

	if type(val) ~= "table" then
		return false;
	end

	local index = 0;

	for _ in pairs(val) do
		index = index + 1;

		if val[index] == nil then
			return false;
		end
	end

	return true;

	---|fE
end

--- Traverses the AST.
---@param parent table[]
---@return string
markdoc.traverse = function (parent, between, width)
	---|fS

	between = between or "";
	width = width or markdoc.config.width;

	local _output = "";

	local function add_between(node)
		if _output == "" then
			return false;
		elseif between == "\n" then
			return node.t ~= "SoftBreak";
		else
			return _output ~= "";
		end
	end

	markdoc.state.depth = markdoc.state.depth + 1;

	for _, item in ipairs(parent) do
		if is_list(item) then
			_output = _output .. markdoc.traverse(item, between, width);
		elseif markdoc[item.t] then
			local can_call, val = pcall(markdoc[item.t], item, _output, width);

			if can_call and type(val) == "string" then
				_output = _output .. (add_between(item) == true and between or "") .. val;
			elseif can_call == false then
				print(val)
			end
		end
	end

	markdoc.state.depth = markdoc.state.depth - 1;

	return _output;

	---|fE
end

--- Writer for markdoc.
---@param document table
---@return string
function Writer (document)
	markdoc.metadata_to_config(document.meta);
	local converted = markdoc.traverse(document.blocks)

	print(document.blocks)
	print(converted);
	return converted;
end
