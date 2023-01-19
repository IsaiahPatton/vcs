module main

import vweb
import os
import szip
import encoding.base64

const (
	port = 80
)

struct App {
	vweb.Context
}

fn main() {
	mut app := &App{}

	app.mount_static_folder_at(os.resource_abs_path('./public'), '/')

	vweb.run(app, port)
}

pub fn (mut app App) init_once() {
	app.handle_static('./public', true)
}

['/wasm'; post]
pub fn (mut app App) index() vweb.Result {
	dat := app.req.data

	dump(dat)
	j := new_compilation_job(dat) or { return app.text(err.msg) }
	j.compile()
	wasm := j.encode() or { return app.text(err.msg) }
	j.cleanup() or { return app.text(err.msg) }
	app.add_header('access-control-allow-origin', '*')
	return app.text(wasm)
}

pub fn extract_zip_to_dir(file string, dir string) ?bool {
	mut zip := szip.open(file, .best_speed, .read_only) or { panic(err) }
	total := zip.total() or { return false }
	for i in 0 .. total {
		zip.open_entry_by_index(i) or {}
		do_to := os.real_path(os.join_path(dir, zip.name()))

		os.mkdir_all(os.dir(do_to)) or { println(err) }
		os.write_file(do_to, '') or {}

		if os.is_dir(do_to) {
			continue
		}

		zip.extract_entry(do_to) or {
		}
	}
	return true
}
