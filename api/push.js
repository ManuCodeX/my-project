// Vercel serverless function: sends web-push notifications for ride requests, answers and chat.
// Env vars (Vercel > Settings > Environment Variables):
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY   (generate: npx web-push generate-vapid-keys)
//   SUPABASE_URL, SUPABASE_SERVICE_KEY    (service_role key, server only, never in the page)
// The caller must be signed in and be a real participant of the request, so nobody can notify arbitrary users.
const webpush = require('web-push');
const J = (res, code, o) => res.status(code).json(o);

module.exports = async (req, res) => {
  const pub = process.env.VAPID_PUBLIC_KEY, priv = process.env.VAPID_PRIVATE_KEY;
  const url = process.env.SUPABASE_URL, svc = process.env.SUPABASE_SERVICE_KEY;
  if (req.method === 'GET') return J(res, 200, { key: pub || '' });
  if (req.method !== 'POST') return J(res, 405, { error: 'method' });
  if (!pub || !priv || !url || !svc) return J(res, 200, { sent: 0, note: 'not configured' });
  try {
    const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    if (!token) return J(res, 401, { error: 'auth' });
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    const type = String(body.type || ''), ref = String(body.ref || '');
    if (!/^[0-9a-f-]{36}$/i.test(ref) || !['request', 'accepted', 'declined', 'chat'].includes(type)) return J(res, 400, { error: 'bad' });
    const H = { apikey: svc, Authorization: 'Bearer ' + svc };
    const ur = await fetch(url + '/auth/v1/user', { headers: { apikey: svc, Authorization: 'Bearer ' + token } });
    if (!ur.ok) return J(res, 401, { error: 'auth' });
    const me = (await ur.json()).id;
    const rr = await fetch(url + '/rest/v1/requests?id=eq.' + ref + '&select=id,rider_id,status,plan:plans(host_id)', { headers: H });
    const row = rr.ok ? (await rr.json())[0] : null;
    if (!row || !row.plan) return J(res, 404, { error: 'none' });
    const rider = row.rider_id, host = row.plan.host_id;
    let to = null, title = 'Pull Up', text = '', link = '/';
    if (type === 'request' && me === rider && row.status === 'pending') { to = host; title = 'New ride request'; text = 'Someone wants to ride with you. Open Pull Up to see.'; }
    else if (type === 'accepted' && me === host && row.status === 'accepted') { to = rider; title = 'You are in'; text = 'Your host accepted. Open Pull Up for the plate and pickup spot.'; }
    else if (type === 'declined' && me === host && row.status === 'declined') { to = rider; title = 'Request update'; text = 'This host cannot take you tonight. Other plans may be nearby.'; }
    else if (type === 'chat' && (me === rider || me === host) && row.status === 'accepted') { to = me === rider ? host : rider; title = 'New message'; text = 'You have a message about tonight’s ride.'; }
    if (!to) return J(res, 403, { error: 'not allowed' });
    const sr = await fetch(url + '/rest/v1/push_subs?user_id=eq.' + to + '&select=endpoint,p256dh,auth', { headers: H });
    const subs = sr.ok ? await sr.json() : [];
    webpush.setVapidDetails('mailto:hello@pullup.app', pub, priv);
    const payload = JSON.stringify({ title, body: text, url: link, tag: type + ref });
    let sent = 0;
    await Promise.all(subs.map(async s => {
      try { await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 3600 }); sent++; }
      catch (e) { if (e && (e.statusCode === 404 || e.statusCode === 410)) await fetch(url + '/rest/v1/push_subs?endpoint=eq.' + encodeURIComponent(s.endpoint), { method: 'DELETE', headers: H }); }
    }));
    return J(res, 200, { sent });
  } catch (e) { return J(res, 200, { sent: 0, note: 'error' }); }
};
