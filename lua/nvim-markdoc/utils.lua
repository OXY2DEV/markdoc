local utils = {};

utils.scratch_buffer = nil;

utils.replace = function (root, root_range, child, child_range)
	local _output = root;

	if not utils.scratch_buffer or not vim.api.nvim_buf_is_valid(utils.scratch_buffer) == false then
		utils.scratch_buffer = vim.api.nvim_create_buf(false, true);
	end

	pcall(function ()
		vim.api.nvim_buf_set_lines(utils.scratch_buffer, 0, -1, false, root);
		local normalized_range = {
			child_range[1] - root_range[1],
			child_range[2] - root_range[2],
			child_range[3] - root_range[1],
			child_range[4] - root_range[2],
		};

		vim.api.nvim_buf_set_text(utils.scratch_buffer, normalized_range[1], normalized_range[2], normalized_range[3], normalized_range[4], child);
		_output = vim.api.nvim_buf_get_lines(utils.scratch_buffer, 0, -1, false);
	end);

	return _output;
end

return utils;
