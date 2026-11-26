import {createClient} from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm';
const sb=createClient('https://salmcnhexlftrgtiryyo.supabase.co','sb_publishable_W-trkanJIam4TdhADQkbzw_ngISUVv6',{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
const status=document.getElementById('status'),profile=document.getElementById('profile');
function text(tag,value){const el=document.createElement(tag);el.textContent=value??'';return el;}
const slug=new URLSearchParams(location.search).get('slug');
try{
 if(!slug||!/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/.test(slug)||slug.includes('--'))throw Error('????? ??????? ?????? ???????.');
 const {data,error}=await sb.rpc('get_public_specialist_v1',{p_slug:slug});
 if(error)throw Error('?? ??????? ????????? ???????. ???????? ????????.');
 if(!data){status.textContent='??????? ???? ??????????.';}
 else{
 profile.append(text('h1',data.display_name),text('p',data.profession),text('p',data.specialization),text('p',data.city),text('p',data.description));
 for(const item of data.items??[]){
 const card=document.createElement('article');
 if(item.type==='service'){card.append(text('h2',item.name),text('p',item.description));if(item.from!=null||item.to!=null)card.append(text('p',[item.from!=null?'?? '+item.from:'',item.to!=null?'?? '+item.to:'',item.currency].filter(Boolean).join(' ')));}
 else if(item.type==='contact'){try{const url=new URL(item.href);if(!['https:','mailto:','tel:'].includes(url.protocol))continue;const a=text('a',item.label);a.href=url.href;a.rel='noopener noreferrer';card.append(a);}catch{continue;}}
 else continue;
 profile.append(card);
 }
 profile.hidden=false;status.hidden=true;document.title=data.display_name+' ? ?????.com';
 }
}catch(e){status.textContent=e.message;}
