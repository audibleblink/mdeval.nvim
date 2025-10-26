if vim.g.mdeval_loaded then
  return
end

vim.api.nvim_create_user_command("MdEval", function(_)
  require("mdeval").eval_code_block()
end, {})

vim.api.nvim_create_user_command("MdEvalClean", function(_)
  require("mdeval").eval_clean_results()
end, {})

vim.g.mdeval_loaded = 1
