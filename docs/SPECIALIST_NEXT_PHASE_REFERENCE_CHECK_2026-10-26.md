# Reference-model check

This is design evidence, not an application test or an executable migration. It checks 58 synthetic semantics assertions, evidence structure and company byte equality. Ran with Node24 on Yumis-pc; Pages60 also PASS. To reproduce, save the following fenced code as an external .mjs file and run with Node; adjust the two explicit checkout paths if needed. No hosted connection is made.

```javascript
import fs from 'node:fs';import cp from 'node:child_process';import assert from 'node:assert/strict';
const cwd='C:/Users/Yumis/otzovik-specialist-next-phase',base='693446dff47bb1335c43104cb37ed47931134700';
const git=(...a)=>cp.execFileSync('git',a,{cwd,encoding:'utf8'}).trim();
let checks=0;const ok=(x)=>{assert(x);checks++};
const units=[null,'service','hour','lesson','day','square_meter','project'];
function valid({mode=null,unit=null,from=null,to=null,currency='RUB'}){
 if(!units.includes(unit)||!['RUB','USD','EUR'].includes(currency)||![null,'priced','negotiated','unspecified'].includes(mode))return false;
 if([from,to].some(x=>x!==null&&(!Number.isFinite(x)||x<0||x>1e8)))return false;
 if(from!==null&&to!==null&&to<from)return false;
 return mode===null||(mode==='priced'?(from!==null||to!==null):(from===null&&to===null));
}
for(const [from,to] of [[null,null],[0,null],[null,10],[1,1],[1,10],[1.123,2.345]]) for(const currency of ['RUB','USD','EUR'])ok(valid({from,to,currency}));
for(const unit of units)ok(valid({mode:'priced',unit,from:1}));
ok(valid({mode:'negotiated'}));ok(valid({mode:'unspecified'}));
for(const x of [{mode:'priced'},{mode:'negotiated',from:1},{mode:'unspecified',to:3},{from:5,to:3},{from:-1},{from:NaN},{from:Infinity},{from:100000001},{unit:'week'},{currency:'GBP'},{mode:'free'}])ok(!valid(x));
const legacyEdit=(old,from,to)=>({unit:old.unit,mode:old.from===from&&old.to===to?old.mode:(from!==null||to!==null?'priced':'unspecified')});
assert.deepEqual(legacyEdit({unit:'hour',mode:'negotiated',from:null,to:null},null,null),{unit:'hour',mode:'negotiated'});checks++;
assert.deepEqual(legacyEdit({unit:'hour',mode:'negotiated',from:null,to:null},10,null),{unit:'hour',mode:'priced'});checks++;
const year=(x,now)=>x===null||(Number.isInteger(x)&&x>=1900&&x<=now);
for(const y of [null,1900,2026])ok(year(y,2026));for(const y of [1899,2027,-1,2020.5,'2020',NaN])ok(!year(y,2026));ok(year(2027,2027));
function attach(project,media){return media.every(m=>m.profile===project.profile&&m.kind==='portfolio')&&new Set(media.map(m=>m.id)).size===media.length&&media.length<=10;}
ok(attach({profile:'a'},[]));ok(attach({profile:'a'},[{id:1,profile:'a',kind:'portfolio'}]));
ok(!attach({profile:'a'},[{id:1,profile:'b',kind:'portfolio'}]));ok(!attach({profile:'a'},[{id:1,profile:'a',kind:'avatar'}]));
ok(!attach({profile:'a'},[{id:1,profile:'a',kind:'portfolio'},{id:1,profile:'a',kind:'portfolio'}]));
ok(!attach({profile:'a'},Array.from({length:11},(_,i)=>({id:i,profile:'a',kind:'portfolio'}))));
const expected=fs.readFileSync(cwd+'/docs/SPECIALIST_NEXT_PHASE_PREFLIGHT_2026-10-26.json','utf8');const meta=JSON.parse(expected);
ok(meta.tables.length===6&&meta.tables.every(t=>t.relrowsecurity&&t.relforcerowsecurity));
ok(meta.functions.length===17&&meta.functions.every(f=>!f.anon_execute));
const files=git('ls-tree','-r','--name-only',base).split('\n');
const company=files.filter(p=>/^account.*\.(html|js|css)$/.test(p)&&!p.startsWith('account-specialist')&&p!=='account-create-specialist.html');
for(const p of company){assert.equal(git('hash-object',p),git('rev-parse',base+':'+p));assert.deepEqual(fs.readFileSync(cwd+'/'+p),fs.readFileSync('C:/Users/Yumis/otzovik-specialist-readiness/'+p));}
const changed=git('status','--porcelain','--untracked-files=all').split('\n').filter(Boolean).map(x=>x.trim().split(/\s+/).slice(1).join(' '));
assert(changed.every(p=>p.startsWith('docs/SPECIALIST_NEXT_PHASE_')));
const report={date:'2026-10-26',scope:'Reference semantics only; not future SQL/runtime/security/concurrency proof',reference_assertions:checks,company_files_byte_identical:company.length,tracked_runtime_diff:git('diff','--name-only',base).split('\n').filter(Boolean),baseline_ci:'39984915671 SUCCESS; same HEAD693446d verified via GitHub',hosted_scope:'SELECT catalog+aggregate only; no hosted mutation tests',pages:'PASS60 separately executed 2026-10-26',limits:'No new model implemented; Docker/concurrency and mobile tests are acceptance requirements for future PRs'};
fs.writeFileSync(cwd+'/docs/SPECIALIST_NEXT_PHASE_VALIDATION_2026-10-26.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));

```
