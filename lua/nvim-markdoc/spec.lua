local spec = {};

---@type markdoc.config
spec.default = {
	tags = {},

	textwidth = 78,
	tabstop = 4,

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

---@type markdoc.config
spec.config = vim.deepcopy(spec.default);

spec.block_quote_config = function (top)
	local callout = string.match(top, ">%s*%[!([^%]]+)%]")
	local title = string.match(top, ">%s*%[!([^%]]+)%][ \t]+([^\n]+)\n?$")
	local block_quotes = spec.config.block_quotes

	local default = block_quotes.default;

	if not callout then
		return block_quotes.default;
	elseif title then
		default.title = title;
	end

	local keys = vim.tbl_keys(block_quotes);
	table.sort(keys);

	for _, key in ipairs(keys) do
		if key ~= "default" and string.match(string.lower(callout), string.lower(key)) then
			return vim.tbl_extend("force", default, block_quotes[key]);
		end
	end

	return default
end

return spec;
