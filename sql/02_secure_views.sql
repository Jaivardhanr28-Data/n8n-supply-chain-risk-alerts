-- A2_secure_views.sql : make the KPI/eval views respect RLS (removes the "UNRESTRICTED" badge)
-- security_invoker = the view runs with the CALLER's permissions, so table RLS applies.
ALTER VIEW v_kpi_by_region        SET (security_invoker = true);
ALTER VIEW v_kpi_by_item          SET (security_invoker = true);
ALTER VIEW v_kpi_by_category      SET (security_invoker = true);
ALTER VIEW v_kpi_weekly_trend     SET (security_invoker = true);
ALTER VIEW v_eval_alert_precision SET (security_invoker = true);
-- Checkpoint: ai_reader can still read the KPIs (expect a number, no error)
SELECT COUNT(*) AS kpi_rows_visible FROM v_kpi_by_item;
