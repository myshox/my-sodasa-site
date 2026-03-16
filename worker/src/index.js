/**
 * Soda Recharge - Cloudflare Worker
 * 連接 MySQL 遊戲資料庫，提供玩家查詢、儲值等 API
 *
 * API 端點：
 *   GET  /debug/tables          → 列出所有資料表（部署後先呼叫確認 schema）
 *   GET  /debug/schema/:table   → 查看指定資料表的欄位結構
 *   GET  /master/:name          → 查詢主帳號旗下角色
 *   GET  /player/:cdkey         → 查詢角色資料（by CDKEY）
 *   GET  /stats                 → 伺服器整體統計
 *   GET  /vip                   → VIP 玩家排行 TOP 10
 *   POST /                      → 儲值（發放金幣/水晶）
 */

import mysql from 'mysql2/promise';

// ─────────────────────────────────────────────
// ★ 資料表名稱設定（如不符請修改後重新 deploy）
// ─────────────────────────────────────────────
const TABLE = {
  // 主帳號（登入帳號）
  account:   'accounts',
  // 角色資料（charName、gold、crystal…）
  character: 'characters',
  // 儲值/付費紀錄
  paydata:   'paydata',
};

// ─────────────────────────────────────────────
// ★ 欄位名稱對應（如資料庫欄位不同請修改）
// ─────────────────────────────────────────────
const COL = {
  // accounts 表
  acc_name:    'account_name',   // 主帳號名稱
  acc_banned:  'is_banned',      // 封號旗標（0=正常 1=封禁）
  acc_created: 'created_at',     // 建立時間

  // characters 表
  char_account:  'account_name', // 所屬主帳號名稱（外鍵）
  char_cdkey:    'cdkey',        // 角色 CDKEY（儲值用）
  char_name:     'char_name',    // 角色名稱
  char_gold:     'gold',         // 金幣
  char_crystal:  'crystal',      // 水晶
  char_online:   'is_online',    // 是否在線（0/1）
  char_banned:   'is_banned',    // 角色封號

  // paydata 表
  pay_account:   'account_name', // 對應主帳號
  pay_cdkey:     'cdkey',        // 對應角色 CDKEY
  pay_twd:       'twd_amount',   // 台幣金額
  pay_gold:      'gold_given',   // 發放金幣
  pay_order:     'order_no',     // 訂單號
  pay_remark:    'remark',       // 備註
  pay_created:   'created_at',   // 建立時間
};

// ─────────────────────────────────────────────
let _pool = null;
function getPool(env) {
  if (!_pool) {
    _pool = mysql.createPool({
      host:            env.DB_HOST,
      port:            parseInt(env.DB_PORT || '3306'),
      database:        env.DB_NAME,
      user:            env.DB_USER,
      password:        env.DB_PASS,
      waitForConnections: true,
      connectionLimit: 5,
      connectTimeout:  10000,
      charset:         'utf8mb4',
    });
  }
  return _pool;
}

function cors(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}

// ─────────────────────────────────────────────
export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return cors({}, 204);
    }

    const url  = new URL(request.url);
    const path = url.pathname;
    const pool = getPool(env);

    try {
      // ── DEBUG: 列出所有資料表 ──────────────────────
      if (path === '/debug/tables') {
        const [rows] = await pool.query('SHOW TABLES');
        return cors({ tables: rows.map(r => Object.values(r)[0]) });
      }

      // ── DEBUG: 查看資料表 schema ───────────────────
      const schemaMatch = path.match(/^\/debug\/schema\/(.+)$/);
      if (schemaMatch) {
        const table = schemaMatch[1].replace(/[^a-zA-Z0-9_]/g, '');
        const [rows] = await pool.query(`DESCRIBE \`${table}\``);
        return cors({ table, columns: rows });
      }

      // ── GET /master/:name ─────────────────────────
      const masterMatch = path.match(/^\/master\/(.+)$/);
      if (masterMatch && request.method === 'GET') {
        const name = decodeURIComponent(masterMatch[1]);
        const [chars] = await pool.query(
          `SELECT
             c.\`${COL.char_cdkey}\`   AS \`account\`,
             c.\`${COL.char_name}\`    AS \`charName\`,
             c.\`${COL.char_online}\`  AS \`isOnline\`,
             c.\`${COL.char_gold}\`    AS \`gold\`,
             COALESCE(SUM(p.\`${COL.pay_twd}\`), 0) AS \`payTotal\`
           FROM \`${TABLE.character}\` c
           LEFT JOIN \`${TABLE.paydata}\` p
             ON p.\`${COL.pay_cdkey}\` = c.\`${COL.char_cdkey}\`
           WHERE c.\`${COL.char_account}\` = ?
           GROUP BY c.\`${COL.char_cdkey}\`
           ORDER BY \`payTotal\` DESC`,
          [name]
        );
        if (!chars.length) {
          return cors({ message: `找不到主帳號「${name}」` }, 404);
        }
        return cors({
          masterName: name,
          chars: chars.map(c => ({
            account:  c.account,
            charName: c.charName,
            isOnline: !!c.isOnline,
            gold:     Number(c.gold) || 0,
            payTotal: Number(c.payTotal) || 0,
          })),
        });
      }

      // ── GET /player/:cdkey ────────────────────────
      const playerMatch = path.match(/^\/player\/(.+)$/);
      if (playerMatch && request.method === 'GET') {
        const cdkey = decodeURIComponent(playerMatch[1]);
        const [[char]] = await pool.query(
          `SELECT
             c.\`${COL.char_cdkey}\`    AS \`account\`,
             c.\`${COL.char_name}\`     AS \`charName\`,
             c.\`${COL.char_account}\`  AS \`masterName\`,
             c.\`${COL.char_online}\`   AS \`isOnline\`,
             c.\`${COL.char_gold}\`     AS \`gold\`,
             COALESCE(SUM(p.\`${COL.pay_twd}\`), 0) AS \`payTotal\`
           FROM \`${TABLE.character}\` c
           LEFT JOIN \`${TABLE.paydata}\` p
             ON p.\`${COL.pay_cdkey}\` = c.\`${COL.char_cdkey}\`
           WHERE c.\`${COL.char_cdkey}\` = ?
           GROUP BY c.\`${COL.char_cdkey}\`
           LIMIT 1`,
          [cdkey]
        );
        if (!char) {
          return cors({ message: `找不到帳號「${cdkey}」` }, 404);
        }
        const payTotal = Number(char.payTotal) || 0;
        return cors({
          account:    char.account,
          charName:   char.charName,
          masterName: char.masterName,
          isOnline:   !!char.isOnline,
          gold:       Number(char.gold) || 0,
          payTotal,
          vipLevel:   payTotal >= 15000 ? 2 : payTotal >= 5000 ? 1 : 0,
        });
      }

      // ── GET /stats ────────────────────────────────
      if (path === '/stats') {
        const [[totals]]  = await pool.query(`SELECT COUNT(*) AS total, SUM(\`${COL.acc_banned}\`) AS banned FROM \`${TABLE.account}\``);
        const [[online]]  = await pool.query(`SELECT COUNT(*) AS cnt FROM \`${TABLE.character}\` WHERE \`${COL.char_online}\` = 1`);
        const [[newToday]]= await pool.query(
          `SELECT COUNT(*) AS cnt FROM \`${TABLE.account}\` WHERE DATE(\`${COL.acc_created}\`) = CURDATE()`
        );
        const [[golds]]   = await pool.query(`SELECT COALESCE(SUM(\`${COL.char_gold}\`),0) AS total FROM \`${TABLE.character}\``);
        const [[crystals]]= await pool.query(`SELECT COALESCE(SUM(\`${COL.char_crystal}\`),0) AS total FROM \`${TABLE.character}\``).catch(() => [[{ total: 0 }]]);

        return cors({
          onlinePlayers: Number(online.cnt)     || 0,
          totalPlayers:  Number(totals.total)   || 0,
          newToday:      Number(newToday.cnt)   || 0,
          bannedPlayers: Number(totals.banned)  || 0,
          totalGold:     Number(golds.total)    || 0,
          totalCrystal:  Number(crystals.total) || 0,
        });
      }

      // ── GET /vip ──────────────────────────────────
      if (path === '/vip') {
        const [rows] = await pool.query(
          `SELECT
             c.\`${COL.char_cdkey}\`    AS \`account\`,
             c.\`${COL.char_name}\`     AS \`charName\`,
             c.\`${COL.char_account}\`  AS \`masterName\`,
             c.\`${COL.char_online}\`   AS \`isOnline\`,
             c.\`${COL.char_gold}\`     AS \`gold\`,
             COALESCE(SUM(p.\`${COL.pay_twd}\`), 0) AS \`payTotal\`
           FROM \`${TABLE.character}\` c
           LEFT JOIN \`${TABLE.paydata}\` p
             ON p.\`${COL.pay_cdkey}\` = c.\`${COL.char_cdkey}\`
           GROUP BY c.\`${COL.char_cdkey}\`
           ORDER BY \`payTotal\` DESC
           LIMIT 10`
        );
        return cors(rows.map(r => ({
          account:    r.account,
          charName:   r.charName,
          masterName: r.masterName,
          isOnline:   !!r.isOnline,
          gold:       Number(r.gold) || 0,
          payTotal:   Number(r.payTotal) || 0,
        })));
      }

      // ── POST / → 儲值 ─────────────────────────────
      if (path === '/' && request.method === 'POST') {
        const body = await request.json().catch(() => ({}));
        const { account, twdAmount, goldAmount, crystalAmount, orderNo, updatePaydata, remark } = body;

        if (!account) return cors({ message: '缺少 account 參數' }, 400);
        if (!goldAmount && !crystalAmount) return cors({ message: '金幣或水晶至少填一項' }, 400);

        // 確認角色存在
        const [[char]] = await pool.query(
          `SELECT \`${COL.char_cdkey}\`, \`${COL.char_name}\`, \`${COL.char_account}\` FROM \`${TABLE.character}\` WHERE \`${COL.char_cdkey}\` = ? LIMIT 1`,
          [account]
        );
        if (!char) return cors({ message: `找不到帳號「${account}」，請確認 CDKEY 是否正確` }, 404);

        // 發放金幣
        if (goldAmount > 0) {
          await pool.query(
            `UPDATE \`${TABLE.character}\` SET \`${COL.char_gold}\` = \`${COL.char_gold}\` + ? WHERE \`${COL.char_cdkey}\` = ?`,
            [goldAmount, account]
          );
        }

        // 發放水晶
        if (crystalAmount > 0) {
          await pool.query(
            `UPDATE \`${TABLE.character}\` SET \`${COL.char_crystal}\` = \`${COL.char_crystal}\` + ? WHERE \`${COL.char_cdkey}\` = ?`,
            [crystalAmount, account]
          );
        }

        // 寫入儲值紀錄
        if (updatePaydata !== false) {
          await pool.query(
            `INSERT INTO \`${TABLE.paydata}\`
               (\`${COL.pay_account}\`, \`${COL.pay_cdkey}\`, \`${COL.pay_twd}\`,
                \`${COL.pay_gold}\`, \`${COL.pay_order}\`, \`${COL.pay_remark}\`, \`${COL.pay_created}\`)
             VALUES (?, ?, ?, ?, ?, ?, NOW())`,
            [
              char[COL.char_account] || account,
              account,
              twdAmount || 0,
              goldAmount || 0,
              orderNo || `CF-${Date.now()}`,
              remark || '系統儲值',
            ]
          );
        }

        return cors({
          success: true,
          message: `✅ 儲值成功：${account} +${goldAmount || 0} 金幣${crystalAmount ? ` +${crystalAmount} 水晶` : ''}`,
          account,
          charName: char[COL.char_name] || account,
          goldGiven:    goldAmount    || 0,
          crystalGiven: crystalAmount || 0,
        });
      }

      return cors({ message: '找不到此 API 路徑' }, 404);

    } catch (err) {
      console.error('[Worker Error]', err);
      return cors({ message: err.message || '伺服器內部錯誤', stack: err.stack }, 500);
    }
  },
};
