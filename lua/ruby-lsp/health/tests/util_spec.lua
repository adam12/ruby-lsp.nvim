local util = require("ruby-lsp.health.util")
local stub = require("luassert.stub")

describe("health utilities", function()
	describe("lualib_installed", function()
		it("returns true if module exists", function()
			package.preload["dummy_module"] = function()
				return {}
			end
			local result = util.lualib_installed("dummy_module")
			assert.is_true(result)
		end)

		it("returns false if module doesn't exist", function()
			local result = util.lualib_installed("missing_module")
			assert.is_false(result)
		end)
	end)

	describe("binary_info", function()
		local popen_stub

		before_each(function()
			stub(vim.fn, "executable")
			popen_stub = stub(io, "popen")
		end)

		after_each(function()
			vim.fn.executable:revert()
			popen_stub:revert()
		end)

		it("returns true, version, location if binary exists", function()
			vim.fn.executable.returns(1)
			local fake_output = "tool v1.2.3\n/test/location/tool\n"
			local handle = {
				read = function()
					return fake_output
				end,
				close = function() end,
			}
			popen_stub.returns(handle)

			local ok, version, location = util.binary_info("somebin")
			assert.is_true(ok)
			assert.equals("tool v1.2.3", version)
			assert.equals("/test/location/tool", location)
		end)

		it("returns false if binary doesn't exist", function()
			vim.fn.executable.returns(1)
			local ok = util.binary_info("missingbin")
			assert.is_false(ok)
		end)
	end)

	describe("present_linters", function()
		before_each(function()
			stub(vim.fn, "filereadable")
		end)
		it("returns linters that exist", function()
			vim.fn.filereadable.returns(1)
			local linters = {
				{ name = "testlint", config = ".testlint.yml" },
			}
			local present = util.present_linters(linters)
			for _, linter in ipairs(present) do
				assert.equals("testlint", linter.name)
				assert.equals(".testlint.yml", linter.config)
			end
		end)
	end)
end)
