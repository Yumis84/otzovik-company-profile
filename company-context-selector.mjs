// Single pure membership selector for the company cabinet. No persistence or UI side effects.
export class CompanySelectionDeniedError extends Error {
 constructor(){super('\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430 \u043a \u0432\u044b\u0431\u0440\u0430\u043d\u043d\u043e\u0439 \u043a\u043e\u043c\u043f\u0430\u043d\u0438\u0438');this.name='CompanySelectionDeniedError'}
}
export function selectVerifiedCompanyRow(rows, requestedId, {explicit=false}={}) {
 if(!Array.isArray(rows))throw Error('Invalid company membership response');
 const valid=rows.filter(row=>row?.company?.id && row?.membership?.role);
 if(requestedId){
  const selected=valid.find(row=>row.company.id===requestedId && (!row.company_id||row.company_id===requestedId));
  if(selected)return selected;
  if(explicit)throw new CompanySelectionDeniedError();
 }
 return valid[0]||null;
}
