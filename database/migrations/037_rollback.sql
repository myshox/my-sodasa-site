-- 還原：刪除 037 的臨時政策
DROP POLICY IF EXISTS "Temp allow all view donations" ON donations;
