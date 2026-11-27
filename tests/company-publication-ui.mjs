import assert from 'node:assert/strict';
import {publicationView,renderPublicationStatus} from '../account-company-publication-ui.js';
for(const [status,label,success,retry] of [['queued','? ??????? ?? ??????????',false,false],['building','????????? ???????',false,false],['published','????????????',true,false],['failed','?????? ??????????',false,true]]){
 const v=publicationView({status});assert.deepEqual([v.label,v.success,v.retry],[label,success,retry]);
}
for(const payload of [null,{}, {status:'published-ish'},{status:'published',public_url:'javascript:alert(1)'},{status:'queued',public_url:'https://valid.example/'}]){
 const v=publicationView(payload);assert(!v.publicUrl);assert(v.state==='published'||!v.success);
}
assert.equal(publicationView({status:'published',public_url:'https://example.com/company'}).publicUrl,'https://example.com/company');
const elements=[];const doc={createElement(tag){return {tag,textContent:'',href:'',target:'',rel:''}}};const node={ownerDocument:doc,replaceChildren(){elements.length=0},append(el){elements.push(el)}};
renderPublicationStatus(node,{status:'queued',public_url:'https://example.com/'});assert.equal(elements.length,1);
renderPublicationStatus(node,{status:'published',public_url:'https://example.com/company'});assert.equal(elements.length,2);assert.equal(elements[1].rel,'noopener noreferrer');
renderPublicationStatus(node,{status:'failed',public_url:'https://example.com/'});assert.equal(elements.length,1);
console.log('PASS publication UI: 4 states, fail-closed unknown, no premature links, valid published link only');
