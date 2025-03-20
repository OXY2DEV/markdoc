--- Generic markdown to Vimdoc transformer.
local markdoc = {};

--- Options for block quotes.
---@class mkdoc.block_quote_opts
---
---@field border? string Border for block quotes.
---@field callout? string Callout string for block quotes.
---@field icon? string Icon before titles in block quotes.


--- Options for tables.
---@class mkdoc.table_opts
---
---@field col_minwidth? integer Minimum column width.
---@field top? string[] Top border.
---@field header? string[] Border for headers.
---
---@field separator? string[] Separator between header & rows.
---@field header_separator? string[] Separator between headers.
---@field row_separator? string[] Separator between rows.
---
---@field row? string[] Border for rows.
---@field bottom? string[] Bottom border.


--- Base configuration table
--- for markdoc.
---@class markdoc.config
---
---@field block_quotes table<string, mkdoc.block_quote_opts>
---
--- Should link references be folded.
---@field fold_refs? boolean
--- Markers for folding.
---@field foldmarkers? string
---
--- Heading text pattern & the corresponding
--- tag.
---@field tags table<string, string | string[]>
---@field table? mkdoc.table_opts
---
--- Width of help file.
---@field textwidth? number
---
--- Document title.
---@field title? string
--- Document title tag.
---@field title_tag? string
---
--- Title for TOC.
---@field toc_title? string
--- TOC entries.
---@field toc? table<string, string>
markdoc.config = {
	textwidth = 78,

	block_quotes = {
		default = {
			border = "▌"
		},

		caution = {
			callout = "▌ 🛑 Caution",
			icon = ""
		},
		important = {
			callout = "▌ 🧩 Important",
			icon = ""
		},
		note = {
			callout = "▌ 📜 Note",
			icon = ""
		},
		tip = {
			callout = "▌ 💡 Tip",
			icon = ""
		},
		warning = {
			callout = "▌ 🚨 Warning",
			icon = ""
		},
	},

	table = {
		col_minwidth = 10,

		top = { "┏", "━", "┓", "┳" },
		header = { "┃", "┃", "┃" },

		separator = { "┡", "━", "┩", "╇" },
		header_separator = { "├", "─", "┤", "┼" },
		row_separator = { "├", "─", "┤", "┼" },

		row = { "│", "│", "│" },
		bottom = { "└", "─", "┘", "┴" }
	}
};

markdoc.state = {
	depth = 0,
	within_tag = nil,

	link_refs = {},
	image_refs = {}
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
	---|fS

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

	---|fE
end

local function wrap(text, width)
	---|fS

	width = width or markdoc.config.textwidth;
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

	for _, code in utf8.codes(text) do
		local char = utf8.char(code);
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
		local line_length = utf8.len(string.match(_output, "\n?([^\n]-)$"));
		local len = utf8.len(token) or 0;

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

				for _, code in utf8.codes(token) do
					if chars == width then
						_output = _output .. "\n";
						chars = 0;
					end

					_output = _output .. utf8.char(code);
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

local function align(alignment, text, width, fill)
	---|fS

	text = text or "";
	alignment = alignment or "l";
	width = math.floor(width or markdoc.config.textwidth);

	local LEN = utf8.len(text);

	if not LEN then
		return text;
	end

	if alignment == "l" then
		return text .. string.rep(fill or " ", width - LEN);
	elseif alignment == "r" then
		return string.rep(fill or " ", width - LEN) .. text;
	else
		local L = math.ceil((width - LEN) / 2);
		local R = math.floor((width - LEN) / 2);

		return string.rep(fill or " ", L) .. text .. string.rep(fill or " ", R);
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

local function new_link_ref(entry)
	---|fS

	local nums = {
		["0"] = "⁰",
		["1"] = "¹",
		["2"] = "²",
		["3"] = "³",
		["4"] = "⁴",
		["5"] = "⁵",
		["6"] = "⁶",
		["7"] = "⁷",
		["8"] = "⁸",
		["9"] = "⁹",
	};

	table.insert(markdoc.state.link_refs, entry);
	local num = tostring(#markdoc.state.link_refs);

	local ref = "";

	for digit in string.gmatch(num, ".") do
		ref = nums[digit];
	end

	return ref;

	---|fE
end

local function new_image_ref(entry)
	---|fS

	local nums = {
		["0"] = "₀",
		["1"] = "₁",
		["2"] = "₂",
		["3"] = "₃",
		["4"] = "₄",
		["5"] = "₅",
		["6"] = "₆",
		["7"] = "₇",
		["8"] = "₈",
		["9"] = "₉",
	};

	table.insert(markdoc.state.image_refs, entry);
	local num = tostring(#markdoc.state.image_refs);

	local ref = "";

	for digit in string.gmatch(num, ".") do
		ref = nums[digit];
	end

	return ref;

	---|fE
end

local function update_tag_state (text)
	if string.match(text, "^</") then
		local tag = string.match(text, "^</(%w+)");

		if markdoc.state.within_tag and tag ~= markdoc.state.within_tag then
			return;
		else
			markdoc.state.within_tag = nil;
		end
	elseif string.match(text, "[^/]>$") then
		local tag = string.match(text, "^<(%w+)");
		local ignore = { "hr", "br" };

		for _, ig in ipairs(ignore) do
			if tag == ig then
				return;
			end
		end

		if markdoc.state.within_tag then
			return;
		else
			markdoc.state.within_tag = tag;
		end
	end
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

local function fix_newlines (output)
	return string.gsub(output, "\n\n\n+", "\n\n");
end

local function align_tags (output)
	---|fS

	output = string.gsub(output, "::MKDocCenter::[^\n]*\n", function (val)
		local _val = string.gsub(val, "::MKDocCenter::", ""):gsub("\n$", "");
		return align("c", _val, markdoc.config.textwidth) .. "\n";
	end);

	output = string.gsub(output, "::MKDocLeft::[^\n]*\n", function (val)
		local _val = string.gsub(val, "::MKDocLeft::", ""):gsub("\n$", "");
		return align("l", _val, markdoc.config.textwidth) .. "\n";
	end);

	output = string.gsub(output, "::MKDocRight::[^\n]*\n", function (val)
		local _val = string.gsub(val, "::MKDocRight::", ""):gsub("\n$", "");
		return align("r", _val, markdoc.config.textwidth) .. "\n";
	end);

	return output;

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

				if line:match("%>") then
					_output = _output .. "\n\n" .. "  " .. line;
				elseif border == false then
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

		local W = width or markdoc.config.textwidth;
		local indent = markdoc.state.depth * 2;

		local content = markdoc.traverse(candidate):gsub("^\n", "");
		local should_wrap = true;
		local within_table = false;

		local function update_state (line)
			---@type string
			local blck = markdoc.config.block_quotes.default.border or "";

			local top = markdoc.config.table.top or { "", "", "", "" };
			local bot = markdoc.config.table.bottom or { "", "", "", "" };

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
	return markdoc.traverse(node.content, "");
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

		for k, _ in pairs(markdoc.config.tags or {}) do
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

	local txt = markdoc.traverse(node.content, "");
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
					table.insert(lines, align("l", txt_l[i], L) .. " " .. align("r", tag_l[i], R));
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

		return _o .. "\n";

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

		return _o .. "\n";

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

		return _o .. "\n";

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

--- Links.
---@param node table
---@param width integer
---@return string
markdoc.Link = function (node, _, width)
	local content = markdoc.traverse(node.content);
	local ref = new_link_ref(node.target);

	return wrap(content .. ref, width);
end

--- Image.
---@param node table
---@param width integer
---@return string
markdoc.Image = function (node, _, width)
	local content = markdoc.traverse(node.caption);
	local ref = new_image_ref(node.src);

	return wrap(content .. ref, width);
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

		local W = width or markdoc.config.textwidth;
		local indent = markdoc.state.depth * 2;

		local content = markdoc.traverse(candidate);
		local lnum, lnum_len = get_marker(L);

		local should_wrap = true;
		local within_table = false;

		local function update_state (line)
			local blck = markdoc.config.block_quotes.default.border or "";

			local top = markdoc.config.table.top or { "", "", "", "" };
			local bot = markdoc.config.table.bottom or { "", "", "", "" };

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
	local content = markdoc.traverse(node.content);
	local lines = split(content, "\n");
	local _output = "";

	for _, line in ipairs(lines) do
		_output = _output .. wrap(line, width) .. "\n";
	end

	return "\n" .. _output;
end

--- Plain text
---@param node table
---@return string
markdoc.Plain = function (node, _)
	--- NOTE, Plain nodes don't text wrapping!
	local content = markdoc.traverse(node.content);
	return content;
end

--- HTML block elements.
---@param node table
---@return string
markdoc.RawBlock = function (node)
	---|fS

	if node.format ~= "html" then
		return "";
	end

	update_tag_state(node.text);

	if string.match(node.text, "^</") then
		local tag = string.match(node.text, "^</(%S*)"):lower();
		local inline = { "span", "em", "i", "b" };

		for _, item in ipairs(inline) do
			if item == tag then
				--- Closing tags for inline elements
				--- shouldn't end with anything.
				return "";
			end
		end

		--- Closing tags for block elements
		--- should end with a newline.
		return "\n";
	elseif string.match(node.text, "align") then
		local alignment = string.match(node.text, "align%s*=%s*[\"']([^\"']+)[\"']")

		--- Tag text alignment
		if alignment == "center" then
			return "::MKDocCenter::"
		elseif alignment == "right" then
			return "::MKDocRight::"
		else
			return "::MKDocLeft::"
		end
	end

	return "";

	---|fE
end

markdoc.Div = function (node)
	local _output = markdoc.traverse(node.content):gsub("^%s*%>", ""):gsub("%<%s*$", "");

	if node.attr then
		local attributes = node.attr.attributes;

		if attributes.align then
			local alignment = attributes.align;

			--- Tag text alignment
			if alignment == "center" then
				_output = "::MKDocCenter::" .. _output;
			elseif alignment == "right" then
				_output = "::MKDocRight::" .. _output;
			else
				_output = "::MKDocLeft::" .. _output;
			end
		end
	end

	return _output .. "\n";
end

--- HTML inline elements.
---@param node table
---@return string
markdoc.RawInline = function (node)
	---|fS

	update_tag_state(node.text);

	if node.format ~= "html" then
		return "";
	elseif node.text == "<MKDocTOC/>" then
		return "::MKDocTOC::";
	elseif node.text == "<br>" then
		return "\n\n";
	elseif string.match(node.text, "^<img") then
		local src = string.match(node.text, "src%s*=%s*[\"']([^\"']+)[\"']")

		if src then
			local _src = new_image_ref(src);
			return "image" .. _src;
		end
	elseif string.match(node.text, "^<a") then
		local href = string.match(node.text, "href%s*=%s*[\"']([^\"']+)[\"']")

		if href then
			local _href = new_link_ref(href);
			return _href;
		end
	end

	return "";

	---|fE
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
	return markdoc.traverse(node.content, "");
end

--- Bold text.
---@param node table
---@return string
markdoc.Strong = function (node)
	return markdoc.traverse(node.content, "");
end

--- Subscript text.
---@param node table
---@return string
markdoc.Subscript = function (node)
	return markdoc.traverse(node.content, "");
end

--- Superscript text.
---@param node table
---@return string
markdoc.Superscript = function (node)
	return markdoc.traverse(node.content, "");
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

		local calculated_width = math.floor((markdoc.config.textwidth - #node.colspecs) * (col[2] or 0));
		local assumed_width = math.floor((markdoc.config.textwidth - #node.colspecs - 1) / #node.colspecs)

		table.insert(widths, math.max(calculated_width, assumed_width, markdoc.config.table.col_minwidth));

		---|fE
	end

	local function handle_row (as, row)
		---|fS

		local borders = markdoc.config.table[as] or {};

		local columns = {};
		local row_height = 1;

		for c, cell in ipairs(row) do
			local tmp = wrap(markdoc.traverse(cell.content, nil, widths[c] - 2), widths[c] - 2);
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
				_line = _line .. (c == 1 and borders[1] or borders[2]) .. " " .. align(alignments[c], col[h] or "", widths[c] - 2) .. " ";
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

	local _output = "\n";

	local function decorators(src)
		---|fS

		_output = _output .. get_border(src, 1);
		for c, _ in ipairs(alignments) do
			_output = _output .. (c ~= 1 and get_border(src, 4) or "") .. string.rep(get_border(src, 2), widths[c]);
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
				_output = _output .. (c ~= 1 and get_border(h_s, 4) or " ") .. string.rep(get_border(h_s, 2) or " ", widths[c]);
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
					_output = _output .. (c ~= 1 and get_border(h_s, 4) or "") .. string.rep(get_border(h_s, 2) or " ", widths[c]);
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
	if markdoc.state.within_tag then
		return " ";
	end

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
		if option == "block_quotes" then
			---|fS

			local _b = {};

			for key, main_value in pairs(value) do
				local _o = {};

				for sub_key, sub_value in pairs(main_value) do
					if key == "default" and (sub_key == "callout" or sub_key == "icon") then
						goto continue;
					end

					_o[sub_key] = str(sub_value);
				    ::continue::
				end

				_b[key] = _o;
			end

			markdoc.config.block_quotes = extend(markdoc.config.block_quotes, _b);

			---|fE
		elseif option == "fold_refs" then
			markdoc.config.fold_refs = str(value) == "true";
		elseif option == "foldmarkers" then
			markdoc.config.foldmarkers = str(value);
		elseif option == "tags" then
			---|fS

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

			---|fE
		elseif option == "table" then
			---|fS

			local _t = {};

			for k, v in pairs(value) do
				if k == "col_minwidth" then
					_t.col_minwidth = tonumber(str(v));
				else
					local _b = {};

					for _, border in ipairs(v) do
						table.insert(_b, str(border));
					end

					_t[k] = _b;
				end
			end

			markdoc.config.table = extend(markdoc.config.table, _t);

			---|fE
		elseif option == "textwidth" then
			---@diagnostic disable-next-line
			markdoc.config.textwidth = tonumber(str(value));
		elseif option == "title" then
			markdoc.config.title = str(value);
		elseif option == "title_tag" then
			markdoc.config.title_tag = str(value);
		elseif option == "toc_title" then
			markdoc.config.toc_title = str(value);
		elseif option == "toc" then
			---|fS

			local _toc = {};

			for k, v in pairs(value) do
				_toc[k] = str(v);
			end

			markdoc.config.toc = _toc;

			---|fE
		end
	end

	---|fE
end

--- Traverses the AST.
---@param parent table[]
---@return string
markdoc.traverse = function (parent, between, width)
	---|fS

	between = between or "";
	width = width or markdoc.config.textwidth;

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
				print("\27[31mError encountered for " .. item.t);
				print("\27[31m" .. val);
			end
		end
	end

	markdoc.state.depth = markdoc.state.depth - 1;

	return _output;

	---|fE
end

--- Creates header for help files.
---@return string
markdoc.header = function (text)
	---|fS

	local _output = "";

	local L = math.ceil((markdoc.config.textwidth - 2) / 2);
	local R = math.floor((markdoc.config.textwidth - 2) / 2);

	if markdoc.config.title or markdoc.config.title_tag then
		---|fS

		local _title = split(wrap(markdoc.config.title or "", L), "\n");
		local _tag = string.format("*%s*", markdoc.config.title_tag);

		if _tag and #_title > 1 then
			--- Tag & Title.
			_output = _output .. _tag .. "\n";

			for _, line in ipairs(_title) do
				_output = _output .. align("r", line, L + R + 2) .. "\n";
			end
		elseif _tag and #_title == 1 then
			--- Tag & Title that fits in 1 
			_output = _output .. align("l", _tag, L) .. " " .. align("r", _title[1], R) .. "\n";
		elseif #_title > 0 then
			--- Just a title.
			for _, line in ipairs(_title) do
				_output = _output .. align("r", line, L + R + 2) .. "\n";
			end
		else
			--- Just a tag.
			_output = _output .. _tag .. "\n";
		end

		_output = _output .. "\n";

		---|fE
	end

	if markdoc.config.toc then
		---|fS

		local _toc = string.rep("-", L + R + 2) .. "\n" .. align("l", markdoc.config.toc_title or "Table of contents:") .. "\n\n";

		for title, address in pairs(markdoc.config.toc) do
			local _title = split(wrap(title, L), "\n");
			local _address = string.format(" |%s|", address);

			if utf8.len(_address) > R then
				goto continue;
			end

			if #_title == 1 then
				_toc = _toc .. " " .. align("l", _title[1] .. " ", L, "•") .. align("r", _address, R, "•") .. " " .. "\n";
			else
				for l, line in ipairs(_title) do
					if l == #_title then
						_toc = _toc .. " " .. align("l", line .. " ", L, "•") .. align("r", _address, R, "•") .. " " .. "\n";
					else
						_toc = _toc .. " " .. align("l", line .. " ", L + R, "•") .. " " .. "\n";
					end
				end
			end

		    ::continue::
		end

		if string.match(text, "::MKDocTOC::") then
			_toc = _toc:gsub("\n$", "");
			text = string.gsub(text, "::MKDocTOC::", _toc, 1);
		else
			_output = _output .. _toc .. "\n";
		end

		---|fE
	end

	return _output .. text;

	---|fE
end

markdoc.footer = function ()
	---|fS

	local _output = "\n" .. string.rep("-", markdoc.config.textwidth or 1) .. "\n\n";

	local foldmarkers = markdoc.config.foldmarkers or "{{{,}}}";
	local foldopen, foldclose = string.match(foldmarkers, "^([^,]-),([^,]-)$")

	if #markdoc.state.link_refs > 0 then
		_output = _output .. "Link references ~" .. "\n\n";

		if markdoc.config.fold_refs == true then
			_output = _output .. foldopen .. "Use 'za' to toggle fold" .. "\n";
		end

		---@type integer
		local max_len = #tostring(#markdoc.state.link_refs) + 1;

		for l, link in ipairs(markdoc.state.link_refs) do
			_output = _output .. string.format("%s: %s\n", align("r", tostring(l), max_len), link);
		end

		if markdoc.config.fold_refs == true then
			_output = _output .. foldclose;
		end

		_output = _output .. "\n"
	end

	if #markdoc.state.image_refs > 0 then
		_output = _output .. "Image references ~" .. "\n\n";

		if markdoc.config.fold_refs == true then
			_output = _output .. foldopen .. "Use 'za' to toggle fold" .. "\n";
		end

		---@type integer
		local max_len = #tostring(#markdoc.state.image_refs) + 1;

		for l, image in ipairs(markdoc.state.image_refs) do
			_output = _output .. string.format("%s: %s\n", align("r", tostring(l), max_len), image);
		end

		if markdoc.config.fold_refs == true then
			_output = _output .. foldclose;
		end

		_output = _output .. "\n"
	end

	_output = _output .. string.format("\nvim:ft=help:tw=%d:ts=2:%s", markdoc.config.textwidth or 78, markdoc.config.fold_refs == true and "foldmethod=marker:" or "")

	return _output;

	---|fE
end

--- Writer for markdoc.
---@param document table
---@return string
function Writer (document)
	markdoc.metadata_to_config(document.meta);
	local converted = markdoc.traverse(document.blocks):gsub("[ ]+%<", "<");

	converted = fix_newlines(converted);
	converted = align_tags(converted);

	converted = markdoc.header(converted);
	converted = converted .. markdoc.footer();

	-- print(converted)
	return converted;
end
