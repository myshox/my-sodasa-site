-- ============================================
-- ⚠️ 僅供排查用 - 暫時允許所有人讀取 donations
-- ============================================
-- 若 036 仍無效，執行此檔案可暫時顯示紀錄
-- 確認後請立即執行 037_rollback.sql 還原
-- ============================================

DROP POLICY IF EXISTS "Temp allow all view donations" ON donations;
CREATE POLICY "Temp allow all view donations"
  ON donations FOR SELECT
  USING (true);
