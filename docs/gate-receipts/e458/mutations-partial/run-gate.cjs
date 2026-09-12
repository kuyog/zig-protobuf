const fs = require('node:fs');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const path = require('node:path');
const root = '/Users/dallindyer/Dev/flutter_source/zig-protobuf-e458-mutations';
const evidence = __dirname;
const [name, filter] = process.argv.slice(2);
if (!name || !filter || !/^[a-z0-9-]+$/.test(name)) throw Error('name and filter required');
const git = (...args) => cp.execFileSync('git', ['-C', root, ...args], {encoding: 'utf8'});
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
function snapshot() {
  const head = git('rev-parse', 'HEAD').trim();
  if (head !== 'e4584b43c99ddb2047153c2697b8d49f75b75930') throw Error('head moved');
  if (git('diff', '--cached').length) throw Error('index changed');
  const files = Object.fromEntries(['src/wire.zig', 'src/protobuf.zig', 'src/decode_error_test.zig'].map(p => [p, hash(fs.readFileSync(path.join(root, p)))]));
  if (files['src/decode_error_test.zig'] !== '1debf64ec283b56bcd7aac3348e62bd4fc9f3edda590cd98ca2ea71f27ebc625') throw Error('tests changed');
  return {head, files, diff: git('diff', '--', 'src')};
}
const before = snapshot();
fs.writeFileSync(path.join(evidence, name + '.before.json'), JSON.stringify(before, null, 2) + '\n', {flag: 'wx'});
const log = fs.openSync(path.join(evidence, name + '.log'), 'wx');
const command = [
  '/Users/dallindyer/Dev/flutter_source/kuyog-crowd-canonical-capture/tools/crowd_canonical_codec_experiment/run-bounded.py',
  '180', path.join(evidence, name + '.run.json'),
  '/opt/homebrew/Cellar/zig/0.16.0_1/bin/zig', 'test', 'src/protobuf.zig', '-O', 'Debug',
  '--test-filter', filter, '--cache-dir', path.join(evidence, 'zig-cache'),
  '--global-cache-dir', '/tmp/protobuf-decode-340078b-gates.cfddUO/zig-global-cache',
];
const child = cp.spawn('/usr/bin/python3', command, {cwd: root, stdio: ['ignore', log, log]});
child.on('error', error => { throw error; });
child.on('exit', (code, signal) => {
  fs.closeSync(log);
  const after = snapshot();
  fs.writeFileSync(path.join(evidence, name + '.after.json'), JSON.stringify(after, null, 2) + '\n', {flag: 'wx'});
  if (JSON.stringify(before) !== JSON.stringify(after)) throw Error('source changed during run');
  const output = fs.readFileSync(path.join(evidence, name + '.log'), 'utf8');
  const lines = output.split('\n').filter(s => /^\d+\/\d+ |tests? passed|tests? failed|tests? leaked|error:|panic:/.test(s));
  console.log(JSON.stringify({name, code, signal, source_unchanged: true, lines}, null, 2));
  process.exitCode = signal ? 1 : code;
});
