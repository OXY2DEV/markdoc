local yaml = {};
local spec = require("nvim-markdoc.spec");

--- Gets text from a YAML node(removes ', ")
---@param node userdata
---@param buffer integer
---@return string
local function get_node_text(node, buffer)
	---|fS

	local text = vim.treesitter.get_node_text(node, buffer)
	text = text:gsub("^['\"]", "");
	text = text:gsub("['\"]$", "");

	return text;

	---|fE
end

--- Turns string into other data types.
---@param str string
---@return number | boolean | string
local function toval(str)
	---|fS

	if tonumber(str) then
		return str;
	elseif str == "true" or str == "false" then
		return str == "true";
	else
		return str;
	end

	---|fE
end

yaml.__block_quotes = function (buffer, node)
	---|fS

	local _value = node:field("value")[1];
	if not _value or not _value:child(0) or not _value:child(0) then return end

	local value = _value:child(0);

	local function block_quote_config (opt_node)
		local _o = {};

		for sub_option in opt_node:iter_children() do
			local k, v = sub_option:field("key")[1], sub_option:field("value")[1];

			if k and v then
				_o[get_node_text(k, buffer)] = toval(get_node_text(v, buffer));
			end
		end

		return _o;
	end

	local _config = {};

	for option in value:iter_children() do
		local opt_name = option:field("key")[1];
		local opt_val  = option:field("value")[1];

		if opt_name and opt_val then
			_config[get_node_text(opt_name, buffer)] = block_quote_config(opt_val:child(0));
		end
	end

	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		block_quotes = _config
	});

	---|fE
end

yaml.__fold_refs = function (buffer, node)
	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		fold_refs = toval(get_node_text(node:field("value")[1], buffer))
	});
end

yaml.__fold_markers = function (buffer, node)
	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		fold_markers = toval(get_node_text(node:field("value")[1], buffer))
	});
end

yaml.__tags = function (buffer, node)
	---|fS

	local _value = node:field("value")[1];
	if not _value or not _value:child(0) or not _value:child(0) then return end

	local value = _value:child(0);
	local _config = {};

	for option in value:iter_children() do
		local opt_name = option:field("key")[1];
		local opt_val  = option:field("value")[1];

		if opt_name and opt_val then
			local flow_type = opt_val:child(0):type();

			if flow_type == "flow_sequence" then
				local _tags = {};

				for entry in opt_val:child(0):iter_children() do
					if entry:type() == "flow_node" then
						table.insert(_tags, get_node_text(entry, buffer))
					end
				end

				_config[get_node_text(opt_name, buffer)] = _tags;
			else
				_config[get_node_text(opt_name, buffer)] = { get_node_text(opt_val:child(0), buffer) };
			end
		end
	end

	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		tags = _config
	});

	---|fE
end

yaml.__table = function (buffer, node)
	---|fS

	local _value = node:field("value")[1];
	if not _value or not _value:child(0) or not _value:child(0) then return end

	local value = _value:child(0);
	local _config = {};

	for option in value:iter_children() do
		local opt_name = option:field("key")[1];
		local opt_val  = option:field("value")[1];

		if opt_name and opt_val then
			if get_node_text(opt_name, buffer) ~= "col_minwidth" then
				local _tags = {};

				for entry in opt_val:child(0):iter_children() do
					if entry:type() == "flow_node" then
						table.insert(_tags, get_node_text(entry, buffer))
					end
				end

				_config[get_node_text(opt_name, buffer)] = _tags;
			else
				_config[get_node_text(opt_name, buffer)] = tonumber(get_node_text(opt_val:child(0), buffer));
			end
		end
	end

	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		table = _config
	});

	---|fE
end

yaml.__textwidth = function (buffer, node)
	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		textwidth = toval(get_node_text(node:field("value")[1], buffer))
	});
end

yaml.__title = function (buffer, node)
	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		title = toval(get_node_text(node:field("value")[1], buffer))
	});
end

yaml.__title_tag = function (buffer, node)
	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		title_tag = toval(get_node_text(node:field("value")[1], buffer))
	});
end

yaml.__toc_title = function (buffer, node)
	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		toc_tag = toval(get_node_text(node:field("value")[1], buffer))
	});
end

yaml.__toc = function (buffer, node)
	---|fS

	local _value = node:field("value")[1];
	if not _value or not _value:child(0) or not _value:child(0) then return end

	local value = _value:child(0);
	local _config = {};

	for option in value:iter_children() do
		local opt_name = option:field("key")[1];
		local opt_val  = option:field("value")[1];

		if opt_name and opt_val then
			_config[get_node_text(opt_name, buffer)] = get_node_text(opt_val:child(0), buffer);
		end
	end

	spec.config = vim.tbl_deep_extend("force", spec.config or spec.default, {
		toc = _config
	});

	---|fE
end

------------------------------------------------------------------------------

yaml.markdoc = function (buffer, node)
	---|fS

	local value = node:field("value")[1];

	if not value then
		return;
	end

	for option in value:child(0):iter_children() do
		local name = option:field("key")[1];

		if not name then
			goto continue;
		end

		pcall(yaml["__" .. get_node_text(name, buffer)], buffer, option);

	    ::continue::
	end

	---|fE
end

yaml.parse = function (buffer, TSTree)
	local scanned_queries = vim.treesitter.query.parse("yaml", [[
		(block_mapping_pair
			key: (flow_node) @property.key
			(#match? @property.key "^markdoc$")) @markdoc
	]]);

	for capture_id, capture_node, _, _ in scanned_queries:iter_captures(TSTree:root(), buffer, from, to) do
		local capture_name = scanned_queries.captures[capture_id];

		if capture_name == "markdoc" then
			yaml.markdoc(buffer, capture_node);
		end
	end
end

return yaml;
