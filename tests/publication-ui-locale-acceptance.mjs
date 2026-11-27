import assert from 'node:assert/strict';
import path from 'node:path';import {pathToFileURL} from 'node:url';
assert(process.argv[2],'Pass exact incoming publication module path; never substitute a mock implementation');
const {publicationView,renderPublicationStatus}=await import(pathToFileURL(path.resolve(process.argv[2])).href);
const checks=[];
for(const status of ['queued','building','published','failed','unknown']){
 const label=publicationView({status}).label;
 checks.push({name:status+' label',ok:typeof label==='string'&&/\p{Script=Cyrillic}/u.test(label)&&!/[?]{2,}/.test(label)});
}
const children=[],doc={createElement:()=>({})},node={ownerDocument:doc,replaceChildren(){children.length=0},append(x){children.push(x)}};
renderPublicationStatus(node,{status:'published',public_url:'https://example.com/profile'});
const link=children.find(x=>x.href);
checks.push({name:'public link text',ok:!!link&&/\p{Script=Cyrillic}/u.test(link.textContent)&&!/[?]{2,}/.test(link.textContent)});
console.log(JSON.stringify(checks));
assert(checks.every(x=>x.ok),'Publication UI contains broken Russian labels');
console.log('PASS independent locale: all states and public link contain readable Cyrillic, no corrupted question-mark runs');
