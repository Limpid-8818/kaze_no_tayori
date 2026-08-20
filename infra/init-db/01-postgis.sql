-- PostGIS extension 装在 public，供各 schema 通过 search_path 共用。
-- 只在数据库首次初始化时执行一次。
CREATE EXTENSION IF NOT EXISTS postgis;
