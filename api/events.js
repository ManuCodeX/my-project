// Vercel serverless function: proxies Ticketmaster Discovery so the API key stays on the server.
// Set TICKETMASTER_KEY in Vercel > Project > Settings > Environment Variables (free key from developer.ticketmaster.com).
module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 's-maxage=900, stale-while-revalidate=3600');
  const key = process.env.TICKETMASTER_KEY;
  const cc = String((req.query && req.query.country) || 'GH').toUpperCase().replace(/[^A-Z]/g, '').slice(0, 2) || 'GH';
  if (!key) return res.status(200).json({ events: [], note: 'no key' });
  try {
    const url = 'https://app.ticketmaster.com/discovery/v2/events.json?size=40&sort=date,asc&countryCode=' + cc + '&apikey=' + encodeURIComponent(key);
    const r = await fetch(url);
    if (!r.ok) return res.status(200).json({ events: [], note: 'upstream ' + r.status });
    const j = await r.json();
    const list = ((j._embedded && j._embedded.events) || []).map(e => {
      const v = e._embedded && e._embedded.venues && e._embedded.venues[0];
      const loc = v && v.location;
      const when = e.dates && e.dates.start && (e.dates.start.dateTime || (e.dates.start.localDate ? e.dates.start.localDate + 'T20:00:00Z' : null));
      if (!v || !loc || !when) return null;
      return { id: 'tm_' + e.id, name: String(e.name).slice(0, 80), venue: String(v.name).slice(0, 80), lat: parseFloat(loc.latitude), lng: parseFloat(loc.longitude), starts_at: when };
    }).filter(x => x && isFinite(x.lat) && isFinite(x.lng));
    res.status(200).json({ events: list });
  } catch (e) {
    res.status(200).json({ events: [], note: 'error' });
  }
};
