import {readFileSync} from 'node:fs';
async function check(source,mode){
const nodes={},buttons=[],calls=[],messages=[];
const node=()=>({value:'',children:[],append(...x){this.children.push(...x)},replaceChildren(){this.children=[]},reset(){},querySelectorAll(){return []}});
const document={getElementById:k=>nodes[k]??=node()};
let reads=0, writes=0;
async function rpc(name,args){calls.push(name);if(name.startsWith('get')){if(++reads===(mode==='initial'?1:2)&&['initial','delete','save'].includes(mode))throw Error('read');return [{id:'service',name:'service',version:1}]}
writes++;if(mode==='reject'||mode==='deleteReject')throw Error('denied');}
const make=(tag,title)=>{let n=node();if(tag==='button')buttons.push([title,n]);return n};
const fn=Object.getPrototypeOf(async function(){}).constructor;
await new fn('document','crypto','context','rpc','message','status','text','installValidation','validateForm','fieldError','confirm',source.replace(/^import .*;$/gm,''))(document,{randomUUID:()=>'fixture-service'},async()=>'fixture-owner',rpc,String,m=>messages.push(m),make,()=>{},()=>true,()=>{},()=>true);
nodes.name=document.getElementById('name');nodes.name.value='demo';
const submit=()=>nodes['service-form'].onsubmit({preventDefault(){}});
if(mode==='deleteReject'){buttons.find(([label])=>label==='Удалить')[1].onclick();await new Promise(r=>setTimeout(r,0));if(nodes.fields.disabled||messages.some(m=>m.includes('Услуга удалена')))throw Error('False deletion confirmation');}
else if(mode==='double'){await Promise.all([submit(),submit()]);}
else if(mode==='delete'){const del=buttons.find(([t])=>t==='Удалить')[1];del.onclick();await new Promise(r=>setTimeout(r,0));del.onclick();await new Promise(r=>setTimeout(r,0));}
else {await submit();if(mode==='save'||mode==='initial')await submit()}
if(mode==='initial' && messages.some(m=>/Услуга (сохранена|удалена)/.test(m)))throw Error('False confirmation after initial read failure');
if(mode==='ok' && (reads!==2||!messages.includes('Услуга сохранена в черновике.')))throw Error('Missing refreshed list or confirmation');
const expected=mode==='initial'?0:1;
if(writes!==expected||(['save','delete'].includes(mode)&&(!nodes.fields.disabled||!messages.some(m=>m.includes('Список не обновлён'))))||(mode==='reject'&&nodes.fields.disabled)||(mode==='ok'&&nodes.fields.disabled))throw Error(mode+' writes='+writes+' message='+messages.at(-1));
}
const source=readFileSync(process.argv[2] || 'account-specialist-services.js','utf8');
for(const mode of ['initial','save','delete','reject','ok','double','deleteReject']){await check(source,mode);console.log(mode,'PASS');}
