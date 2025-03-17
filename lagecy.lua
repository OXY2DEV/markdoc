--- For debugging,
--- You need to install this package or
--- download the file itself from Github.
---
-- local inspect = require("inspect");

--- Base module(s)

--- Handler for various nodes.
local handler = {};

--- Handler for text styling.
local styles  = {};

 ------------------------------------------------------------------------------------------

---@class doc.block_quotes.opts
---
---@field border string
---@field icon? string
---@field match_string? string
---@field preview? string
---@field skip_end? string
---@field skip_start? string
---@field title? boolean


---@class vimdoc.block_quotes
---
---@field default doc.block_quotes.opts
---@field patterns doc.block_quotes.opts[]


---@class vimdoc.tables
---
---@field top string[]
---@field header string[]
---@field separator string[]
---@field header_separator string[]
---@field row_separator string[]
---@field row string[]
---@field bottom string[]

---@class vimdoc.config
---
---@field block_quotes vimdoc.block_quotes               Changes how block quotes & callouts/alerts look.
---@field count_conceal boolean                          When `true`, the amount of columns that will be concealed is counted too when aligning text.
---@field emph_style "none" | "simple" | "fancy"         *Emphasized* text style.
---@field hr_part string                                 Text to use for the horizontal rules.
---@field image_style "none" | "simple" | "fancy"        Image link style.
---@field link_style "none" | "simple" | "fancy"         Hyperlink style.
---@field list_marker string                             Text to use as the marker for bullet list.
---@field strikeout_style "none" | "simple" | "fancy"    ~~Strikeout~~ text style.
---@field strong_style "none" | "simple" | "fancy"       **Bold** text style.
---@field subscript_style "none" | "simple" | "fancy"    Subscript text style.
---@field superscript_style "none" | "simple" | "fancy"  Superscript text style.
---@field tables vimdoc.tables                           Changes how tables look.
---@field tabstop integer                                Amount of spaces used for every indentation level.
---@field textwidth integer                              Changes the width of the document & where text is wrapped.
handler.config = {
	textwidth = 78,
	tabstop = 4,
	count_conceal = false,

	toc_text_width = 70,
	toc_separator = "•",

	link_style = "fancy",
	image_style = "fancy",

	emph_style = "simple",
	strong_style = "simple",
	subscript_style = "simple",
	superscript_style = "simple",
	default_cell_alignment = "left",

	block_quotes = {
		default = {
			border = "▋",
			skip_start = "▘",
			skip_end = "▖",

			preview = nil,
			title = true,
			icon = "",
		},

		patterns = {
			{
				match_string = "NOTE",
				border = "▋",
				skip_start = "▘",
				skip_end = "▖",

				preview = "📜 Note:",
				icon = "📜 ",
				title = true
			},
			{
				match_string = "TIP",
				border = "▋",
				skip_start = "▘",
				skip_end = "▖",

				preview = "💡 Tip:",
				icon = "💡 ",
				title = true
			},
			{
				match_string = "IMPORTANT",
				border = "▋",
				skip_start = "▘",
				skip_end = "▖",

				preview = "💬 Important:",
				icon = "💬 ",
				title = true
			},
			{
				match_string = "WARNING",
				border = "▋",
				skip_start = "▘",
				skip_end = "▖",

				preview = "🚨 Warning:",
				icon = "🚨 ",
				title = true
			},
			{
				match_string = "CAUTION",
				border = "▋",
				skip_start = "▘",
				skip_end = "▖",

				preview = "🔶 Caution:",
				icon = "🔶 ",
				title = true
			},
		}
	},

	tables = {
		top = { "╭", "─", "╮", "┬" },
		header = { "│", "│", "│" },
		separator = { "├", "─", "┤", "┼" },
		header_separator = { "├", "─", "┤", "┼" },
		row_separator = { "├", "─", "┤", "┼" },
		row = { "│", "│", "│" },
		bottom = { "╰", "─", "╯", "┴" }
	}
};

handler.cache = {
	wrap = true,

	parents = {},
	block_quotes = {},

	links = {},
	images = {},

	name = nil,
	desc = nil,
	tags = {},
	toc = nil,
};

local stringify = function (data)
	local pandoc = require("pandoc");

	if type(data) ~= "table" then
		return tostring(data);
	end

	return pandoc.utils.stringify(data);
end

local list_contains = function (source, value)
	for _, item in ipairs(source) do
		if item == value then
			return true;
		end
	end

	return false;
end

local is_list = function (val)
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
end

local str_sub = function (text, from, to)
	from = from or 1;
	to = to or -1;

	if from < 1 or to < 1 then
		local len = utf8.len(text);

		if not len then return nil end

		if from < 0 then from = len + 1 + from end
		if to < 0 then to = len + 1 + to end

		if from < 0 then
			from = 1;
		elseif from > len then
			from = len
		end

		if to < 0 then
			to = 1;
		elseif to > len then
			to = len;
		end
	end

	if to < from then
		return "";
	end

	from = utf8.offset(text, from);
	to = utf8.offset(text, to + 1);

	if from and to then
		return text:sub(from, to - 1);
	elseif from then
		return text:sub(from);
	else
		return "";
   end
end

local property = function (source, keys)
	if not source or not keys then
		return;
	end

	local _o = source;

	for _, key in ipairs(keys) do
		if tonumber(key) then
			key = tonumber(key);
		end

		_o = _o[key];

		if _o == nil then
			return;
		end
	end

	return _o;
end

handler.to_roman = function (number)
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
			number = number - tuple[2];
			_s = _s .. tuple[1]
		end
	end

	return _s;
end

handler.to_alpha = function (number)
	local alphabets = {
		"a", "b", "c", "d", "e",
		"f", "g", "h", "i", "j",
		"k", "l", "m", "n", "o",
		"p", "q", "r", "s", "t",
		"u", "v", "w", "x", "y",
		"z"
	};
	local _s = "";

	while number >= #alphabets do
		_s = alphabets[#alphabets];
		number = number - #alphabets
	end

	_s = alphabets[number];
	return _s;
end

handler.wrap = function (text, max_width, add_newline)
	max_width = max_width or handler.config.textwidth;
	local marker = handler.config.hr_part or "-";

	local source = text or "";
	local _l = {};

	local function append(val)
		if #_l == 0 then
			table.insert(_l, {});
		end

		table.insert(_l[#_l], val);
	end

	if source == "" then
		return { "" };
	end

	while source ~= "" do
		if source:match("^\n") then
			--- Newline
			table.insert(_l, {});
			source = source:gsub("^\n", "");
		elseif source:match("^" .. marker .. marker .. "+") then
			table.insert(_l, { string.rep(marker, max_width - 1) });
			table.insert(_l, {});
			source = source:gsub("^" .. marker .. "+", "");
		-- elseif source:match("^%>[ \t]*") then
		-- 	--- Block quote
		-- 	table.insert(_l, { source:match("^%>[ \t]*", "") });
		-- 	source = source:gsub("^%>[ \t]*", "");
		elseif source:match("^%↑%([^%)]+%)") then
			--- Superscript
			append(source:match("^%↑%([^%)]+%)"));
			source = source:gsub("^%↑%([^%)]+%)", "");
		elseif source:match("^%↓%([^%)]+%)") then
			--- Subscript
			append(source:match("^%↓%([^%)]+%)"));
			source = source:gsub("^%↓%([^%)]+%)", "");
		elseif source:match("^%!%([^%)]+%)") then
			--- Images
			append(source:match("^%!%([^%)]+%)"));
			source = source:gsub("^%!%([^%)]+%)", "");
		elseif source:match("^%([^%)]+%)") then
			--- Hyperlink
			append(source:match("^%([^%)]+%)"));
			source = source:gsub("^%([^%)]+%)", "");
		elseif source:match("^%[%[[^%]]+%]%]") then
			--- Italics
			append(source:match("^%[%[[^%]]+%]%]"));
			source = source:gsub("^%[%[[^%]]+%]%]", "");
		elseif source:match("^%[[^%]]+%]") then
			--- Italics
			append(source:match("^%[[^%]]+%]"));
			source = source:gsub("^%[[^%]]+%]", "");
		elseif source:match("^%`[^%`]+%`") then
			--- Inline codes
			append(source:match("^%`[^%`]+%`"));
			source = source:gsub("^%`[^%`]+%`", "");
		elseif source:match("^%*[^%*]+%*") then
			--- Inline codes
			append(source:match("^%*[^%*]+%*"));
			source = source:gsub("^%*[^%*]+%*", "");
		elseif source:match("^%'[^%']+%'") then
			--- Quoted text
			append(source:match("^%'[^%']+%'"));
			source = source:gsub("^%'[^%']+%'", "");
		elseif source:match("^[ \t]+") then
			--- Whitespaces
			append(source:match("^[ \t]+"));
			source = source:gsub("^[ \t]+", "");
		elseif source:match("^%S+") then
			--- Text, final filter
			append(source:match("^%S+"));
			source = source:gsub("^%S+", "");
		end
	end

	local lines = {};
	local line_width = 0;

	local function sub_divide(txt)
		local str_width = styles.strdisplaywidth(txt);
		local sub_divisions = math.floor(str_width / max_width) + 1;

		for s = 1, sub_divisions do
			if s == 1 then
				lines[#lines] = (lines[#lines] or "") .. str_sub(txt, (s - 1) * max_width, s * max_width);
			else
				table.insert(
					lines,
					str_sub(txt, (s - 1) * max_width, s * max_width)
				);
			end

			if s == sub_divisions then
				line_width = styles.strdisplaywidth(
					str_sub(txt, (s - 1) * max_width, s * max_width)
				);
			end
		end
	end

	local function line_processor(tbl)
		line_width = 0;

		for _, part in ipairs(tbl) do
			local part_width = styles.strdisplaywidth(part);
			if part == "\n" then
				line_width = 0;
			elseif part_width >= max_width then
				-- table.insert(lines, "");
				sub_divide(part);
			elseif line_width + part_width >= max_width then
				table.insert(lines, part);
				line_width = part_width;
			else
				lines[#lines] = lines[#lines] .. part;
				line_width = line_width + part_width;
			end
		end
	end

	for _, line in ipairs(_l) do
		table.insert(lines, "");

		line_processor(line);
	end

	local skip = false;

	--- Remove spaces from the start of the
	--- lines.
	for i, out in ipairs(lines) do
		--- Code lock
		if out:match("%>.*") then
			skip = true;
		elseif
			skip == true and
			out:match("^%<")
		then
			skip = false;
		--- List item
		elseif out:match("^%s+" .. (handler.config.list_marker or "•")) then
			skip = true;
		elseif skip == true and out == "" then
			skip = false;
		elseif skip == false then
			lines[i] = out:gsub("^[ ]+", "");
		end
	end

	lines = handler.strip_empty_lines(lines);

	if
		add_newline ~= false and
		lines[#lines] ~= ""
	then
		table.insert(lines, "");
	end

	return lines;
end

handler.strip_empty_lines = function (lines)
	local count = #lines;

	for l = count, 1, -1 do
		if lines[l] == "" then
			table.remove(lines, l);
		else
			break;
		end
	end

	return lines;
end

 ------------------------------------------------------------------------------------------

--- Node handlers
---@param node { content: table[], tag: string }
handler.BlockQuote = function (node)
	local function get_level ()
		for level, entries in ipairs(handler.cache.block_quotes) do
			for _, entry in ipairs(entries) do
				if entry == node then
					return level;
				end
			end
		end

		return 1;
	end

	local level = get_level();
	local callout, title;

	local content = handler.init(node.content);
	local text    = table.concat(content, "\n");

	if text then
		callout = text:match("^%s*%[%!([^%]]+)%]");
	end

	if not handler.config.block_quotes then
		handler.config.block_quotes = {
			default = {
				border = "",
				skip_start = "",
				skip_end = ""
			},
			patterns = {}
		}
	end

	local config = handler.config.block_quotes.default or {};

	for _, conf in ipairs(handler.config.block_quotes.patterns or {}) do
		local match_string = conf.match_string or "";

		if not callout then
			break;
		elseif
			callout and
			match_string:match("^%^") and
			callout:match(match_string)
		then
			config = conf;
			break;
		elseif
			callout and
			string.lower(callout) == string.lower(match_string)
		then
			config = conf;
			break;
		end
	end

	local lines = {};
	local skip, exited_skip = false, false;

	for _, line in ipairs(content) do
		if
			skip == false and
			(
				line:match("%>.*") or
				line:match("^%" .. (property(handler.config, { "tables", "top", "1" }) or ""))
			)
		then
			table.insert(lines, line);
			skip = true;
		elseif
			skip == true and
			(
				line:match("%<") or
				line:match("^%" .. (property(handler.config, { "tables", "bottom", "1" }) or ""))
			)
		then
			table.insert(lines, line);

			skip = false;
			exited_skip = true;
		elseif exited_skip == true then
			table.insert(lines, line);

			skip = false;
			exited_skip = false;
		elseif skip == false then
			local _o = handler.wrap(line, handler.config.textwidth - (level * 2))
			_o = handler.strip_empty_lines(_o);

			for _, l in ipairs(_o) do
				table.insert(lines, l);
			end
		else
			table.insert(lines, line);
		end
	end

	title = lines[1]:match("^%[%![^%]]+%]%s+(.+)$")

	if
		(title and config.title == true) or
		(callout and config.preview)
	then
		table.remove(lines, 1);
	end

	lines = handler.strip_empty_lines(lines);

	for l, line in ipairs(lines) do
		if
			skip == false and
				line:match("%>.*")
		then
			lines[l] = (config.skip_start or "") .. " " .. lines[l];
			skip = true;
		elseif
			skip == false and
			line:match("^%" .. (property(handler.config, { "tables", "top", "1" }) or ""))
		then
			skip = true;
		elseif
			skip == true and
			(
				line:match("%<") or
				line:match("^%" .. (property(handler.config, { "tables", "bottom", "1" }) or ""))
			)
		then
			if
				l < #lines and
				lines[l + 1] ~= ""
			then
				lines[l + 1] = (config.skip_end or "") .. " " .. lines[l + 1];
			end

			skip = false;
			exited_skip = true;
		elseif exited_skip == true then
			skip = false;
			exited_skip = false;
		elseif skip == false then
			lines[l] = (config.border or "") .. " " .. line;
		end
	end

	if
		config.title == true and
		title
	then
		table.insert(
			lines,
			1,
			string.format(
				"%s %s%s",
				config.border or "",
				config.icon or "",
				title
			)
		)
	elseif
		config.preview and
		callout
	then
		table.insert(
			lines,
			1,
			string.format(
				"%s%s",
				config.border or "",
				config.preview
			)
		)
	end

	if lines[#lines] ~= "" then
		table.insert(lines, "");
	end

	return lines;
end

handler.BulletList = function (node)
	local max_width = handler.config.textwidth;
	local marker = handler.config.list_marker or "•";

	local indent = handler.config.tabstop;
	local lines = {};

	for i, item in ipairs(node.content) do
		handler.cache.wrap = false;
		local item_parts = handler.init(item);
		handler.cache.wrap = true;
		local item_text  = table.concat(item_parts, "\n");

		local _l = handler.wrap(item_text, max_width - indent - styles.strdisplaywidth(marker) - 1);
		_l[1] = marker .. " " .. _l[1];

		--- TODO, Not sure if this is necessary
		if i == #node.content then
			_l = handler.strip_empty_lines(_l);
		end

		for l, ln in ipairs(_l) do
			if ln ~= "" then
				if l ~= 1 then
					ln = string.rep(" ", indent + 2) .. ln;
				else
					ln = string.rep(" ", indent) .. ln;
				end
			end

			table.insert(lines, ln);
		end
	end

	table.insert(lines, "");
	return lines;
end

handler.CodeBlock = function (node)
	local language = node.classes[1];
	local indent = handler.config.tabstop or 0;
	local lines = {};

	table.insert(lines, ">" .. (language or ""));

	if not node.text:match("\n$") then
		node.text = node.text .. "\n";
	end

	for line in node.text:gmatch("(.-)\n") do
		table.insert(
			lines,
			string.format(
				"%s%s",
				string.rep(" ", indent),
				line
			)
		);
	end

	table.insert(lines, "<");
	return lines;
end

handler.DefinitionList = function (node)
	local lines = {};
	local marker = handler.config.list_marker or "•";
	local indent = handler.config.tabstop;

	for _, item in ipairs(node.content) do
		local definition = handler.init(item[1]);
		local def_text   = table.concat(definition, "");
		local def_wrap   = handler.wrap(def_text);

		local content    = handler.init(item[2] or {});
		local con_text   = table.concat(content, "\n");
		local con_wrap   = handler.wrap(con_text, handler.config.textwidth - indent - 2);

		if def_wrap[#def_wrap] == "" then
			table.remove(def_wrap, #def_wrap)
		end

		for l, line in ipairs(def_wrap) do
			if l == 1 then
				table.insert(
					lines,
					string.format(
						"%s%s %s" .. (#def_wrap == 1 and ":" or ""),
						string.rep(" ", indent),
						marker,
						line
					)
				);
			elseif l == #def_wrap then
				table.insert(
					lines,
					string.format(
						"%s%s:",
						string.rep(" ", indent + 2),
						line
					)
				);
			else
				table.insert(
					lines,
					string.format(
						"%s%s",
						string.rep(" ", indent + 2),
						line
					)
				);
			end
		end

		for _, line in ipairs(con_wrap) do
			if line ~= "" then
				table.insert(
					lines,
					string.format(
						"%s%s",
						string.rep(" ", indent + 2),
						line
					)
				);
			end
		end
	end

	if lines[#lines] ~= "" then
		table.insert(lines, "");
	end
	return lines;
end

handler.Header = function (node)
	local level = node.level;
	local max_width = handler.config.textwidth;

	local content = handler.init(node.content);
	local text    = table.concat(content, "");
	local lines   = handler.wrap(text, level >= 4 and max_width - 2 or nil, false);

	local tags = {};

	--- Gets a tag
	for _, set in ipairs(handler.cache.tags) do
		if string.match(text, set[1]) then
			tags = set[2];
			break;
		end
	end

	local tag = table.remove(tags, 1);

	if level == 1 then
		table.insert(lines, 1, string.rep("=", max_width));
	elseif level == 2 then
		table.insert(lines, 1, string.rep("-", max_width));
	end

	for l, line in ipairs(lines) do
		if level == 3 then
			lines[l] = string.upper(line);
		elseif
			level >= 4 and
			line ~= ""
		then
			lines[l] = line .. " ~";
		elseif level < 3 then
			lines[l] = line;
		end
	end


	if
		tag and
		styles.strdisplaywidth(lines[#lines] .. tag) <= max_width
	then
		local line_width = styles.strdisplaywidth(lines[#lines]);

		if property(handler.config, { "count_conceal" }) == true then
			line_width = line_width - 2;
		end

		lines[#lines] = string.format(
			"%s%" .. (max_width - line_width) .. "s",
			lines[#lines],
			"*" .. tag .. "*"
		);
	elseif tag then
		table.insert(
			lines,
			string.format(
				"%" .. max_width .. "s",
				"*" .. tag .. "*"
			)
		);
	end

	if #tags > 0 then
		local line_width = max_width;
		local _text = "";
		local count = property(handler.config, { "count_conceal" });

		for t, _tag in ipairs(tags) do
			if count == true then
				_text = _text .. string.format("*%s*", _tag);
			else
				_text = _text .. string.format("*%s*", _tag);
			end

			if t ~= #tags then
				_text = _text .. " ";
			end
		end

		local _wrap = handler.wrap(_text, math.floor(line_width / 2), false);

		for _, w in ipairs(_wrap) do
			local tmp_width = line_width;
			local offset = 0;
			w = w:gsub("%s+$", "");

			for _ in w:gmatch("%*") do
				offset = offset + 1;
			end

			if property(handler.config, { "count_conceal" }) == true then
				tmp_width = line_width + offset;
			end

			table.insert(lines, styles.align_text("right", w, tmp_width, false))
		end
	end

	if lines[#lines] ~= "" then
		table.insert(lines, "");
	end
	return lines;
end

handler.HorizontalRule = function (_)
	return {
		string.rep(handler.config.hr_part or "•", handler.config.textwidth),
		""
	};
end

handler.OrderedList = function (node)
	local max_width = handler.config.textwidth;

	local num = node.start;
	local style = node.style;

	local indent = handler.config.tabstop;
	local lines = {};

	for _, item in ipairs(node.content) do
		local item_parts = handler.init(item);
		local item_text  = table.concat(item_parts, "\n");

		local _n = num;

		if style == "Decimal" then
		elseif style == "LowerAlpha" then
			_n = handler.to_alpha(num);
		elseif style == "UpperAlpha" then
			_n = string.upper(handler.to_alpha(num));
		elseif style == "LowerRoman" then
			_n = handler.to_roman(num);
		elseif style == "UpperRoman" then
			_n = string.upper(handler.to_roman(num));
		end

		local _l = handler.wrap(item_text, max_width - styles.strdisplaywidth(_n) - 2);
		_l[1] = _n .. ". " .. _l[1];

		_l = handler.strip_empty_lines(_l);

		for l, ln in ipairs(_l) do
			if ln ~= "" then
				if l ~= 1 then
					ln = string.rep(" ", indent + 3) .. ln;
				else
					ln = string.rep(" ", indent) .. ln;
				end
			end

			table.insert(lines, ln);
		end

		num = num + 1;
	end

	table.insert(lines, "");
	return lines;
end

--- NOTE, This is a translation layer! It turns inline contents
--- into block contents.
--- It wraps the text(when possible).
--- And it MUST return a **list of lines** and not some string.
handler.Para = function (node)
	local content = table.concat(handler.init(node.content), "");
	local lines = handler.wrap(content, handler.cache.wrap == false and math.maxinteger or nil);

	if lines[#lines] ~= "" then
		table.insert(lines, "");
	end
	return lines;
end

-- handler.RawBlock = function (node)
-- 	--- Hide Blocks
-- 	-- return "";
-- end

handler.Table = function (node)
	local align = function (align, text, width)
		if align == "AlignLeft" then
			return styles.align_text("left", text, width - 2, false);
		elseif align == "AlignRight" then
			return styles.align_text("right", text, width - 2, false);
		else
			return styles.align_text(handler.config.default_cell_alignment or "center", text, width - 2, false);
		end
	end

	---@type [ string, integer ][]
	local col_spec = node.colspecs;

	local tbl_head = node.head.rows;
	local tbl_body = node.bodies;

	local border_state = "top";

	---@param name string?
	---@return table
	local get_border = function (name)
		name = name or border_state;
		return handler.config.tables[name] --[[ @as string[] ]] or {};
	end

	local max_width = handler.config.textwidth;

	for b, border in ipairs(get_border("top")) do
		if b == 4 then
			break;
		elseif b == 1 or b == 3 then
			max_width = max_width - styles.strdisplaywidth(border);
		else
			max_width = max_width - ((#col_spec - 1) * styles.strdisplaywidth(border));
		end
	end

	--- FIXME, should we also count the borders?
	local col_width = math.floor((max_width - (#col_spec + 1)) / #col_spec); -- - (#col_spec + 1);

	local create_decorator = function ()
		local borders = get_border();

		local _l = borders[1] or "";

		for c = 1, #col_spec do
			if c == #col_spec then
				_l = _l .. string.rep(borders[2] or " ", col_width) .. (borders[3] or "");
			else
				_l = _l .. string.rep(borders[2] or " ", col_width) .. (borders[4] or "");
			end
		end

		return _l;
	end

	local create_row = function (cols)
		local _lines = {};
		local columns = {};
		local max_lines = 0;

		local borders = get_border();

		for _, col in ipairs(cols) do
			local this_col_width = col_width;
			local col_align = handler.table_align or col.alignment;

			if col_align ~= "AlignCenter" then
				this_col_width = this_col_width - 2;
			end

			local content = handler.init(col.contents);
			local text    = table.concat(content, "\n");

			local wrapped = handler.wrap(text, this_col_width);
			wrapped = handler.strip_empty_lines(wrapped);

			for w, wtext in ipairs(wrapped) do
				wrapped[w] = align(col_align, wtext, col_width);
			end

			table.insert(columns, wrapped);

			if #wrapped > max_lines then
				max_lines = #wrapped;
			end
		end

		for l = 1, max_lines, 1 do
			local line = borders[1];

			for c, column in ipairs(columns) do
				if column[l] then
					line = line .. string.format(" %s ", column[l]);
				else
					line = line .. string.rep(" ", col_width);
				end

				if c ~= #columns then
					line = line .. borders[2];
				else
					line = line .. borders[3];
				end
			end

			table.insert(_lines, line)
		end

		return _lines;
	end

	local lines = {};

	table.insert(lines, create_decorator());
	border_state = "header";

	for _, row in ipairs(tbl_head) do
		local cells = row.cells;
		local _l = create_row(cells);

		for _, line in ipairs(_l) do
			table.insert(lines, line);
		end
	end

	border_state = "separator";
	table.insert(lines, create_decorator());
	border_state = "row";

	for _, body in ipairs(tbl_body) do
		for _, row in ipairs(body.head) do
			local cells = row.cells;
			local _l = create_row(cells);

			for _, line in ipairs(_l) do
				table.insert(lines, line);
			end

			border_state = "header_separator";
			table.insert(lines, create_decorator());
			border_state = "header";
		end

		for r, row in ipairs(body.body) do
			local cells = row.cells;
			local _l = create_row(cells);

			for _, line in ipairs(_l) do
				table.insert(lines, line);
			end

			if r < #body.body then
				border_state = "row_separator";
				table.insert(lines, create_decorator());
				border_state = "row";
			end
		end
	end

	border_state = "bottom";
	table.insert(lines, create_decorator());

	table.insert(lines, "");
	return lines;
end

 ------------------------------------------------------------------------------------------

---@param node { text: string, tag: string }
handler.Code = function (node)
	if property(handler.config, { "count_conceal" }) == true then
		return string.format(" `%s` ", node.text);
	end

	return string.format("`%s`", node.text);
end

handler.Emph = function (node)
	table.insert(handler.cache.parents, 1, node.t);

	local content = table.concat(
		handler.init(node.content, nil, true),
		""
	);

	table.remove(handler.cache.parents, #handler.cache.parents);
	return handler.config.emph_style == "simple" and
		string.format("〈%s〉", content) or
		content
	;
end

handler.Image = function (node)
	local caption = table.concat(
		handler.init(node.caption, nil, true),
		""
	);

	table.insert(handler.cache.images, node);
	return string.format("!(%s)%s", caption, styles.tostring("subscript", tostring(#handler.cache.images)))
end

handler.LineBreak = function ()
	return "\n";
end

handler.Link = function (node)
	local content = table.concat(
		handler.init(node.content, nil, true),
		""
	);

	table.insert(handler.cache.links, node);
	return string.format("(%s)%s", content, styles.tostring("superscript", tostring(#handler.cache.links)))
end

handler.Math = function (node)
	if node.mathtype == "InlineMath" then
		return node.text;
	else
		--- TODO, Properly show maths
		return "";
	end
end

handler.Plain = function (node)
	local content = table.concat(handler.init(node.content), "");
	local lines = handler.wrap(content, handler.cache.wrap == false and math.maxinteger or nil);

	if lines[#lines] ~= "" then
		table.insert(lines, "");
	end
	return lines;
end

handler.Quoted = function (node)
	local text = node.text;

	if node.quotetype == "SingleQuote" then
		return string.format("'%s'", text)
	else
		return string.format('"%s"', text)
	end
end

handler.SoftBreak = function ()
	return "\n";
end

handler.Space = function ()
	return " ";
end

handler.Str = function (node)
	return styles.tostring(nil, node.text);
end

handler.Strikeout = function (node)
	table.insert(handler.cache.parents, 1, node.t);

	local content = table.concat(
		handler.init(node.content, nil, true),
		""
	);

	--- FIXME, Find way to handle mixed styles.
	table.remove(handler.cache.parents, #handler.cache.parents);
	return handler.config.strikeout_style == "simple" and string.format("/%s/", content) or content;
end

handler.Strong = function (node)
	table.insert(handler.cache.parents, 1, node.t);

	local content = table.concat(
		handler.init(node.content, nil, true),
		""
	);

	--- FIXME, Find way to handle mixed styles.
	table.remove(handler.cache.parents, #handler.cache.parents);
	return handler.config.strong_style == "simple" and string.format("⎡%s⎦", content) or content;
end

handler.Subscript = function (node)
	table.insert(handler.cache.parents, 1, node.t);

	local content = table.concat(
		handler.init(node.content, nil, true),
		""
	);

	--- FIXME, Find way to handle mixed styles.
	table.remove(handler.cache.parents, #handler.cache.parents);
	return handler.config.subscript_style == "simple" and string.format("↓[%s]", content) or content;
end

handler.Superscript = function (node)
	table.insert(handler.cache.parents, 1, node.t);

	local content = table.concat(
		handler.init(node.content, nil, true),
		""
	);

	--- FIXME, Find way to handle mixed styles.
	table.remove(handler.cache.parents, #handler.cache.parents);
	return handler.config.superscript_style == "simple" and string.format("↑[%s]", content) or content;
end


 ------------------------------------------------------------------------------------------

handler.metadata = function (metadata)
	if metadata["markdoc"] == nil then
		return;
	end

	for key, value in pairs(metadata.markdoc) do
		if key == "tags" then
			for _, entry in ipairs(value) do
				local pattern = stringify(entry[1]);
				local tags = entry[2];

				local _t = {};

				if
					type(tags) == "table" and
					#tags > 0
				then
					for _, tag in ipairs(tags) do
						table.insert(_t, stringify(tag));
					end
				elseif type(tags) == "string" then
					table.insert(_t, stringify(tags));
				end

				table.insert(
					handler.cache.tags,
					{
						pattern or "",
						_t
					}
				)
			end
		elseif key == "name" then
			handler.cache.name = stringify(value);
		elseif key == "desc" then
			handler.cache.desc = stringify(value);
		elseif key == "toc_header" then
			handler.cache.toc_header = stringify(value);
		elseif key == "toc" then
			handler.cache.toc = {};

			for _, entry in ipairs(value) do
				local content = stringify(entry[1]);
				local tag = stringify(entry[2]);

				table.insert(
					handler.cache.toc,
					{ content, tag }
				)
			end
		end
	end
end

handler.block_quote_level = function (nodes, level)
	level = level or 1;

	if not handler.cache.block_quotes[level] then
		handler.cache.block_quotes[level] = {};
	end

	for _, sub_node in ipairs(nodes or {}) do
		if sub_node.t == "BlockQuote" then
			table.insert(handler.cache.block_quotes[level], sub_node);
			handler.block_quote_level(sub_node.content, level + 1);
		elseif sub_node.t and sub_node.t then
			handler.block_quote_level(sub_node.content, level);
		elseif is_list(sub_node) then
			handler.block_quote_level(sub_node, level + 1);
		end
	end
end

handler.header = function ()
	if handler.cache.name == nil then
		return {};
	end

	local lines = {}

	local max_width = handler.config.textwidth or 78;
	local name = string.format("*%s*", handler.cache.name or "unknown");
	local desc = string.format("%s", handler.cache.desc or "");

	table.insert(
		lines,
		styles.align_text("left", name, math.floor(max_width / 2))
	);

	if
		desc and
		styles.strdisplaywidth(lines[#lines] .. desc) <= max_width
	then
		local line_width = styles.strdisplaywidth(lines[#lines]);

		if property(handler.config, { "count_conceal" }) == true then
			line_width = line_width - 2;
		end

		lines[#lines] = string.format(
			"%s%" .. (max_width - line_width) .. "s",
			lines[#lines],
			desc
		);
	elseif desc then
		table.insert(
			lines,
			string.format(
				"%" .. max_width .. "s",
				desc
			)
		);
	end

	if lines[#lines] ~= "" then
		table.insert(lines, "");
	end

	return lines;
end

handler.init = function (nodes, dest, inline)
	dest = dest or {};

	if not inline then
		handler.cache.parents = {};
	end

	for _, node in ipairs(nodes) do
		--- Returned value
		---@type string | string[]
		local val;

		if is_list(node) then
			val = handler.init(node);
		else
			if not handler[node.t] then
				goto continue;
			end

			val = handler[node.t](node);
		end

		if type(val) == "string" then
			table.insert(dest, val);
		elseif type(val) == "table" then
			for _, part in ipairs(val) do
				table.insert(dest, part);
			end
		end

	    ::continue::
	end

	return dest;
end

handler.toc = function ()
	local toc = handler.cache.toc;
	local toc_header = handler.cache.toc_header;

	local max_width = handler.config.textwidth;
	local toc_txt_width = handler.config.toc_text_width;
	local sep = handler.config.toc_separator;

	if toc_txt_width < 1 then
		toc_txt_width = math.floor(max_width * toc_txt_width);
	end

	if not toc then
		return;
	end

	local lines = {};

	if toc_header then
		for _, line in ipairs(handler.Header({ level = 2, content = { { t = "Str", text = toc_header } } })) do
			table.insert(lines, line);
		end
	end

	for _, content in ipairs(toc) do
		local text = handler.wrap(content[1], toc_txt_width, false);
		local tag  = "|" .. content[2] .. "|";

		if styles.strdisplaywidth(#text[#text] .. tag) < toc_txt_width then
			local left = toc_txt_width - styles.strdisplaywidth(text[#text] .. tag);

			text[#text] = string.format(
				"%s %s %s",
				text[#text],
				string.rep(sep or " ", left - 2),
				tag
			);
		else
			local left = toc_txt_width - styles.strdisplaywidth(text[#text]);
			local tag_left = toc_txt_width - styles.strdisplaywidth(tag);

			text[#text] = string.format(
				"%s %s",
				text[#text],
				string.rep(sep or " ", left - 1)
			);
			table.insert(
				text,
				string.format(
					"%s%s",
					string.rep(sep or " ", tag_left),
					tag
				)
			);
		end

		for _, item in ipairs(text) do
			local padding = max_width - toc_txt_width;
			local left = math.floor(padding / 2);
			local right = math.ceil(padding / 2)

			table.insert(
				lines,
				string.format(
					"%s%s%s",
					string.rep(" ", left),
					item,
					string.rep(" ", right)
				)
			);
		end
	end

	return lines;
end

handler.links = function ()
	local lines = {};
	local link_icon = property(handler.config, { "link_icon" }) or "";
	local image_icon = property(handler.config, { "image_icon" }) or "";

	if #handler.cache.links > 0 then
		table.insert(lines, "");
		table.insert(lines, "Link definitions:");
		table.insert(lines, "");
	end

	for l, link in ipairs(handler.cache.links) do
		table.insert(lines, string.format("%s%d:", link_icon, l));
		table.insert(lines, (link.target and link.target ~= "") and link.target or "<Not available>");
		table.insert(lines, "");
	end

	if #handler.cache.images > 0 then
		table.insert(lines, "");
		table.insert(lines, "Image definitions:");
		table.insert(lines, "");
	end

	for i, img in ipairs(handler.cache.images) do
		table.insert(lines, string.format("%s%d:", image_icon, i));
		table.insert(lines, (img.target and img.target ~= "") and img.target or "<Not available>");
	end

	return lines;
end

 ------------------------------------------------------------------------------------------

styles.superscript = {
	---+${class}
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

	["+"] = "⁺",
	["-"] = "⁻",
	["="] = "⁼",
	["("] = "⁽",
	[")"] = "⁾",

	["A"] = "ᵃ",
	["B"] = "ᵇ",
	["C"] = "ᶜ",
	["D"] = "ᵈ",
	["E"] = "ᵉ",
	["F"] = "ᶠ",
	["G"] = "ᵍ",
	["H"] = "ʰ",
	["I"] = "ⁱ",
	["J"] = "ʲ",
	["K"] = "ᵏ",
	["L"] = "ˡ",
	["M"] = "ᵐ",
	["N"] = "ⁿ",
	["O"] = "ᵒ",
	["P"] = "ᵖ",
	["Q"] = "ᶿ",
	["R"] = "ʳ",
	["S"] = "ˢ",
	["T"] = "ᵗ",
	["U"] = "ᵘ",
	["V"] = "ᵛ",
	["W"] = "ʷ",
	["X"] = "ˣ",
	["Y"] = "ʸ",
	["Z"] = "ᶻ",

	["a"] = "ᵃ",
	["b"] = "ᵇ",
	["c"] = "ᶜ",
	["d"] = "ᵈ",
	["e"] = "ᵉ",
	["f"] = "ᶠ",
	["g"] = "ᵍ",
	["h"] = "ʰ",
	["i"] = "ⁱ",
	["j"] = "ʲ",
	["k"] = "ᵏ",
	["l"] = "ˡ",
	["m"] = "ᵐ",
	["n"] = "ⁿ",
	["o"] = "ᵒ",
	["p"] = "ᵖ",
	["q"] = "ᶣ",
	["r"] = "ʳ",
	["s"] = "ˢ",
	["t"] = "ᵗ",
	["u"] = "ᵘ",
	["v"] = "ᵛ",
	["w"] = "ʷ",
	["x"] = "ˣ",
	["y"] = "ʸ",
	["z"] = "ᶻ",

	["alpha"] = "ᵅ",
	["beta"] = "ᵝ",
	["gamma"] = "ᵞ",
	["delta"] = "ᵟ",
	["epsilon"] = "ᵋ",
	["theta"] = "ᶿ",
	["iota"] = "ᶥ",
	["Phi"] = "ᶲ",
	["varphi"] = "ᵠ",
	["chi"] = "ᵡ",
	---_
};

styles.subscript = {
	---+${class}
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

	["+"] = "₊",
	["-"] = "₋",
	["="] = "₌",
	["("] = "₍",
	[")"] = "₎",

	["A"] = "ᴀ",
	["B"] = "ʙ",
	["C"] = "ᴄ",
	["D"] = "ᴅ",
	["E"] = "ᴇ",
	["F"] = "ғ",
	["G"] = "ɢ",
	["H"] = "ʜ",
	["I"] = "ɪ",
	["J"] = "ᴊ",
	["K"] = "ᴋ",
	["L"] = "ʟ",
	["M"] = "ᴍ",
	["N"] = "ɴ",
	["O"] = "ɪ",
	["P"] = "ᴘ",
	["Q"] = "ǫ",
	["R"] = "ʀ",
	["S"] = "s",
	["T"] = "ᴛ",
	["U"] = "ᴜ",
	["V"] = "ᴠ",
	["W"] = "ᴡ",
	["X"] = "x",
	["Y"] = "ʏ",
	["Z"] = "ᴢ",

	["a"] = "ₐ",
	["b"] = "ᵦ",
	["c"] = "𝒸",
	["d"] = "𝒹",
	["e"] = "ₑ",
	["f"] = "𝒻",
	["g"] = "𝓰",
	["h"] = "ₕ",
	["i"] = "ᵢ",
	["j"] = "ⱼ",
	["k"] = "ₖ",
	["l"] = "ₗ",
	["m"] = "ₘ",
	["n"] = "ₙ",
	["o"] = "ₒ",
	["p"] = "ₚ",
	["q"] = "ℴ",
	["r"] = "ᵣ",
	["s"] = "ₛ",
	["t"] = "ₜ",
	["u"] = "ᵤ",
	["v"] = "ᵥ",
	["w"] = "𝓌",
	["x"] = "ₓ",
	["y"] = "ᵧ",
	["z"] = "𝓏",

	["beta"] = "ᵦ",
	["gamma"] = "ᵧ",
	["rho"] = "ᵨ",
	["epsilon"] = "ᵩ",
	["chi"] = "ᵪ",
	---_
};

styles.emph = {
	---+${lua}
	["A"] = "𝐴",
	["B"] = "𝐵",
	["C"] = "𝐶",
	["D"] = "𝐷",
	["E"] = "𝐸",
	["F"] = "𝐹",
	["G"] = "𝐺",
	["H"] = "𝐻",
	["I"] = "𝐼",
	["J"] = "𝐽",
	["K"] = "𝐾",
	["L"] = "𝐿",
	["M"] = "𝑀",
	["N"] = "𝑁",
	["O"] = "𝑂",
	["P"] = "𝑃",
	["Q"] = "𝑄",
	["R"] = "𝑅",
	["S"] = "𝑆",
	["T"] = "𝑇",
	["U"] = "𝑈",
	["V"] = "𝑉",
	["W"] = "𝑊",
	["X"] = "𝑋",
	["Y"] = "𝑌",
	["Z"] = "𝑍",

	["a"] = "𝑎",
	["b"] = "𝑏",
	["c"] = "𝑐",
	["d"] = "𝑑",
	["e"] = "𝑒",
	["f"] = "𝑓",
	["g"] = "𝑔",
	["h"] = "𝒉",
	["i"] = "𝑖",
	["j"] = "𝑗",
	["k"] = "𝑘",
	["l"] = "𝑙",
	["m"] = "𝑚",
	["n"] = "𝑛",
	["o"] = "𝑜",
	["p"] = "𝑝",
	["q"] = "𝑞",
	["r"] = "𝑟",
	["s"] = "𝑠",
	["t"] = "𝑡",
	["u"] = "𝑢",
	["v"] = "𝑣",
	["w"] = "𝑤",
	["x"] = "𝑥",
	["y"] = "𝑦",
	["z"] = "𝑧",
	---_
};

styles.strong = {
	---+${lua}
	["A"] = "𝐀",
	["B"] = "𝐁",
	["C"] = "𝐂",
	["D"] = "𝐃",
	["E"] = "𝐄",
	["F"] = "𝐅",
	["G"] = "𝐆",
	["H"] = "𝐇",
	["I"] = "𝐈",
	["J"] = "𝐉",
	["K"] = "𝐊",
	["L"] = "𝐋",
	["M"] = "𝐌",
	["N"] = "𝐍",
	["O"] = "𝐎",
	["P"] = "𝐏",
	["Q"] = "𝐐",
	["R"] = "𝐑",
	["S"] = "𝐒",
	["T"] = "𝐓",
	["U"] = "𝐔",
	["V"] = "𝐕",
	["W"] = "𝐖",
	["X"] = "𝐗",
	["Y"] = "𝐘",
	["Z"] = "𝐙",

	["a"] = "𝐚",
	["b"] = "𝐛",
	["c"] = "𝐜",
	["d"] = "𝐝",
	["e"] = "𝐞",
	["f"] = "𝐟",
	["g"] = "𝐠",
	["h"] = "𝐡",
	["i"] = "𝐢",
	["j"] = "𝐣",
	["k"] = "𝐤",
	["l"] = "𝐥",
	["m"] = "𝐦",
	["n"] = "𝐧",
	["o"] = "𝐨",
	["p"] = "𝐩",
	["q"] = "𝐪",
	["r"] = "𝐫",
	["s"] = "𝐬",
	["t"] = "𝐭",
	["u"] = "𝐮",
	["v"] = "𝐯",
	["w"] = "𝐰",
	["x"] = "𝐱",
	["y"] = "𝐲",
	["z"] = "𝐳",

	["0"] = "𝟎",
	["1"] = "𝟏",
	["2"] = "𝟐",
	["3"] = "𝟑",
	["4"] = "𝟒",
	["5"] = "𝟓",
	["6"] = "𝟔",
	["7"] = "𝟕",
	["8"] = "𝟖",
	["9"] = "𝟗",
	---_
};

styles.combined = {
	---+${lua}
	["A"] = "𝑨",
	["B"] = "𝑩",
	["C"] = "𝑪",
	["D"] = "𝑫",
	["E"] = "𝑬",
	["F"] = "𝑭",
	["G"] = "𝑮",
	["H"] = "𝑯",
	["I"] = "𝑰",
	["J"] = "𝑱",
	["K"] = "𝑲",
	["L"] = "𝑳",
	["M"] = "𝑴",
	["N"] = "𝑵",
	["O"] = "𝑶",
	["P"] = "𝑷",
	["Q"] = "𝑸",
	["R"] = "𝑹",
	["S"] = "𝑺",
	["T"] = "𝑻",
	["U"] = "𝑼",
	["V"] = "𝑽",
	["W"] = "𝑾",
	["X"] = "𝑿",
	["Y"] = "𝒀",
	["Z"] = "𝒁",

	["a"] = "𝒂",
	["b"] = "𝒃",
	["c"] = "𝒄",
	["d"] = "𝒅",
	["e"] = "𝒆",
	["f"] = "𝒇",
	["g"] = "𝒈",
	["h"] = "𝒉",
	["i"] = "𝒊",
	["j"] = "𝒋",
	["k"] = "𝒌",
	["l"] = "𝒍",
	["m"] = "𝒎",
	["n"] = "𝒏",
	["o"] = "𝒐",
	["p"] = "𝒑",
	["q"] = "𝒒",
	["r"] = "𝒓",
	["s"] = "𝒔",
	["t"] = "𝒕",
	["u"] = "𝒖",
	["v"] = "𝒗",
	["w"] = "𝒘",
	["x"] = "𝒙",
	["y"] = "𝒚",
	["z"] = "𝒛",
	---_
}

styles.strkeout = {}

styles.strdisplaywidth = function (text)
    return utf8.len(text)
end

styles.tostring = function (style, text)
	if style and styles[style] then
		style = style;
	elseif #handler.cache.parents == 0 then
		style = nil;
		return text;
	elseif
		list_contains(handler.cache.parents, "Subscript") and
		handler.config.subscript_style == "fancy"
	then
		style = "subscript";
	elseif
		list_contains(handler.cache.parents, "Superscript") and
		handler.config.superscript_style == "fancy"
	then
		style = "superscript";
	elseif
		(
			list_contains(handler.cache.parents, "Emph") and
			handler.config.emph_style == "fancy"
		) and
		(
			list_contains(handler.cache.parents, "Strong") and
			handler.config.strong_style == "fancy"
		)
	then
		style = "combined";
	elseif
		list_contains(handler.cache.parents, "Emph") and
		handler.config.emph_style == "fancy"
	then
		style = "emph";
	elseif
		list_contains(handler.cache.parents, "Strong") and
		handler.config.strong_style == "fancy"
	then
		style = "strong";
	else
		style = nil;
	end

	local striked, underlined = list_contains(handler.cache.parents, "Striked"), list_contains(handler.cache.parents, "Underline");

	local font = style == nil and {} or styles[style];
	local out = "";

	for char in string.gmatch(text, ".") do
		if font[char] then
			out = out .. font[char];
		else
			out = out .. char;
		end

		--- FIXME, Experimental feature
		if striked then
			out = out .. "̶";
		elseif underlined then
			out = out .. "̲";
		end
	end

	return out;
end

styles.align_text = function (alignment, text, width, pad)
	local str_len = styles.strdisplaywidth(text);

	if alignment == "left" then
		local after = width - str_len;

		if pad == false then
			return text .. string.rep(" ", after);
		else
			return " " .. text .. string.rep(" ", after - 1);
		end
	elseif alignment == "right" then
		local before = width - str_len;

		if pad == false then
			return string.rep(" ", before) .. text;
		else
			return string.rep(" ", before - 1) .. text .. " ";
		end
	else
		local before = math.floor((width - str_len) / 2);
		local after  = math.ceil((width - str_len) / 2);

		return string.rep(" ", before) .. text .. string.rep(" ", after);
	end
end

 ------------------------------------------------------------------------------------------

--- Creates a document.
---@param document table
---@return string
function Writer(document)
	handler.metadata(document.meta);
	handler.block_quote_level(document.blocks);

	local lines = {};

	for _, header_line in ipairs(handler.header() or {}) do
		table.insert(lines, header_line);
	end

	for _, header_line in ipairs(handler.toc() or {}) do
		table.insert(lines, header_line);
	end

	for _, line in ipairs(handler.init(document.blocks) or {}) do
		table.insert(lines, line);
	end

	for _, link in ipairs(handler.links() or {}) do
		table.insert(lines, link);
	end

	return table.concat(lines, "\n");
end


