// Thin data/menu adapters. No shared table, role escalation or publication fallback.
import {profileRPC} from './account-profile-core.js';
import {sectionsFor} from './account-profile-sections.js';
const menuFor=kind=>sectionsFor(kind).map(item=>[item.key,item.label,item.route]);
function requireFields(values,fields){if(!values||fields.some(k=>!Object.hasOwn(values,k))||Object.keys(values).some(k=>!fields.includes(k)))throw Error('Передайте полный набор полей профиля.');}
const adapters={
 specialist:{kind:'specialist',idKey:'id',otherIdKey:'company_id',title:'Специалист',unavailable:'Черновик не найден или недоступен.',menu:menuFor('specialist'),
  list:client=>profileRPC(client,'get_my_specialists'),
  select(rows,id){const data=Array.isArray(rows)?rows.find(x=>x.id===id&&x.profile_status==='draft'):null;return data?{kind:'specialist',id,name:data.display_name,role:'owner',status:data.profile_status,canEdit:true,data}:null;},
  saveBasic(client,id,v){requireFields(v,['display_name','profession','specialization','city','description']);return profileRPC(client,'update_my_specialist_draft',{p_id:id,p_display_name:v.display_name,p_profession:v.profession,p_specialization:v.specialization,p_city:v.city,p_description:v.description});},
  savedRecord:result=>result,
  visible:()=>true
 },
 company:{kind:'company',idKey:'company_id',otherIdKey:'id',title:'Компания',unavailable:'Компания не найдена или недоступна.',menu:menuFor('company'),
  list:client=>profileRPC(client,'get_my_companies'),
  select(rows,id){const row=Array.isArray(rows)?rows.find(x=>x.company?.id===id&&x.company.status==='active'&&x.membership?.verification_status==='verified'):null;if(!row||!['owner','admin','manager','analyst'].includes(row.membership.role))return null;const data=row.company,role=row.membership.role;return {kind:'company',id,name:data.name,role,status:data.profile_status,canEdit:['owner','admin'].includes(role),data};},
  saveBasic(client,id,v){requireFields(v,['name','description','website','phone','city','email']);return profileRPC(client,'update_my_company_profile',{p_company_id:id,p_name:v.name,p_description:v.description,p_website:v.website,p_phone:v.phone,p_city:v.city,p_email:v.email});},
  savedRecord:result=>result?.company,
  visible(key,role){if(['access','billing'].includes(key)&&role!=='owner')return false;return role!=='analyst'||!['profile','branches','services','media','reviews','questions','sources'].includes(key);}
 }
};
export function profileAdapter(kind){if(!Object.hasOwn(adapters,kind))throw Error('Неизвестный тип профиля.');return adapters[kind];}
