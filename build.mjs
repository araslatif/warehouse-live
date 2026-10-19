import {cp, mkdir, rm, access} from 'node:fs/promises';
await rm('dist', {recursive:true, force:true});
await mkdir('dist', {recursive:true});
await cp('public', 'dist', {recursive:true});
try { await access('images'); await cp('images','dist/images',{recursive:true}); }
catch (error) { if(error.code !== 'ENOENT') throw error; console.warn('images/ missing: preserve your existing images folder in the repository root.'); }
console.log('V97 built in dist/; database configuration copied without modification.');
