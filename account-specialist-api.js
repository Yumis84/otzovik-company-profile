// Compatibility adapter for existing specialist editor URLs and RPC clients.
import {createClient} from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm';
import {createCabinet,profileRPC} from './account-profile-core.js';
import {profileAdapter} from './account-profile-adapters.js';
import {mountCabinet} from './account-profile-shell.js';
export {message,status} from './account-profile-shell.js';
export const sb=createClient('https://rzhlcszqtuhkhfibygnk.supabase.co','sb_publishable_yhqWJ1eWUznBkqKwPogTrw_xCdCbFA-');
const adapter=profileAdapter('specialist'),cabinet=createCabinet({client:sb,adapter});
export async function loadContext(section){mountCabinet(adapter,{id:null,name:'Проверяем доступ…',role:null},section);const profile=await cabinet.load();mountCabinet(adapter,profile,section);return profile;}
export async function context(section){return (await loadContext(section)).id;}
export const saveBasic=values=>cabinet.saveBasic(values);
export const rpc=(name,args={})=>profileRPC(sb,name,args);
