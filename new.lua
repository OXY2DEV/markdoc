--- Generic markdown to Vimdoc transformer.
local markdoc = {};
local insp = require("inspect");

--- Turns other data types to string.
---@param data any
---@return string
local function str(data)
	local pandoc = require("pandoc");

	if type(data) ~= "table" then
		return tostring(data);
	else
		return pandoc.utils.stringify(data);
	end
end

local function wrap(text, width)
	width = width or markdoc.config.width;
	local _output = "";
	local line_length = 0;

	for token in string.gmatch(text, "%S+") do
		local token_length = 0;
		_output = _output .. "token";
	end

	return _output;
end








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







markdoc.Header = function (node)
	local function get_tags(text)
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
	end

	local txt = markdoc.treverse(node.content);
	local tags = get_tags(txt);

	if node.level == 1 then
		local _o = string.rep("=", markdoc.config.width);
	end

	return txt;
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

	for option, value in pairs(metadata.markdoc) do
		if option == "tags" then
			--- Structure.
			--- tags = {
			---	    ["^.nvim"] = "Hi",
			---	    ["^.txt"] = { "Hello", "Bye" },
			--- }
			local tags =  {};

			for k, v in pairs(value) do
				tags[k] = str(v);
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
markdoc.treverse = function (parent)
	---|fS

	local _output = "";

	for _, item in ipairs(parent) do
		if is_list(item) then
			_output = _output .. markdoc.treverse(item);
		elseif markdoc[item.t] then
			local can_call, val = pcall(markdoc[item.t], item, _output);

			if can_call then
				_output = _output .. val;
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
	markdoc.treverse(document.blocks)

	return "";
end
