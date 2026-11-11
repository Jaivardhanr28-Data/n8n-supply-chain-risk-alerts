// Number check — Capstone 2: Weekly Risk Report  (guardrail: numbers must come from SQL, never from the AI)
// Every number in the AI summary must appear in the SQL KPI text. Otherwise the summary is withheld.
const kpi = $('Format KPIs').first().json;
const summary = String($input.first().json.text || '').trim();

const nums = s => (String(s).match(/\d+(?:[.,]\d+)*/g) || [])
  .map(n => n.replace(/,/g, ''))
  .map(n => String(Number(n)));                     // "85.0" -> "85", "1,03,892" -> "103892"
const allowed = new Set(nums(kpi.kpi_text));
const found = nums(summary);
const unverified = [...new Set(found.filter(n => !allowed.has(n)))];
const verified = unverified.length === 0;

const shown = verified
  ? summary
  : `⚠ AI summary withheld: it contained numbers not found in the SQL results (${unverified.join(', ')}). See the KPI tables below.`;

const body = [
  `Weekly Supply Risk Report: ${kpi.report_date}`,
  '',
  'SUMMARY (AI-written, numbers verified against SQL)',
  shown,
  '',
  '----------------------------------------',
  kpi.kpi_text,
  '----------------------------------------',
  `Number check: ${verified ? 'PASSED' : 'FAILED'} (${found.length} numbers in summary, ${unverified.length} unverified)`,
  'Supply Risk Scanner (n8n + Gemini + Supabase).'
].join('\n');

return [{ json: {
  subject: `Weekly Supply Risk Report: ${kpi.report_date} (HIGH: ${kpi.high_risk})`,
  body, verified, unverified_numbers: unverified.join(', ')
}}];
