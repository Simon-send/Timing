import {readFileSync, existsSync} from 'node:fs';
import {join} from 'node:path';
const root = process.argv[2];
if (!root) throw new Error('Build directory required');
const hosting = JSON.parse(readFileSync(new URL('./firebase.json', import.meta.url), 'utf8')).hosting;
const policy = hosting.headers.flatMap(entry => entry.headers)
  .find(header => header.key === 'Content-Security-Policy')?.value ?? '';
const directives = new Map(policy.split(';').map(part => {
  const [name, ...values] = part.trim().split(/\s+/);
  return [name, values];
}));
if (!directives.get('script-src')?.includes('https://apis.google.com') ||
    !directives.get('frame-src')?.includes('https://results.plotting.live')) {
  throw new Error('Hosting CSP blocks Firebase Google sign-in');
}
// GIS is loaded by the web plugin during initialization, including on Safari.
for (const [directive, source] of [
  ['script-src', 'https://accounts.google.com/gsi/client'],
  ['style-src', 'https://accounts.google.com/gsi/style'],
  ['connect-src', 'https://accounts.google.com/gsi/'],
  ['frame-src', 'https://accounts.google.com'],
]) {
  if (!directives.get(directive)?.includes(source)) {
    throw new Error(`Hosting CSP blocks Google Identity Services: ${directive} ${source}`);
  }
}
for (const file of ['index.html','app-start.js','main.dart.js','flutter_bootstrap.js','manifest.json',
  'favicon-plotting-live.png','icons/PlottingLive-192.png','icons/PlottingLive-512.png',
  'assets/assets/branding/plotting_results_logo_v2.png']) {
  if (!existsSync(join(root,file))) throw new Error(`Missing ${file}`);
}
const html = readFileSync(join(root,'index.html'),'utf8');
const js = readFileSync(join(root,'main.dart.js'),'utf8');
const manifest = JSON.parse(readFileSync(join(root,'manifest.json'),'utf8'));
if (!html.includes('<title>Resultater</title>') || manifest.name !== 'Resultater') throw new Error('Incorrect application name');
if (!js.includes('results.plotting.live')) throw new Error('Missing production auth domain');
if (!html.includes('favicon-plotting-live.png')) throw new Error('Incorrect favicon');
for (const icon of manifest.icons) if (!existsSync(join(root,icon.src))) throw new Error(`Missing ${icon.src}`);
console.log('Release assets, title, manifest and auth domain verified.');
