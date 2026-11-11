// Validate AI output — Capstone 2: Supply Risk Scanner  (guardrail G3)
// Joins each AI answer back to its article, checks the JSON, and decides the risk level by RULE (not by the AI).
const ai = $input.all();
const arts = $('Flatten articles').all();
const ALLOWED = ['strike','natural_disaster','port_congestion','geopolitical','regulatory',
                 'supplier_financial','cyber_attack','other','not_relevant'];

function parse(text) {
  if (!text) return null;
  const clean = String(text).replace(/```json|```/gi, '').trim();
  const m = clean.match(/\{[\s\S]*\}/);            // first {...} block
  if (!m) return null;
  try { return JSON.parse(m[0]); } catch (e) { return null; }
}

return ai.map((r, i) => {
  const idx = (r.pairedItem && typeof r.pairedItem.item === 'number') ? r.pairedItem.item : i;
  const a = (arts[idx] || arts[i]).json;
  const p = parse(r.json.text);

  let score = p ? Number(p.risk_score) : NaN;
  let cat   = p ? String(p.risk_category || '').trim().toLowerCase() : '';
  let reason = p ? String(p.reason || '').slice(0, 300) : '';

  // Checks: valid JSON, integer score 0-100, category from the allowed list
  const valid = p !== null && Number.isFinite(score) && score >= 0 && score <= 100 && ALLOWED.includes(cat);

  let level = null;
  if (valid) {
    score = Math.round(score);
    if (cat === 'not_relevant' && score > 39) score = 39;   // irrelevant news can never alert
    level = score >= 70 ? 'HIGH' : score >= 40 ? 'MEDIUM' : 'LOW';
  }

  return { json: {
    watch_item:    a.watch_item,
    region:        a.region,
    title:         a.title,
    source:        a.source,
    url:           a.url,
    published_at:  a.published_at,
    description:   a.description,
    risk_score:    valid ? score : null,
    risk_level:    level,
    risk_category: valid ? cat : null,
    reason:        valid ? reason : 'AI output failed validation: ' + String(r.json.text || '').slice(0, 150),
    needs_review:  !valid,
    alert_sent:    false
  }};
});
