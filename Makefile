.PHONY: test

test:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c 'PlenaryBustedDirectory spec/ { minimal_init = "./scripts/minimal_init.vim" }'
