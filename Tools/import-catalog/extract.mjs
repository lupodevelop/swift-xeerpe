// Records what each preset of the xeerpe TypeScript library calls on its
// builder and writes it as JSON.
// Usage: node extract.mjs <path to lib/src/presets> <output.json>
import fs from 'node:fs'
const [root, outFile] = process.argv.slice(2)
if (!root || !outFile) { console.error('usage: node extract.mjs <presets dir> <out.json>'); process.exit(2) }
const dir = root.endsWith('/') ? root : root + '/'
const strip = s => s.replace(/^import .*$/gm, '').replace(/^export const (\w+): Record<string, PresetConfig> =/m, 'const $1 =')
const colorsSrc = fs.readFileSync(dir + 'colors.ts', 'utf8').replace(/^export const colors =/m, 'const colors =') + '\nreturn colors'
const colors = new Function(colorsSrc)()
const out = {}
for (const f of fs.readdirSync(dir + 'library').sort()) {
  const category = f.replace('.ts', '')
  const src = strip(fs.readFileSync(dir + 'library/' + f, 'utf8'))
  const table = new Function('colors', src + `\nreturn ${src.match(/const (\w+) =/)[1]}`)(colors)
  out[category] = {}
  for (const [id, fn] of Object.entries(table)) {
    const calls = []
    const builder = new Proxy({}, { get: (_, method) => (...args) => { calls.push({ method, args }); return builder } })
    fn(builder)
    out[category][id] = calls
  }
}
fs.writeFileSync(outFile, JSON.stringify(out, null, 1))
