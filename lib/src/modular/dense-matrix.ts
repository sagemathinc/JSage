import { DenseVector } from "./dense-vector";
import { init as pariInit, exec as pariExec } from "../pari";
import wasmImport from "../wasm";
export let wasm: any = undefined;
export async function init() {
  wasm = await wasmImport("modular/manin-symbols");
}
init();

// @ts-ignore
const registry = new FinalizationRegistry((handle) => {
  wasm.exports.DenseMatrix_free(handle);
});

export class DenseMatrix {
  private readonly handle: number;

  constructor(handle: number) {
    if (handle <= 0) {
      throw Error(`invalid handle ${handle}`);
    }
    this.handle = handle;
    registry.register(this, this.handle);
  }

  __repr__(): string {
    wasm.exports.DenseMatrix_format(this.handle);
    return wasm.result;
  }

  toJSON(): {
    type: "DenseMatrixMod";
    modulus: number;
    nrows: number;
    ncols: number;
    entries: number[];
  } {
    wasm.exports.DenseMatrix_stringify(this.handle);
    return JSON.parse(wasm.result);
  }

  getRow(i: number): DenseVector {
    return new DenseVector(wasm.exports.DenseMatrix_getRow(this.handle, i));
  }

  modulus(): number {
    return wasm.exports.DenseMatrix_modulus(this.handle);
  }

  kernel(): DenseMatrix {
    return new DenseMatrix(wasm.exports.DenseMatrix_kernel(this.handle));
  }

  __sub__(other) {
    return this.subtractScalar(other);
  }

  subtractScalar(scalar: number): DenseMatrix {
    return new DenseMatrix(
      wasm.exports.DenseMatrix_subtractScalar(this.handle, scalar)
    );
  }

  transpose(): DenseMatrix {
    return new DenseMatrix(wasm.exports.DenseMatrix_transpose(this.handle));
  }

  nrows(): number {
    return wasm.exports.DenseMatrix_nrows(this.handle);
  }

  ncols(): number {
    return wasm.exports.DenseMatrix_ncols(this.handle);
  }

  rank(): number {
    return wasm.exports.DenseMatrix_rank(this.handle);
  }

  toPariString(): string {
    const { modulus, nrows, ncols, entries } = this.toJSON();
    // make it in pari
    let s: string = "[";
    for (let i = 0; i < nrows; i++) {
      if (i > 0) s += ";";
      for (let j = 0; j < ncols; j++) {
        s += `${j > 0 ? "," : ""}Mod(${entries[i * ncols + j]},${modulus})`;
      }
    }
    s += "]";
    return s;
  }

  // quick and dirty factored charpoly for now that just prints it.
  async fcp(): Promise<void> {
    // NOTE: this will just fail the first time due to needing to
    // init pari...
    await pariInit();
    console.log(pariExec(`lift(factor(charpoly(${this.toPariString()})))`));
  }
}
