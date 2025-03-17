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
	}
};

markdoc.state = {};



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

local function wrap(text, width)
	---|fS

	width = width or markdoc.config.width;
	local _output = "";
	local line_length = 0;

	for token in string.gmatch(text, "%S+") do
		---@type integer Token length.
		local token_length = utf8.len(token) or 0;

		if token_length >= width then
			local times = (token_length // width) + 1;

			for i = 1, times do
				local start = utf8.offset(token, (i - 1) * width);
				local till = utf8.offset(token, i * width);

				_output = _output .. "\n" .. string.sub(token, start, till);
			end
		elseif (line_length + token_length) >= width then
			line_length = token_length;
			_output = _output .. "\n" .. token;
		elseif _output == "" then
			line_length = line_length + token_length;
			_output = _output .. token;
		else
			line_length = line_length + 1 + token_length;
			_output = _output .. " " .. token;
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





markdoc.Header = function (node)
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

	local function tag_lines(tags, width)
		---|fS

		local _output = {};
		local line_length = 0;

		for _, tag in ipairs(tags) do
			local _tag = string.format(" *%s*", tag);
			local tag_length = utf8.len(_tag);

			if tag_length > width then
				goto continue;
			end

			if #_output == 0 or tag_length == width then
				table.insert(_output, _tag);
				line_length = tag_length;
			elseif (line_length + tag_length) > width then
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

	local txt = markdoc.treverse(node.content, " ");
	local tags = get_tags(txt);

	if node.level == 1 or node.level == 2 then
		---|fS

		local _o = string.rep(node.level == 1 and "=" or "-", markdoc.config.width) .. "\n";

		if #tags > 0 then
			local L = math.ceil((markdoc.config.width - 2) / 2);
			local R = math.floor((markdoc.config.width - 2) / 2);

			local tmp = wrap(txt, L);
			local txt_l = split(tmp, "\n");
			local tag_l = tag_lines(tags, R);

			local lines = {};

			for i = 1, math.max(#txt_l, #tag_l) do
				if txt_l[i] and tag_l[i] then
					table.insert(lines, align("l", txt_l[i], L) .. "  " .. align("r", tag_l[i], R));
				elseif tag_l[i] then
					table.insert(lines, align("r", tag_l[i], markdoc.config.width));
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

		local tmp = wrap(txt, markdoc.config.width - 3);
		local _o = tmp .. " ~\n";

		if #tags > 0 then
			local R = math.floor((markdoc.config.width - 2) / 2);
			local tag_l = tag_lines(tags, R);

			local lines = {};

			for i = 1, #tag_l do
				table.insert(lines, align("r", tag_l[i], markdoc.config.width));
			end

			_o = _o .. table.concat(lines, "\n");
		end

		return _o;

		---|fE
	else
		---|fS

		local filtered = string.upper(filter(txt, "[a-zA-Z%d%s%._%-]"));
		local tmp = wrap(filtered, markdoc.config.width - 3);
		local _o = tmp .. " ~\n";

		if #tags > 0 then
			local R = math.floor((markdoc.config.width - 2) / 2);
			local tag_l = tag_lines(tags, R);

			local lines = {};

			for i = 1, #tag_l do
				table.insert(lines, align("r", tag_l[i], markdoc.config.width));
			end

			_o = _o .. table.concat(lines, "\n");
		end

		return _o;

		---|fE
	end
end

markdoc.Plain = function (node)
	return str(node);
end

markdoc.Str = function (node)
	return node.text;
end








--- Turns metadata to configuration table.
markdoc.metadata_to_config = function (metadata)
	---|fS

	if not metadata or not metadata.markdoc then
		--- Markdoc configuration not found!
		return;
	end

	for option, value in pairs(metadata.markdoc[1]) do
		if option == "tags" then
			--- Structure.
			--- tags = {
			---	    ["^.nvim"] = "Hi",
			---	    ["^.txt"] = { "Hello", "Bye" },
			--- }
			local tags =  {};

			for k, v in pairs(value[1]) do
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
		elseif option == "tables" then
			markdoc.config.tables = value;
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
markdoc.treverse = function (parent, between)
	---|fS

	between = between or "";
	local _output = "";

	for _, item in ipairs(parent) do
		if is_list(item) then
			_output = _output .. markdoc.treverse(item, between);
		elseif markdoc[item.t] then
			local can_call, val = pcall(markdoc[item.t], item, _output);

			if can_call then
				_output = _output .. (_output ~= "" and between or "") .. val;
			else
				-- print(val)
			end
		end
	end

	return _output;

	---|fE
end

--- Writer for markdoc.
---@param document table
---@return string
function Writer (document)
	markdoc.metadata_to_config(document.meta);
	local converted = markdoc.treverse(document.blocks)

	print(converted);
	return converted;
end
