vim.api.nvim_create_user_command("MK", function ()
	require("nvim-markdoc").init();
end, {})
