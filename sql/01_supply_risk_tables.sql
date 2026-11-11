-- A1_supply_risk_tables.sql
-- Advanced Capstone #12: Supply Chain Disruption Alert System
-- Creates: watchlist (what we monitor), risk_articles (AI-scored news),
--          4 KPI views, 1 eval view. Gives ai_reader READ access for the weekly report.
-- Safe to re-run.

DROP VIEW IF EXISTS v_eval_alert_precision, v_kpi_weekly_trend, v_kpi_by_category, v_kpi_by_item, v_kpi_by_region;
DROP TABLE IF EXISTS risk_articles;
DROP TABLE IF EXISTS watchlist;

-- 1) What we monitor (the electronics supply chain = 52% of store net revenue)
CREATE TABLE watchlist (
  id            SERIAL PRIMARY KEY,
  item_name     TEXT NOT NULL,
  item_type     TEXT CHECK (item_type IN ('supplier','port','route','region')),
  region        TEXT NOT NULL,
  category      TEXT NOT NULL DEFAULT 'Electronics',
  search_query  TEXT NOT NULL,            -- NewsAPI search (AND / OR / quotes allowed)
  active        BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO watchlist (item_name, item_type, region, search_query) VALUES
 ('Foxconn',               'supplier', 'Taiwan / China', 'Foxconn AND (strike OR fire OR shutdown OR disruption OR shortage)'),
 ('Semiconductor supply',  'supplier', 'Taiwan',         '(semiconductor OR chip) AND (shortage OR disruption OR earthquake OR export ban)'),
 ('Chennai Port',          'port',     'India - South',  '"Chennai port" AND (congestion OR strike OR cyclone OR closure OR delay)'),
 ('JNPT / Nhava Sheva',    'port',     'India - West',   '(JNPT OR "Nhava Sheva") AND (congestion OR strike OR delay OR closure)'),
 ('Red Sea shipping',      'route',    'Middle East',    '"Red Sea" AND (shipping OR container) AND (attack OR disruption OR diversion)'),
 ('Shenzhen manufacturing','region',   'China',          'Shenzhen AND (factory OR port OR typhoon OR lockdown OR shortage)');

-- 2) Every article the AI scored
CREATE TABLE risk_articles (
  id             BIGSERIAL PRIMARY KEY,
  scanned_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  watch_item     TEXT NOT NULL,
  region         TEXT,
  title          TEXT NOT NULL,
  source         TEXT,
  url            TEXT NOT NULL UNIQUE,      -- duplicate guard: same article never stored/alerted twice
  published_at   TIMESTAMPTZ,
  description    TEXT,
  risk_score     INTEGER CHECK (risk_score BETWEEN 0 AND 100),
  risk_level     TEXT CHECK (risk_level IN ('LOW','MEDIUM','HIGH')),
  risk_category  TEXT CHECK (risk_category IN ('strike','natural_disaster','port_congestion','geopolitical',
                                               'regulatory','supplier_financial','cyber_attack','other','not_relevant')),
  reason         TEXT,
  needs_review   BOOLEAN NOT NULL DEFAULT false,   -- AI output failed validation
  alert_sent     BOOLEAN NOT NULL DEFAULT false,
  human_label    TEXT CHECK (human_label IN ('HIGH','NOT_HIGH'))   -- filled in during eval
);

-- 3) KPI views (the analyst layer: numbers come from SQL, never from the AI)
CREATE VIEW v_kpi_by_region AS
SELECT region,
       COUNT(*)                                        AS articles,
       COUNT(*) FILTER (WHERE risk_level = 'HIGH')     AS high_risk,
       ROUND(AVG(risk_score), 1)                       AS avg_score
FROM risk_articles WHERE NOT needs_review
GROUP BY region ORDER BY high_risk DESC, avg_score DESC;

CREATE VIEW v_kpi_by_item AS
SELECT watch_item,
       COUNT(*)                                        AS articles,
       COUNT(*) FILTER (WHERE risk_level = 'HIGH')     AS high_risk,
       ROUND(AVG(risk_score), 1)                       AS avg_score,
       MAX(risk_score)                                 AS max_score
FROM risk_articles WHERE NOT needs_review
GROUP BY watch_item ORDER BY high_risk DESC, avg_score DESC;

CREATE VIEW v_kpi_by_category AS
SELECT risk_category,
       COUNT(*)                                        AS articles,
       COUNT(*) FILTER (WHERE risk_level = 'HIGH')     AS high_risk
FROM risk_articles WHERE NOT needs_review AND risk_category <> 'not_relevant'
GROUP BY risk_category ORDER BY high_risk DESC, articles DESC;

CREATE VIEW v_kpi_weekly_trend AS
WITH w AS (
  SELECT date_trunc('week', published_at)::date AS week_start,
         COUNT(*) FILTER (WHERE risk_level = 'HIGH') AS high_risk,
         COUNT(*)                                    AS articles
  FROM risk_articles WHERE NOT needs_review AND published_at IS NOT NULL
  GROUP BY 1
)
SELECT week_start, articles, high_risk,
       high_risk - LAG(high_risk) OVER (ORDER BY week_start) AS wow_change
FROM w ORDER BY week_start;

-- 4) Eval view: alert precision / recall vs human labels
CREATE VIEW v_eval_alert_precision AS
SELECT
  COUNT(*) FILTER (WHERE human_label IS NOT NULL)                                       AS labelled,
  COUNT(*) FILTER (WHERE risk_level = 'HIGH' AND human_label IS NOT NULL)               AS ai_high,
  COUNT(*) FILTER (WHERE risk_level = 'HIGH' AND human_label = 'HIGH')                  AS true_positive,
  COUNT(*) FILTER (WHERE human_label = 'HIGH')                                          AS human_high,
  ROUND(100.0 * COUNT(*) FILTER (WHERE risk_level = 'HIGH' AND human_label = 'HIGH')
        / NULLIF(COUNT(*) FILTER (WHERE risk_level = 'HIGH' AND human_label IS NOT NULL), 0), 1) AS precision_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE risk_level = 'HIGH' AND human_label = 'HIGH')
        / NULLIF(COUNT(*) FILTER (WHERE human_label = 'HIGH'), 0), 1)                   AS recall_pct
FROM risk_articles;

-- 5) Security: RLS on, ai_reader may only READ (used by the weekly report)
ALTER TABLE watchlist     ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_articles ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON watchlist, risk_articles,
      v_kpi_by_region, v_kpi_by_item, v_kpi_by_category, v_kpi_weekly_trend, v_eval_alert_precision
      TO ai_reader;
CREATE POLICY ai_reader_select ON watchlist     FOR SELECT TO ai_reader USING (true);
CREATE POLICY ai_reader_select ON risk_articles FOR SELECT TO ai_reader USING (true);

-- Checkpoint: expect  6 | 0 | true | false
SELECT
  (SELECT COUNT(*) FROM watchlist)     AS watchlist_items,
  (SELECT COUNT(*) FROM risk_articles) AS articles_now,
  has_table_privilege('ai_reader', 'v_kpi_by_region', 'SELECT') AS ai_reader_can_read_kpis,
  has_table_privilege('ai_reader', 'risk_articles',   'INSERT') AS ai_reader_can_insert;
