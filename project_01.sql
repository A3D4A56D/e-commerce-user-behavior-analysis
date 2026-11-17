-- ============================================================
-- 项目：电商用户行为数据分析（Taobao UserBehavior）
-- 环境：Aiven MySQL 8.4，库 defaultdb，表 user_behavior
-- 数据：50 万条行为记录（2017-11-24 ~ 2017-12-03 为主）
-- 说明：每段可单独执行；表内 id 为自增主键，timestamp 为 Unix 秒
-- ============================================================

-- ------------------------------------------------------------
-- ① 行为类型分布：pv（浏览）/ cart（加购）/ fav（收藏）/ buy（购买）
-- 业务含义：先看清这份数据里各类行为各占多少，判断数据是否可用
-- ------------------------------------------------------------
SELECT behavior_type,
       COUNT(*)               AS behavior_cnt,
       COUNT(DISTINCT user_id) AS user_cnt
FROM user_behavior
GROUP BY behavior_type
ORDER BY behavior_cnt DESC;


-- ------------------------------------------------------------
-- ② 按天 PV 趋势：数据覆盖了哪些天、每天多少流量
-- 业务含义：看流量是否均匀，是否有大促脉冲；异常早于起始日的记录会在这里暴露
-- ------------------------------------------------------------
SELECT DATE(FROM_UNIXTIME(timestamp)) AS log_date,
       COUNT(*)                       AS pv_cnt
FROM user_behavior
GROUP BY log_date
ORDER BY log_date;


-- ------------------------------------------------------------
-- ③ 转化漏斗（用户-日口径）
-- 定义：同一用户、同一自然日内，是否发生过 pv / cart / buy
-- 注意：只统计"是否发生"，不要求时间先后，因此不等于会话级漏斗
-- 业务含义：定位流失最严重的一层，决定运营侧重"促加购"还是"催下单"
-- ------------------------------------------------------------
WITH user_day AS (
    SELECT user_id,
           DATE(FROM_UNIXTIME(timestamp)) AS d,
           MAX(behavior_type = 'pv')       AS did_pv,
           MAX(behavior_type = 'cart')     AS did_cart,
           MAX(behavior_type = 'buy')      AS did_buy
    FROM user_behavior
    GROUP BY user_id, d
)
SELECT SUM(did_pv)                                     AS pv_user_days,    -- 有浏览的用户日
       SUM(did_cart)                                   AS cart_user_days,  -- 有加购的用户日
       SUM(did_buy)                                    AS buy_user_days,   -- 有购买的用户日
       ROUND(SUM(did_cart) * 100.0 / SUM(did_pv), 2)   AS pv_to_cart_pct,  -- 浏览→加购
       ROUND(SUM(did_buy)  * 100.0 / SUM(did_pv), 2)   AS pv_to_buy_pct    -- 浏览→购买
FROM user_day;


-- ------------------------------------------------------------
-- ④ 每个用户最后一次行为（窗口函数）
-- 业务含义：识别"最后一步停在哪"的用户，用于召回；也演示 ROW_NUMBER 分组取首行
-- ------------------------------------------------------------
SELECT user_id,
       behavior_type,
       FROM_UNIXTIME(timestamp) AS last_action_time
FROM (
    SELECT user_id,
           behavior_type,
           timestamp,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY timestamp DESC) AS rn
    FROM user_behavior
) t
WHERE rn = 1
LIMIT 10;


-- ------------------------------------------------------------
-- 附：数据量校验
-- ------------------------------------------------------------
SELECT COUNT(*) AS total_rows FROM user_behavior;
