// One section registry, based on the company cabinet. Missing routes are unavailable,
// never redirected to the other profile kind's editor.
export const profileSections=[
 {key:'profile',label:'Профиль',primary:true,routes:{company:'account-profile.html',specialist:'account-specialist-profile.html'}},
 {key:'branches',label:'Филиалы',routes:{company:'account-branches.html'}},
 {key:'services',label:'Услуги',primary:true,labels:{specialist:'Услуги и цены'},routes:{company:'account-services.html',specialist:'account-specialist-services.html'}},
 {key:'media',label:'Фото',primary:true,labels:{specialist:'Фото и портфолио'},routes:{company:'account-media.html',specialist:'account-specialist-media.html'}},
 {key:'contacts',label:'Контакты',labels:{specialist:'Контакты и работа'},routes:{specialist:'account-specialist-contacts.html'}},
 {key:'reviews',label:'Отзывы',labels:{specialist:'Отзывы и ответы'},routes:{company:'account-reviews.html',specialist:'account-specialist-section.html'}},
 {key:'questions',label:'Вопросы и ответы',labels:{specialist:'Вопросы пользователей'},routes:{company:'account-qna.html',specialist:'account-specialist-section.html'}},
 {key:'sources',label:'Источники рейтингов',routes:{company:'account-sources.html',specialist:'account-specialist-section.html'}},
 {key:'access',label:'Доступ',routes:{company:'account-access.html'}},
 {key:'billing',label:'Тариф и оплата',routes:{company:'account-billing.html'}},
 {key:'assistant',label:'AI-ассистент',labels:{specialist:'ИИ-ассистент'},routes:{company:'account-ai-assistant.html',specialist:'account-specialist-section.html'}},
 {key:'notifications',label:'Уведомления',routes:{company:'account-notifications.html',specialist:'account-specialist-section.html'}},
 {key:'analytics',label:'Статистика',labels:{specialist:'Аналитика'},routes:{company:'account-analytics.html',specialist:'account-specialist-section.html'}},
 {key:'mcp',label:'Мой ИИ-агент · MCP',routes:{specialist:'account-specialist-section.html'}},
 {key:'settings',label:'Настройки и публикация',routes:{specialist:'account-specialist-section.html'}}
];
export function sectionsFor(kind){return profileSections.filter(item=>Object.hasOwn(item.routes,kind)).map(item=>({...item,primaryLabel:item.label,label:item.labels?.[kind]||item.label,route:item.routes[kind]}));}
export function activeSection(kind,location=globalThis.location){
 const params=new URLSearchParams(location.search),page=location.pathname.split('/').pop().replace(/\.html$/,'');
 if(kind==='specialist'&&page==='account-specialist-section')return sectionsFor(kind).find(item=>item.key===params.get('section'))?.key||'settings';
 return sectionsFor(kind).find(item=>item.route.replace(/\.html$/,'')===page)?.key||'profile';
}
