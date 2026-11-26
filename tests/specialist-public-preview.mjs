import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import assert from 'node:assert/strict';
const page=readFileSync(new URL('../staging/specialist/public.html',import.meta.url),'utf8');
const script=page.match(/<script type="module">([\s\S]*?)<\/script>/)[1].replace(/^import .*$/m,'');
for(const [slug,response,expected] of [
 ['demo',{data:{slug:'demo',display_name:'Тест',city:'Город',items:[{type:'service',name:'Тестовая услуга',from:0,to:150,currency:'RUB'},{type:'contact',label:'Сайт',href:'https://example.org/'},{type:'contact',label:'Некорректная ссылка',href:'javascript:void(0)'}]}},''],
 ['demo',{data:null},'Профиль недоступен.'],
 ['demo',{error:Error('offline')},'Не удалось загрузить профиль.'],
 ['x',{},'Профиль недоступен.']
]){
 let onShow,calls=0;
 const nodes=new Map();
 const element=()=>({textContent:'',children:[],replaceChildren(){this.children=[]},append(...items){this.children.push(...items)}});
 const document={querySelector(key){if(!nodes.has(key))nodes.set(key,element());return nodes.get(key)},createElement:element};
 runInNewContext(script,{URL,URLSearchParams,location:{search:'?slug='+slug},document,addEventListener:(_,fn)=>{onShow=fn},createClient:(_url,_key,options)=>{
  assert.equal(options.auth.persistSession,false);
  return {rpc:async(name,args)=>{assert.equal(name,'get_public_specialist_v1');assert.equal(args.p_slug,slug);calls++;return response}};
 }});
 await onShow();assert.equal(calls,slug==='x'?0:1);assert.equal(document.querySelector('[role=status]').textContent,expected);
 if(!expected){assert.equal(document.querySelector('h1').textContent,'Тест');assert.equal(document.querySelector('dl').children.length,6);assert.match(document.querySelector('dl').children[3].textContent,/от 0 · до 150 · RUB/);assert.equal(document.querySelector('dl').children[5].children[0].href,'https://example.org/');}
}
console.log('PASS guest renderer: published fields, null, RPC failure, invalid slug (stub)');
