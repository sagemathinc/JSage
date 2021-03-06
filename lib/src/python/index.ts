import wasmImport, { WasmInstance } from "../wasm";

export let wasm: WasmInstance | undefined = undefined;

export function exec(str: string): void {
  if (wasm == null) throw Error("call init");
  wasm.callWithString("exec", str);
}

export function repr(str: string): string {
  if (wasm == null) throw Error("call init");
  return wasm.callWithString("eval", str) as string;
}

// export function toObject(str: string): object {
//   if (wasm == null) throw Error("call init");
//   //return JSON.parse(wasm.callWithString("toJSON", str));
// }

export async function init() {
  if (wasm != null) return;
  wasm = await wasmImport("python/python.wasm", {
    init: (wasm) => wasm.exports.init(),
  });
}

init();
