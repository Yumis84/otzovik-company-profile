import {createHash} from 'node:crypto';
// Called by a trusted publisher adapter AFTER successful publication, never by visitors.
// Binding comes from the publisher's registry, not the JSON's slug or user input.
export function publishedSnapshot({kind,id,exported,publicationConfirmed}){
 if(!publicationConfirmed||!['company','specialist'].includes(kind)||exported.profile_status!=='ready')throw Error('Publication not confirmed');
 const text=(x,max)=>typeof x==='string'?x.slice(0,max):'';
 const payload={name:text(exported.name,160),description:text(exported.description,4000),city:text(exported.location?.city,120),services:[],public_contacts:[]};
 for(const v of (exported.services||[]).slice(0,50)){
  if(typeof v==='string')payload.services.push({name:text(v,160)});
  else if(v&&v.status==='published')payload.services.push({name:text(v.name,160),price:text(v.price,100),currency:text(v.currency,12)});
 }
 for(const c of (exported.contacts||[]).slice(0,10))if(c.visibility==='public'&&['phone','email','website'].includes(c.kind))payload.public_contacts.push({kind:c.kind,value:text(c.value,250)});
 const revision=createHash('sha256').update(JSON.stringify(payload)).digest('hex');return {kind,profile_id:id,revision,payload};
}
