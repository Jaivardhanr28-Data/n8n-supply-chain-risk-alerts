// Format KPIs — Capstone 2: Weekly Risk Report
// Turns the one SQL row into readable text tables. The AI only ever sees THIS text.
const k = $input.first().json;
const arr = v => Array.isArray(v) ? v : (typeof v === 'string' ? JSON.parse(v || '[]') : []);
const byItem = arr(k.by_item), byRegion = arr(k.by_region), byCat = arr(k.by_category);
const trend = arr(k.weekly_trend), top = arr(k.top_articles);
const today = new Date().toISOString().slice(0, 10);

const lines = [];
lines.push(`WEEKLY SUPPLY RISK KPIs (generated ${today}, source: SQL on risk_articles)`);
lines.push('');
lines.push(`Articles scored: ${k.articles_scored} | HIGH: ${k.high_risk} | MEDIUM: ${k.medium_risk} | LOW: ${k.low_risk} | Needs review: ${k.needs_review} | Alerts sent: ${k.alerts_sent}`);
lines.push('');
lines.push('By watch item (articles / HIGH / avg score / max score):');
byItem.forEach(r => lines.push(`- ${r.watch_item}: ${r.articles} / ${r.high_risk} / ${r.avg_score} / ${r.max_score}`));
lines.push('');
lines.push('By region (articles / HIGH / avg score):');
byRegion.forEach(r => lines.push(`- ${r.region}: ${r.articles} / ${r.high_risk} / ${r.avg_score}`));
lines.push('');
lines.push('By risk category, relevant only (articles / HIGH):');
if (byCat.length === 0) lines.push('- none');
byCat.forEach(r => lines.push(`- ${r.risk_category}: ${r.articles} / ${r.high_risk}`));
lines.push('');
lines.push('Weekly trend (week start: articles / HIGH / week-over-week change in HIGH):');
trend.forEach(r => lines.push(`- ${r.week_start}: ${r.articles} / ${r.high_risk} / ${r.wow_change === null ? 'n/a' : r.wow_change}`));
lines.push('');
lines.push('Top 3 articles by risk score:');
top.forEach(r => lines.push(`- [${r.risk_score} ${r.risk_level}] ${r.watch_item}: ${r.title}`));

return [{ json: { kpi_text: lines.join('\n'), report_date: today, high_risk: Number(k.high_risk) } }];
