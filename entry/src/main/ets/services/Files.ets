// 沙箱路径与文件工具。iOS 的 Application Support/cstf/ → filesDir/cstf/。
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

export class AppEnv {
  static context: common.UIAbilityContext | null = null;

  static ctx(): common.UIAbilityContext {
    if (AppEnv.context === null) {
      throw new Error('UIAbilityContext 未初始化');
    }
    return AppEnv.context;
  }

  /** filesDir/cstf */
  static cstfRoot(): string {
    return `${AppEnv.ctx().filesDir}/cstf`;
  }

  /** filesDir/cstf/data */
  static dataRoot(): string {
    return `${AppEnv.cstfRoot()}/data`;
  }

  /** filesDir/cstf/audio */
  static audioRoot(): string {
    return `${AppEnv.cstfRoot()}/audio`;
  }

  static cacheDir(): string {
    return AppEnv.ctx().cacheDir;
  }
}

export class Files {
  static exists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (e) {
      return false;
    }
  }

  static isDir(path: string): boolean {
    try {
      return fs.statSync(path).isDirectory();
    } catch (e) {
      return false;
    }
  }

  static mkdirs(path: string): void {
    if (!Files.exists(path)) {
      fs.mkdirSync(path, true);
    }
  }

  /** 真机调试日志（console.* 在 release 构建下不进 hilog，写文件兜底）。 */
  static dbg(msg: string): void {
    try {
      const path = `${AppEnv.ctx().filesDir}/dbg.log`;
      const prev = Files.readText(path) ?? '';
      Files.writeTextAtomic(path, prev + msg + '\n');
    } catch (e) {
      // 调试日志本身不允许再抛
    }
  }

  static parent(path: string): string {
    const i = path.lastIndexOf('/');
    return i > 0 ? path.substring(0, i) : path;
  }

  static readText(path: string): string | null {
    try {
      if (!Files.exists(path)) {
        return null;
      }
      return fs.readTextSync(path);
    } catch (e) {
      return null;
    }
  }

  /** 先写临时文件再改名，保证读到的永远是完整 JSON。 */
  static writeTextAtomic(path: string, text: string): void {
    Files.mkdirs(Files.parent(path));
    const tmp = `${path}.tmp`;
    const file = fs.openSync(tmp, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, text);
    } finally {
      fs.closeSync(file);
    }
    fs.renameSync(tmp, path);
  }

  static writeBytes(path: string, data: ArrayBuffer): void {
    Files.mkdirs(Files.parent(path));
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, data);
    } finally {
      fs.closeSync(file);
    }
  }

  static remove(path: string): void {
    try {
      if (!Files.exists(path)) {
        return;
      }
      if (Files.isDir(path)) {
        fs.rmdirSync(path);
      } else {
        fs.unlinkSync(path);
      }
    } catch (e) {
      // 清理失败不影响主流程
    }
  }

  /** 递归列出目录下所有普通文件（相对路径，不带前导 /）。 */
  static listFilesRecursive(dir: string): string[] {
    const out: string[] = [];
    const walk = (rel: string) => {
      const abs = rel.length > 0 ? `${dir}/${rel}` : dir;
      let names: string[] = [];
      try {
        names = fs.listFileSync(abs);
      } catch (e) {
        return;
      }
      for (const name of names) {
        const childRel = rel.length > 0 ? `${rel}/${name}` : name;
        const childAbs = `${dir}/${childRel}`;
        let st: fs.Stat | null = null;
        try {
          st = fs.lstatSync(childAbs);
        } catch (e) {
          continue;
        }
        if (st.isSymbolicLink()) {
          throw new Error('资源包含符号链接');
        }
        if (st.isDirectory()) {
          walk(childRel);
        } else if (st.isFile()) {
          out.push(childRel);
        }
      }
    };
    walk('');
    return out;
  }

  static listNames(dir: string): string[] {
    try {
      return fs.listFileSync(dir);
    } catch (e) {
      return [];
    }
  }

  static move(src: string, dest: string): void {
    Files.mkdirs(Files.parent(dest));
    try {
      fs.renameSync(src, dest);
    } catch (e) {
      fs.copyFileSync(src, dest);
      fs.unlinkSync(src);
    }
  }

  static sha256Hex(path: string): string {
    try {
      return Files.sha256HexImpl(path);
    } catch (e) {
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      try {
        const st = fs.statSync(file.fd);
        const buf = new ArrayBuffer(Math.min(1 << 20, st.size));
        const n = fs.readSync(file.fd, buf, { offset: 0, length: buf.byteLength });
        return Files.fingerprint(new Uint8Array(buf.slice(0, n))) + `-${st.size}`;
      } finally {
        fs.closeSync(file);
      }
    }
  }

  private static sha256HexImpl(path: string): string {
    const md = cryptoFramework.createMd('SHA256');
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const chunk = new ArrayBuffer(1 << 20);
      let position = 0;
      while (true) {
        const n = fs.readSync(file.fd, chunk, { offset: position, length: chunk.byteLength });
        if (n <= 0) {
          break;
        }
        md.updateSync({ data: new Uint8Array(chunk.slice(0, n)) });
        position += n;
      }
    } finally {
      fs.closeSync(file);
    }
    return Files.hex(md.digestSync().data);
  }

  static sha256OfBytes(bytes: Uint8Array): string {
    try {
      const md = cryptoFramework.createMd('SHA256');
      md.updateSync({ data: bytes });
      return Files.hex(md.digestSync().data);
    } catch (e) {
      return Files.fingerprint(bytes);
    }
  }

  /** FNV-1a 64bit 内容指纹 —— createMd 不可用设备上的确定性退避。
      用于种子版本戳/课程内容键（只需确定性，不需抗碰撞）。 */
  static fingerprint(bytes: Uint8Array): string {
    let h = 0xcbf29ce484222325n;
    const prime = 0x100000001b3n;
    const mask = 0xffffffffffffffffn;
    for (let i = 0; i < bytes.length; i++) {
      h = (h ^ BigInt(bytes[i])) * prime & mask;
    }
    return `fnv64-${h.toString(16)}`;
  }

  static sha256OfText(text: string): string {
    return Files.sha256OfBytes(new util.TextEncoder().encodeInto(text));
  }

  static hex(bytes: Uint8Array): string {
    let s = '';
    for (let i = 0; i < bytes.length; i++) {
      const b = bytes[i];
      s += (b < 16 ? '0' : '') + b.toString(16);
    }
    return s;
  }

  static decodeUtf8(bytes: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(bytes);
  }

  static uuid(): string {
    return util.generateRandomUUID(false);
  }
}
