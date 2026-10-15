self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
self.addEventListener('push',e=>{
  let d={};try{d=e.data?e.data.json():{};}catch(x){}
  e.waitUntil(self.registration.showNotification(d.title||'Pull Up',{body:d.body||'',icon:'/icon-192.png',badge:'/icon-192.png',tag:d.tag,data:{url:d.url||'/'}}));
});
self.addEventListener('notificationclick',e=>{
  e.notification.close();
  e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(l=>{
    for(const c of l){if('focus' in c)return c.focus();}
    return self.clients.openWindow((e.notification.data&&e.notification.data.url)||'/');
  }));
});
