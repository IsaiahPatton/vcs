module main

import os
import rand
import encoding.base64

struct CompilationJob {
	id        string
	path      string
	code_path string
	code      string
}

fn temp_path(id string) string {
	return os.join_path(os.temp_dir(), id)
}

fn new_compilation_job(code string) ?CompilationJob {
	id := rand.string(18)
	j := CompilationJob{
		id: id
		path: temp_path(id)
		code: code
	}

	os.mkdir(j.path) or { return error('failed to create temp dir') }
	os.write_file(j.get_ext_path('v'), j.code) or { return error('failed to write code to temp') }

	lines := os.read_lines(j.get_ext_path('v')) or { ['err'] }

	dump(lines)
	return j
}

fn (j CompilationJob) get_ext_path(ext string) string {
	return os.join_path(j.path, '${j.id}.${ext}')
}

fn (j CompilationJob) get_ext_path1(ext string) string {
	return os.join_path(j.path, '${j.id}_.${ext}')
}

fn (j CompilationJob) compile() {
	out0 := j.get_ext_path('c')
	out1 := j.get_ext_path1('c')
	v_res := os.execute('v -d emscripten -d no_emoji -gc none -os wasm32-emscripten -o ${out1} ${j.get_ext_path('v')}')
	println(v_res.str())

	b := os.execute("cat ${out1} | sed 's/waitpid(p->pid, &cstatus, 0);/-1;/g' | sed 's/waitpid(p->pid, &cstatus, WNOHANG);/-1;/g' | sed 's/wait(0);/-1;/g' &> ${out0}")
	dump(b.exit_code)
	// c := os.execute("emcc -fPIC -Wimplicit-function-declaration -w  thirdparty/stb_image/stbi.c -I/usr/include/gc/   -Ithirdparty/stb_image -Ithirdparty/fontstash -Ithirdparty/sokol -Ithirdparty/sokol/util    -DSOKOL_GLES2 -DSOKOL_NO_ENTRY   -DNDEBUG -O3   -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s ALLOW_MEMORY_GROWTH -s MODULARIZE -s ASSERTIONS=1 emscripten.c -o app.js --embed-file C:/v/examples/gg/myfont.ttf@/myfont.ttf")
	c := os.execute('emcc -fPIC -Wimplicit-function-declaration -w  v/thirdparty/stb_image/stbi.c -I/usr/include/gc/   -Iv/thirdparty/stb_image -Iv/thirdparty/fontstash -Iv/thirdparty/sokol -Iv/thirdparty/sokol/util    -DSOKOL_GLES2 -DSOKOL_NO_ENTRY   -DNDEBUG -O3   -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s ALLOW_MEMORY_GROWTH -s MODULARIZE -s ASSERTIONS=1 ${out0} -o ${j.get_ext_path('js')}')
	dump(c.str())
	/*
	clang_res := os.exec('./wasi-sdk-12.0/bin/clang -w -O3 -D__linux__ \
	-target wasm32-unknown-wasi \
	--sysroot "./wasi-sdk-12.0/share/wasi-sysroot" \
	-D_WASI_EMULATED_SIGNAL \
	-lwasi-emulated-signal \
	-Iinclude \
	-Wl,--allow-undefined \
	-o ${j.get_ext_path('wasm')} \
	${j.get_ext_path('c')} placeholders.c') or { panic(err) }
	println(clang_res.str())*/
}

fn (j CompilationJob) encode() ?string {
	bytes0 := os.read_bytes(j.get_ext_path('wasm')) or { return error('failed to read wasm') }
	bytes1 := os.read_bytes(j.get_ext_path('js')) or { return error('failed to read js') }
	return base64.encode(bytes0) + ' ' + base64.encode(bytes1)
}

fn (j CompilationJob) cleanup() ? {
	os.rmdir_all(j.path) or { return error('failed to remove temp dir') }
}
