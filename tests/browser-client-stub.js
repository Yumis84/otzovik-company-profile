// Test-only adapter. Auth/Storage are simulated; selected RPCs execute real isolated SQL.
export const createClient=()=>({
 auth:{
  getSession:async()=>({data:{session:await window.testSession()}}),
  signInWithPassword:args=>window.testAuth('login',args),
  signUp:args=>window.testAuth('signup',args),
  signOut:()=>window.testAuth('logout',{})
 },
 rpc:(name,args)=>window.testRPC(name,args),
 from:table=>{
  const query={table,filters:[],single:false};
  const builder={select:()=>builder,eq:(key,value)=>{query.filters.push([key,value]);return builder;},order:()=>builder,limit:()=>builder,maybeSingle:()=>{query.single=true;return builder;},then:(ok,fail)=>window.testTable(query).then(ok,fail)};
  return builder;
 },
 storage:{from:bucket=>({upload:async path=>({data:{path},error:null}),remove:async()=>({data:[],error:null}),createSignedUrl:async path=>({data:{signedUrl:'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='},error:null})})}
});
