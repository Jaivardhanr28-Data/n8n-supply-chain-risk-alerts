// Flatten articles — Capstone 2: Supply Risk Scanner
// Input: one NewsAPI response per watchlist item (6 items).
// Output: ONE item per article, tagged with its watchlist item. Removes duplicates and empty/removed articles.
const watch = $('Read watchlist').all();
const results = $input.all();
const seen = new Set();
const out = [];

results.forEach((r, i) => {
  const idx = (r.pairedItem && typeof r.pairedItem.item === 'number') ? r.pairedItem.item : i;
  const w = (watch[idx] || watch[i]).json;
  const articles = Array.isArray(r.json.articles) ? r.json.articles : [];
  for (const a of articles) {
    if (!a || !a.url || !a.title || a.title === '[Removed]') continue;   // skip removed/empty
    if (seen.has(a.url)) continue;                                      // same article found by 2 searches
    seen.add(a.url);
    out.push({ json: {
      watch_item:   w.item_name,
      region:       w.region,
      item_type:    w.item_type,
      title:        String(a.title).slice(0, 300),
      source:       a.source && a.source.name ? a.source.name : null,
      url:          a.url,
      published_at: a.publishedAt || null,
      description:  String(a.description || '').slice(0, 600)        // keep tokens (and cost) low
    }});
  }
});

return out;   // 0 articles -> workflow simply stops here
