export const kinds={telegram:'Telegram',max:'MAX',vk:'ВКонтакте',whatsapp:'WhatsApp',ok:'Одноклассники',website:'Сайт',portfolio:'Внешнее портфолио'};
export function prepareChannelValue(input){
 // Only cosmetic edits: keep paths, query strings and opaque service tokens intact.
 return String(input).replace(/^ +| +$/g,'').replace(/^https:\/\//i,'https://');
}
export function normalizeChannel(kind,input){
 if(!Object.hasOwn(kinds,kind))throw Error('Неизвестный тип контакта.');
 let s=prepareChannelValue(input);
 if(!s||s.length>500||/[^\x21-\x7e]/.test(s)||/[\\<>"']/.test(s)||/%(?:0[0-9a-f]|1[0-9a-f]|7f|5c|3c|3e|22|27)/i.test(s))throw Error('Введите корректную ссылку HTTPS без пробелов.');
 if(kind==='telegram'&&/^@[A-Za-z][A-Za-z0-9_]{0,31}$/.test(s))s='https://t.me/'+s.slice(1);
 if(kind==='whatsapp'&&/^\+[1-9][0-9]{7,14}$/.test(s))s='https://wa.me/'+s.replace(/^\+/,'');
 const m=/^https:\/\/([^/?#]+)([^?#]*)(\?[^#]*)?$/.exec(s);
 if(/%(?![0-9a-f]{2})/i.test(s)||/(?:\/|%2f)(?:\.|%2e){1,2}(?:\/|%2f|\?|$)/i.test(s))throw Error('Проверьте путь ссылки.');
 if(!m)throw Error('Нужна полная ссылка, начинающаяся с https://.');
 let host=m[1].toLowerCase(),path=m[2]||'/',query=m[3]||'';
 if(host.length>253||host.split('.').some(x=>! /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(x)||x.startsWith('xn--'))||!/\.[a-z]{2,63}$/.test(host)||/\.(?:local|localhost|internal|invalid|test|example)$/.test(host))throw Error('Проверьте домен ссылки.');
 if(kind==='telegram'){
  if(!['t.me','telegram.me'].includes(host)||!/^\/[A-Za-z][A-Za-z0-9_]{0,31}\/?$/.test(path)||query||/^(?:share|proxy|socks|login|joinchat|addstickers|addemoji|boost|giftcode|invoice|iv|c|s|bg|contact|confirmphone|setlanguage)$/i.test(path.replaceAll('/','')))throw Error('Укажите @имя или прямую ссылку на профиль Telegram.');
  host='t.me';path='/'+path.replaceAll('/','').toLowerCase();
 }else if(kind==='whatsapp'){
  if(host!=='wa.me'||!/^\/[1-9][0-9]{7,14}$/.test(path)||query)throw Error('Укажите международный номер с кодом страны или ссылку https://wa.me/номер.');
 }else if(kind==='vk'){
  if(!['vk.com','m.vk.com'].includes(host)||!/^\/[A-Za-z0-9_.-]+\/?$/.test(path)||query||/^\/(?:away(?:\.php)?|login|oauth|share|cc)\/?$/i.test(path))throw Error('Вставьте прямую ссылку на профиль ВКонтакте.');
  host='vk.com';path=path.replace(/\/$/,'').toLowerCase();
 }else if(kind==='ok'){
  if(!['ok.ru','m.ok.ru'].includes(host)||!/^\/(?:profile\/[0-9]+|[A-Za-z0-9_.-]+)\/?$/.test(path)||query||/^\/(?:dk|login|help|outlink|away)\/?$/i.test(path))throw Error('Вставьте прямую ссылку на профиль Одноклассников.');
  host='ok.ru';path=path.replace(/\/$/,'').toLowerCase();
 }else if(kind==='max'){
  if(host!=='max.ru'||path==='/'||query)throw Error('Вставьте полную ссылку на профиль из MAX (https://max.ru/…).');
 }
 return 'https://'+host+path+query;
}
export function validateChannels(rows){
 if(!Array.isArray(rows)||rows.length>20)throw Error('Можно добавить до 20 контактов.');
 const seen=new Set(),ids=new Set();let preferred=0;
 return rows.map(row=>{
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(row.id)||ids.has(row.id))throw Error('Некорректный идентификатор контакта.');ids.add(row.id);
  const value=prepareChannelValue(row.value_raw??''),href=normalizeChannel(row.kind,value),label=String(row.label??'').trim();
  if([...label].length>40||/[\x00-\x1f\x7f]/.test(label))throw Error('Название контакта — до 40 символов, без переносов.');
  if(row.is_public===true)throw Error('Публичные контакты пока недоступны.');
  for(const field of ['is_preferred','accepts_inquiries','is_public'])if(row[field]!==undefined&&typeof row[field]!=='boolean')throw Error('Некорректная настройка контакта.');
  const key=row.kind+'|'+href;if(seen.has(key))throw Error('Этот контакт уже добавлен.');seen.add(key);
  if(row.is_preferred&&++preferred>1)throw Error('Выберите один предпочтительный контакт.');
  return {id:row.id,kind:row.kind,value_raw:value,label,is_preferred:!!row.is_preferred,accepts_inquiries:!!row.accepts_inquiries,is_public:false,href};
 });
}

// UI-only defaults: a country prefix alone is not a contact.
export const phoneValue=value=>String(value??'').trim()==='+7'?'':String(value??'').trim();
export const phoneDisplayValue=value=>phoneValue(value)||'+7';
