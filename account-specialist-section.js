import {context,message,status} from './account-specialist-api.js';
import {text} from './account-specialist-ui.js';
const sections={
 reviews:['Отзывы и ответы','Отзывы специалиста не подключены. Здесь будут отзывы именно этого профиля и ответы владельца.','Отзывы компаний не используются. Ответы и публикация сейчас отключены.'],
 questions:['Вопросы пользователей','Приём вопросов для приватного черновика отключён.','После подключения серверного модуля здесь будут вопросы и ответы этого специалиста.'],
 sources:['Источники рейтингов','Подтверждённые источники рейтингов специалиста не подключены.','Рейтинги не рассчитываются и не копируются из профиля компании.'],
 analytics:['Аналитика','Сбор статистики специалиста не подключён.','Демонстрационные просмотры, обращения и показатели не отображаются.'],
 notifications:['Уведомления','Серверная доставка уведомлений специалиста не включена.','Telegram и email не подключены; уведомления не отправляются.'],
 assistant:['ИИ-ассистент','Помощник кабинета и консультант для посетителей отключены.','История, защищённые предложения и настройки требуют отдельного включения серверных модулей. Платные AI-вызовы не выполняются.'],
 mcp:['Мой ИИ-агент · MCP','Подключение внешнего агента отключено.','Сервер авторизации и отзыва разрешений ещё не развёрнут. Ключи и пароли вводить здесь не нужно.'],
 settings:['Настройки и публикация','Профиль остаётся приватным черновиком.','Публичная выдача специалистов ещё не включена. Сохранение анкеты, услуг или фото не публикует профиль.']
};
const section=new URLSearchParams(location.search).get('section')||'settings';
const root=document.getElementById('section-content');
function card(title,description){const c=text('section','','card');c.append(text('h2',title),text('p',description));root.append(c);return c;}
function disabledControl(parent,label,type='button'){
 const e=text(type,label);e.disabled=true;if(type==='button')e.type='button';parent.append(e);return e;
}
try{
 if(!Object.hasOwn(sections,section))throw Error('Раздел не найден. Откройте профиль из «Мои профили».');
 const id=await context(section),[title,reason,detail]=sections[section];
 document.title=title+' специалиста | Отзыв.com';document.getElementById('section-title').textContent=title;
 card('Состояние раздела',reason).append(text('p',detail));
 if(section==='assistant'){
  const owner=card('Помощник владельца','Помогает готовить изменения. Каждое предложение требует вашего подтверждения; автоматическая публикация запрещена.');
  disabledControl(owner,'Открыть помощника · отключено');disabledControl(owner,'История диалогов · отключена');
  const visitor=card('ИИ-консультант посетителей','Использует только опубликованные данные. У приватного черновика нет публичной базы знаний.');
  for(const [label,max] of [['Приветствие',300],['Инструкции владельца',2000],['Дополнительная информация',4000]]){const l=text('label',label);const input=document.createElement('textarea');input.maxLength=max;input.disabled=true;l.append(input);visitor.append(l);}
  const l=text('label','Расположение виджета');const select=document.createElement('select');select.disabled=true;for(const value of ['Справа внизу','Слева внизу','Внутри страницы'])select.append(text('option',value));l.append(select);visitor.append(l);
  disabledControl(visitor,'Включить консультанта · отключено');visitor.append(text('p','Настройки сейчас не сохраняются. Секреты и платёжные данные сюда не вводятся.','hint'));
 }
 if(section==='mcp'){
  const c=card('Индивидуальные разрешения','Будущий доступ привязывается только к этому профилю, выбранному агенту и сроку действия. По умолчанию разрешений нет.');
  for(const label of ['Чтение приватного профиля','Предложения изменений анкеты','Предложения услуг и цен','Работа с портфолио','Чтение отзывов и вопросов','Подготовка ответов']){const l=text('label',label);const input=document.createElement('input');input.type='checkbox';input.disabled=true;input.checked=false;l.prepend(input);c.append(l);}
  disabledControl(c,'Подключить агента · отключено');
  card('Отзыв доступа','Подключения пока не создаются. Список активных доступов не загружен: серверный модуль отсутствует. Кнопка отзыва станет доступна после получения подтверждённого сервером списка.').append(text('p','Каждый запрос должен повторно проверять владельца, профиль, разрешения, срок и отзыв. Публикация не входит в эти разрешения.'));
 }
 if(section==='settings'){
  const c=card('Адрес и видимость','Адрес зарезервирован. Смена адреса и публичная публикация сейчас отключены.');
  disabledControl(c,'Опубликовать · отключено');
  const a=text('a','Редактировать основные сведения');a.href='account-specialist-profile.html?id='+encodeURIComponent(id);c.append(a);
 }
 root.hidden=false;status('Раздел открыт. Функции, требующие подключения сервера, отключены.');
}catch(e){root.replaceChildren();root.hidden=true;status(message(e));}
