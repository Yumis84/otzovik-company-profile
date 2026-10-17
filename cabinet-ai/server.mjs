import http from 'node:http';
import fs from 'node:fs/promises';
import {randomBytes,createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {CabinetAssistant,Denied} from './core.mjs';
export function fixtureServer({port=18888}={}){
 const core=new CabinetAssistant();core.seed('demo-a','company','company-demo','Компания — тест');core.seed('demo-b','specialist','specialist-demo','Специалист — тест');const tokens=new Map();const hash=t=>createHash('sha256').update(t).digest('hex');const origin=`http://127.0.0.1:${port}`;
 const server=http.createServer(async(req,res)=>{res.setHeader('Cache-Control','no-store');res.setHeader('Content-Security-Policy',"default-src 'self';script-src 'self';style-src 'self';connect-src 'self';frame-ancestors 'none'");res.setHeader('X-Content-Type-Options','nosniff');try{
 const path=new URL(req.url,origin).pathname;
 if(req.method==='GET'&&['/','/history','/client.mjs','/style.css'].includes(path)){res.setHeader('Content-Type',path.endsWith('.mjs')?'text/javascript':path.endsWith('.css')?'text/css':'text/html;charset=utf-8');res.end(await fs.readFile(new URL(path==='/'||path==='/history'?'index.html':path.slice(1),import.meta.url)));return;}
 if(req.method!=='POST'||req.headers.origin!==origin)throw new Denied(403,'Origin запрещён');let raw='';for await(const chunk of req){raw+=chunk;if(Buffer.byteLength(raw)>10000)throw new Denied(413,'Слишком большой запрос');}let b;try{b=JSON.parse(raw);}catch{throw new Denied(400,'Неверный JSON');}if(!b||Array.isArray(b)||typeof b!=='object')throw new Denied(400,'Неверный запрос');let result;
 if(path==='/api/demo'){if(!['demo-a','demo-b'].includes(b.actor))throw new Denied(403,'Только тестовые владельцы');const token=randomBytes(32).toString('base64url');tokens.set(hash(token),{id:b.actor,expires:Date.now()+1800000});result={token,profiles:[...core.profiles.values()].filter(p=>p.owner===b.actor)};}
 else{const a=tokens.get(hash((req.headers.authorization||'').replace(/^Bearer /,'')));if(!a||a.expires<Date.now())throw new Denied(401,'Начните тестовую сессию');
 if(path==='/api/start')result=core.start(a,b.kind,b.id);else if(path==='/api/list')result=core.list(a);else if(path==='/api/history')result=core.history(a,b.id);else if(path==='/api/chat'){if(Object.keys(b).some(k=>!['conversation_id','message','request_id','expected_seq'].includes(k)))throw new Denied(400,'Правила платформы недоступны для изменения');result=core.chat(a,b);}else if(path==='/api/review')result=core.review(a,b.id);else if(path==='/api/approve')result=core.approve(a,b);else if(path==='/api/clear')result=core.clear(a,b.id);else throw new Denied(404,'Не найдено');}
 res.setHeader('Content-Type','application/json');res.end(JSON.stringify(result));
 }catch(e){res.statusCode=e.status||500;res.setHeader('Content-Type','application/json');res.end(JSON.stringify({error:e.status?e.message:'Ошибка тестового сервера'}));}});
 server.requestTimeout=10000;const cleanup=setInterval(()=>{core.cleanup();for(const[k,v]of tokens)if(v.expires<Date.now())tokens.delete(k);},10000);cleanup.unref();server.on('close',()=>clearInterval(cleanup));return {server,core,origin};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){const app=fixtureServer();app.server.listen(18888,'127.0.0.1',()=>console.log(app.origin+' — synthetic data only; not deployable'));}
