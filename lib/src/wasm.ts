import { WASI, wasmEnv } from "@jsage/wasi";
import nodeBindings from "@jsage/wasi/dist/bindings/node";

import { reuseInFlight } from "async-await-utils/hof";
import { readFile as readFile0 } from "fs";
import { promisify } from "util";
import { dirname, join } from "path";
import callsite from "callsite";
import fs from "fs";

const readFile = promisify(readFile0);

const textDecoder = new TextDecoder();
function recvString(wasm, ptr, len) {
  const slice = wasm.exports.memory.buffer.slice(ptr, ptr + len);
  return textDecoder.decode(slice);
}

interface Options {
  noWasi?: boolean; // if true, include wasi
  env?: object; // functions to include in the environment
  dir?: string | null; // WASI pre-opened directory; default is to preopen /, i.e., full filesystem; explicitly set as null to sandbox.
  traceSyscalls?: boolean;
  time?: boolean;
  init?: (wasm: WasmInstance) => void | Promise<void>; // initialization function that gets called when module first loaded.
}

const cache: { [name: string]: any } = {};

type WasmImportFunction = (
  name: string,
  options?: Options
) => Promise<WasmInstance>;

async function doWasmImport(
  name: string,
  options: Options = {}
): Promise<WasmInstance> {
  if (cache[name] != null) {
    return cache[name];
  }
  const t = new Date().valueOf();
  if (!name.startsWith("/")) {
    throw Error(`name must be an absolute path -- ${name}`);
  }
  const pathToWasm = `${name}${name.endsWith(".wasm") ? "" : ".wasm"}`;

  wasmEnv.reportError = (ptr, len: number) => {
    // @ts-ignore
    const slice = result.instance.exports.memory.buffer.slice(ptr, ptr + len);
    const textDecoder = new TextDecoder();
    throw Error(textDecoder.decode(slice));
  };

  const wasmOpts: any = { env: { ...wasmEnv, ...options.env } };

  let wasm;

  if (wasmOpts.env.wasmSendString == null) {
    wasmOpts.env.wasmSendString = (ptr: number, len: number) => {
      wasm.result = recvString(wasm, ptr, len);
    };
  }

  let wasi: any = undefined;
  if (!options?.noWasi) {
    const opts: any = {
      args: process.argv,
      env: process.env,
      traceSyscalls: options.traceSyscalls,
    };
    if (options.dir === null) {
      // sandbox -- don't give any fs access
    } else {
      opts.bindings = {
        ...nodeBindings,
        fs,
      };
      if (options.dir !== undefined) {
        // something explicit
        opts.preopenDirectories = { [options.dir]: options.dir };
      } else {
        // just give full access; security of fs access isn't
        // really relevant for us at this point
        opts.preopenDirectories = { "/": "/" };
      }
    }
    wasi = new WASI(opts);
    wasmOpts.wasi_snapshot_preview1 = wasi.wasiImport;
  }

  //console.log(`reading ${pathToWasm}`);
  const source = await readFile(pathToWasm);
  const typedArray = new Uint8Array(source);
  const result = await WebAssembly.instantiate(typedArray, wasmOpts);
  if (wasi != null) {
    wasi.start(result.instance);
  }
  if (result.instance.exports.__wasm_call_ctors != null) {
    // We also **MUST** explicitly call the WASM constructors. This is
    // a library function that is part of the zig libc code.  We have
    // to call this because the wasm file is built using build-lib, so
    // there is no main that does this.  This call does things like
    // setup the filesystem mapping.    Yes, it took me **days**
    // to figure this out, including reading a lot of assembly code. :shrug:
    (result.instance.exports.__wasm_call_ctors as CallableFunction)();
  }

  wasm = new WasmInstance(result.instance.exports);
  if (options.init != null) {
    await options.init(wasm);
  }

  cache[name] = wasm;

  if (options.time) {
    console.log(`imported ${name} in ${new Date().valueOf() - t}ms`);
  }

  return wasm;
}

const wasmImportDebounced: WasmImportFunction = reuseInFlight(doWasmImport, {
  createKey: (args) => args[0],
});

export default async function wasmImport(
  name: string,
  options: Options = {}
): Promise<WasmInstance> {
  if (!name.startsWith("/")) {
    // it's critical to make this canonical BEFORE calling the debounced function,
    // or randomly otherwise end up with same module imported twice, which will
    // result in a "hellish nightmare" of subtle bugs.
    name = join(dirname(callsite()[1]?.getFileName() ?? ""), name);
  }
  return await wasmImportDebounced(name, options);
}

const encoder = new TextEncoder();

export class WasmInstance {
  result: any = undefined;
  exports: any;
  constructor(exports) {
    this.exports = exports;
  }

  private stringToCharStar(str: string): number {
    // Caller MUST free the returned char* from stringToU8 using wasm.free!
    const strAsArray = encoder.encode(str);
    const len = strAsArray.length + 1;
    const ptr = this.exports.malloc(len);
    const array = new Int8Array(this.exports.memory.buffer, ptr, len);
    array.set(strAsArray);
    array[len - 1] = 0;
    return ptr;
  }

  public callWithString(name: string, str: string, ...args): any {
    this.result = undefined;
    const ptr = this.stringToCharStar(str);
    let r;
    try {
      const f = this.exports[name];
      if (f == null) {
        throw Error(`no function ${name} defined in wasm module`);
      }
      // @ts-ignore
      r = f(ptr, ...args);
    } finally {
      // @ts-ignore
      this.exports.free(ptr);
    }
    return this.result ?? r;
  }
}

export function run(filename: string) {
  wasmImport(filename);
}
