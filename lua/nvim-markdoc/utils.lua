local utils = {};

utils.scratch_buffer = nil;

utils.replace = function (root, root_range, child, child_range)
	local _output = root;

	if (root_range[3] - root_range[1]) == #root then
		table.insert(_output, "");
	end

	if not utils.scratch_buffer or not vim.api.nvim_buf_is_valid(utils.scratch_buffer) == false then
		utils.scratch_buffer = vim.api.nvim_create_buf(false, true);
	end

	local _, err = pcall(function ()
		vim.api.nvim_buf_set_lines(utils.scratch_buffer, 0, -1, false, root);
		local normalized_range = {
			child_range[2] - root_range[2],
		};

		normalized_range[1] = child_range[1] - root_range[1];
		normalized_range[3] = child_range[3] - root_range[1];

		if root_range[2] ~= 0 and normalized_range[1] == 0 then
			--- Child node doesn't start on column 0 and exists
			--- on the first line.
			normalized_range[2] = child_range[2] - root_range[2];
		else
			normalized_range[2] = child_range[2];
		end

		if root_range[4] ~= 0 and normalized_range[3] == 0 then
			--- Child node doesn't start on column 0 and exists
			--- on the first line.
			normalized_range[4] = child_range[4] - root_range[2];
		else
			normalized_range[4] = child_range[4];
		end

		vim.api.nvim_buf_set_text(utils.scratch_buffer, normalized_range[1], normalized_range[2], normalized_range[3], normalized_range[4], child);
		_output = vim.api.nvim_buf_get_lines(utils.scratch_buffer, 0, -1, false);
	end);

	return _output;
end

utils.spaces_above = function (node)
	if not node:prev_sibling() then
		return 0;
	end

	local row_start = node:range();
	local _, _, b_row_end = node:prev_sibling():range();

	return row_start - b_row_end;
end

return utils;
