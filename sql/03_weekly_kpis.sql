-- B1_weekly_kpis.sql  (used inside n8n "Get KPIs (SQL)" node, runs as read-only ai_reader)
-- One row with every KPI the weekly report needs. All numbers come from here, never from the AI.
SELECT
  (SELECT COUNT(*) FROM risk_articles WHERE NOT needs_review)                          AS articles_scored,
  (SELECT COUNT(*) FROM risk_articles WHERE NOT needs_review AND risk_level = 'HIGH')   AS high_risk,
  (SELECT COUNT(*) FROM risk_articles WHERE NOT needs_review AND risk_level = 'MEDIUM') AS medium_risk,
  (SELECT COUNT(*) FROM risk_articles WHERE NOT needs_review AND risk_level = 'LOW')    AS low_risk,
  (SELECT COUNT(*) FROM risk_articles WHERE needs_review)                               AS needs_review,
  (SELECT COUNT(*) FROM risk_articles WHERE alert_sent)                                 AS alerts_sent,
  (SELECT COALESCE(json_agg(t), '[]') FROM v_kpi_by_item t)      AS by_item,
  (SELECT COALESCE(json_agg(t), '[]') FROM v_kpi_by_region t)    AS by_region,
  (SELECT COALESCE(json_agg(t), '[]') FROM v_kpi_by_category t)  AS by_category,
  (SELECT COALESCE(json_agg(t), '[]') FROM v_kpi_weekly_trend t) AS weekly_trend,
  (SELECT COALESCE(json_agg(t), '[]') FROM (
       SELECT watch_item, risk_score, risk_level, title, url
       FROM risk_articles WHERE NOT needs_review
       ORDER BY risk_score DESC, published_at DESC LIMIT 3) t)  AS top_articles;
