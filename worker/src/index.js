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
// 蘇打石器 GM 資料庫表名（已對齊真實 schema）
// ─────────────────────────────────────────────
const TABLE = {
  master:    'csaloginmaster',
  character: 'csalogin',
  paydata:   'paydata',
  // recharge_orders：站內儲值訂單歷史
  recharge:  'recharge_orders',
  // vippointlog：VipPoint（=遊戲內金幣／元寶）變動紀錄
  vipplog:   'vippointlog',
};

const COL = {
  // csaloginmaster
  m_id:        'Id',
  m_name:      'Name',
  m_created:   'created_at',

  // csalogin
  c_id:        'Id',
  c_master:    'MasterId',
  c_cdkey:     'Name',
  c_charname:  'OnlineName',
  c_online:    'Online',
  c_gold:      'VipPoint',   // ★ 遊戲內「金幣／元寶」實際存的欄位（vippointlog 也記錄這欄變動）
  c_paytotal:  'PayTotal',
  c_vippoint:  'VipPoint',
  c_paypoint:  'PayPoint',
  c_logintime: 'LoginTime',
  c_regtime:   'RegTime',

  // paydata
  p_cdkey:     'cdkey',
  p_point:     'point',
  p_lifetime:  'lifetime_total',
  p_time:      'time',
};

// GM 資料庫角色名是「以 latin1/binary 欄位儲存的 UTF-8 bytes」，
// mysql2 連線拿出來會自動雙重轉碼變亂碼，所以改在 SQL 層轉成 HEX，
// JS 端再用 Buffer 還原為真正的 UTF-8 字串。
const u8 = (col) => `HEX(${col})`;
const decodeU8 = (hex) => {
  if (hex == null) return '';
  try {
    const buf = new Uint8Array(Math.floor(hex.length / 2));
    for (let i = 0; i < buf.length; i++) buf[i] = parseInt(hex.substr(i * 2, 2), 16);
    return new TextDecoder('utf-8', { fatal: false }).decode(buf);
  } catch { return String(hex); }
};

// ─────────────────────────────────────────────
// Supabase Admin API 操作（需 SUPABASE_SERVICE_ROLE_KEY）
// 全部 /admin/* 端點必須驗證呼叫方為 super_admin。
// ─────────────────────────────────────────────
async function verifySuperAdmin(env, accessToken) {
  if (!accessToken) return { ok: false, status: 401, msg: '缺少 access token' };
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return { ok: false, status: 500, msg: 'Worker 未設定 SUPABASE_URL 或 SUPABASE_SERVICE_ROLE_KEY' };
  }
  // 用 access token 拿目前使用者
  const meRes = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${accessToken}`,
    },
  });
  if (!meRes.ok) return { ok: false, status: 401, msg: 'access token 無效或已逾期' };
  const me = await meRes.json();
  const role = me?.user_metadata?.role || me?.app_metadata?.role;
  if (role !== 'super_admin') {
    return { ok: false, status: 403, msg: '僅超級管理員可執行此操作', user: me };
  }
  return { ok: true, user: me };
}

async function handleAdmin(request, env, path) {
  // POST /admin/reset-password   body: { email, newPassword, accessToken }
  if (path === '/admin/reset-password' && request.method === 'POST') {
    let body;
    try { body = await request.json(); } catch { return cors({ message: '無效的 JSON 內容' }, 400); }
    const { email, newPassword, accessToken } = body || {};
    if (!email || !newPassword) return cors({ message: '缺少 email 或 newPassword' }, 400);
    if (String(newPassword).length < 6) return cors({ message: '密碼至少需要 6 個字元' }, 400);

    const auth = await verifySuperAdmin(env, accessToken);
    if (!auth.ok) return cors({ message: auth.msg }, auth.status);

    // 用 email 找 user_id
    const findRes = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users?email=${encodeURIComponent(email)}`,
      {
        headers: {
          apikey: env.SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        },
      }
    );
    if (!findRes.ok) {
      const t = await findRes.text();
      return cors({ message: `查詢使用者失敗：${t}` }, 500);
    }
    const findData = await findRes.json();
    const target = (findData.users || []).find(u => (u.email || '').toLowerCase() === email.toLowerCase()) || findData.users?.[0];
    if (!target) return cors({ message: `找不到此 Email 註冊的使用者：${email}` }, 404);

    // 直接改密碼
    const updRes = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users/${target.id}`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          apikey: env.SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({ password: newPassword }),
      }
    );
    if (!updRes.ok) {
      const t = await updRes.text();
      return cors({ message: `更新密碼失敗：${t}` }, 500);
    }
    return cors({
      success: true,
      message: `✅ 已為 ${email} 設定新密碼，請通知玩家用新密碼登入`,
      adminEmail: auth.user?.email || '',
      targetEmail: email,
      targetId:    target.id,
      changedAt:   new Date().toISOString(),
    });
  }

  return cors({ message: '找不到此 admin 路徑' }, 404);
}

// ─────────────────────────────────────────────
// Cloudflare Workers 禁止跨 request 共用 I/O 物件，
// 因此每個 request 建立獨立的 connection，結束後關閉。
async function openConn(env) {
  return await mysql.createConnection({
    host:           env.DB_HOST,
    port:           parseInt(env.DB_PORT || '3306'),
    database:       env.DB_NAME,
    user:           env.DB_USER,
    password:       env.DB_PASS,
    connectTimeout: 10000,
    charset:        'utf8mb4',
    disableEval:    true,
    decimalNumbers: true,
    dateStrings:    true,
  });
}

const WORKER_VERSION = 'v2026-04-19-hexutf8';
function cors(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      'X-Worker-Version': WORKER_VERSION,
    },
  });
}

// ─────────────────────────────────────────────
export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin':  '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, X-Api-Key, Authorization',
          'Access-Control-Max-Age':       '86400',
        },
      });
    }

    const url  = new URL(request.url);
    const path = url.pathname;

    // ──────────────────────────────────────────────
    // /admin/* 端點不需要 MySQL，直接走 Supabase Admin API
    // 必須先驗證呼叫方是 super_admin
    // ──────────────────────────────────────────────
    if (path.startsWith('/admin/')) {
      return await handleAdmin(request, env, path);
    }

    let pool;
    try {
      pool = await openConn(env);
    } catch (e) {
      return cors({ message: '資料庫連線失敗：' + (e.message || e) }, 500);
    }

    try {
      // ── DEBUG: 列出所有資料表（用 information_schema，避開 SHOW TABLES 限制） ──
      if (path === '/debug/tables') {
        const [rows] = await pool.execute(
          'SELECT TABLE_NAME AS name, TABLE_ROWS AS rows FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? ORDER BY TABLE_NAME',
          [env.DB_NAME]
        );
        return cors({
          database: env.DB_NAME,
          tables: rows.map(r => ({ name: r.name, rows: Number(r.rows) || 0 })),
        });
      }

      // ── DEBUG: 查看資料表 schema ───────────────────
      const schemaMatch = path.match(/^\/debug\/schema\/(.+)$/);
      if (schemaMatch) {
        const table = schemaMatch[1].replace(/[^a-zA-Z0-9_]/g, '');
        const [rows] = await pool.execute(
          'SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT, COLUMN_COMMENT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION',
          [env.DB_NAME, table]
        );
        return cors({ table, columns: rows });
      }

      // ── DEBUG: 看資料表前 5 筆樣本（幫助對應欄位） ──
      const sampleMatch = path.match(/^\/debug\/sample\/(.+)$/);
      if (sampleMatch) {
        const table = sampleMatch[1].replace(/[^a-zA-Z0-9_]/g, '');
        const [rows] = await pool.execute(`SELECT * FROM \`${table}\` LIMIT 5`);
        return cors({ table, sample: rows });
      }

      // ── DEBUG: 任意 SELECT-only SQL ─────
      if (path === '/debug/sql' && request.method === 'POST') {
        const { sql, params } = await request.json().catch(() => ({}));
        if (!sql || !/^\s*SELECT\b/i.test(sql)) return cors({ message: '只允許 SELECT' }, 400);
        const [rows] = await pool.execute(sql, params || []);
        return cors({ rows });
      }

      // ── DEBUG: 列出資料庫所有資料表 ─────
      if (path === '/debug/tables') {
        const [rows] = await pool.execute(`SHOW TABLES`);
        return cors({ tables: rows });
      }

      // ── DEBUG: 顯示某表的欄位結構 ─────
      const descMatch = path.match(/^\/debug\/desc\/(.+)$/);
      if (descMatch) {
        const t = descMatch[1].replace(/[^a-zA-Z0-9_]/g, '');
        const [rows] = await pool.execute(`SHOW FULL COLUMNS FROM \`${t}\``);
        return cors({ table: t, columns: rows });
      }

      // ── DEBUG: 在所有表搜尋特定 CDKEY（找儲值真正寫到哪裡） ─────
      const findMatch = path.match(/^\/debug\/find\/(.+)$/);
      if (findMatch) {
        const cdkey = decodeURIComponent(findMatch[1]);
        const [tables] = await pool.execute(`SHOW TABLES`);
        const tablesKey = Object.keys(tables[0])[0];
        const found = [];
        for (const t of tables) {
          const tname = t[tablesKey];
          try {
            const [cols] = await pool.execute(`SHOW COLUMNS FROM \`${tname}\``);
            const matchCols = cols
              .filter(c => /name|cdkey|account|user|player|char/i.test(c.Field))
              .map(c => c.Field);
            if (matchCols.length === 0) continue;
            const where = matchCols.map(c => `\`${c}\` = ?`).join(' OR ');
            const params = matchCols.map(() => cdkey);
            const [hits] = await pool.execute(
              `SELECT * FROM \`${tname}\` WHERE ${where} LIMIT 3`,
              params
            );
            if (hits.length > 0) found.push({ table: tname, matchedColumns: matchCols, rows: hits });
          } catch {}
        }
        return cors({ cdkey, found });
      }

      // ── DEBUG: 查特定玩家的 paydata 儲值記錄 ─────
      const paydataMatch = path.match(/^\/debug\/paydata\/(.+)$/);
      if (paydataMatch) {
        const cdkey = decodeURIComponent(paydataMatch[1]);
        const [rows] = await pool.execute(
          `SELECT \`${COL.p_cdkey}\` AS cdkey,
                  \`${COL.p_point}\` AS point,
                  \`${COL.p_lifetime}\` AS lifetime_total,
                  \`${COL.p_time}\` AS time
           FROM \`${TABLE.paydata}\` WHERE \`${COL.p_cdkey}\` = ?`,
          [cdkey]
        );
        return cors({ cdkey, paydata: rows });
      }

      // ── GET /master/:name → 查主帳號旗下所有角色 ──
      const masterMatch = path.match(/^\/master\/(.+)$/);
      if (masterMatch && request.method === 'GET') {
        const name = decodeURIComponent(masterMatch[1]);
        const [chars] = await pool.execute(
          `SELECT
             c.\`${COL.c_cdkey}\`             AS \`account\`,
             ${u8('c.`'+COL.c_charname+'`')}  AS \`charName\`,
             c.\`${COL.c_online}\`            AS \`isOnline\`,
             c.\`${COL.c_gold}\`              AS \`gold\`,
             COALESCE(p.\`${COL.p_lifetime}\`, c.\`${COL.c_paytotal}\`, 0) AS \`payTotal\`,
             c.\`${COL.c_vippoint}\`          AS \`vipPoint\`,
             c.\`${COL.c_logintime}\`         AS \`lastLogin\`
           FROM \`${TABLE.character}\` c
           INNER JOIN \`${TABLE.master}\` m
             ON m.\`${COL.m_id}\` = c.\`${COL.c_master}\`
           LEFT JOIN \`${TABLE.paydata}\` p
             ON p.\`${COL.p_cdkey}\` = c.\`${COL.c_cdkey}\`
           WHERE m.\`${COL.m_name}\` = ?
           ORDER BY \`payTotal\` DESC`,
          [name]
        );
        if (!chars.length) {
          return cors({ message: `找不到主帳號「${name}」` }, 404);
        }
        return cors({
          masterName: name,
          chars: chars.map(c => ({
            account:   c.account,
            charName:  decodeU8(c.charName),
            isOnline:  Number(c.isOnline) === 1,
            gold:      Number(c.gold) || 0,
            payTotal:  Number(c.payTotal) || 0,
            vipPoint:  Number(c.vipPoint) || 0,
            lastLogin: c.lastLogin || null,
          })),
        });
      }

      // ── GET /player/:cdkey → 查單一角色 ───────────
      const playerMatch = path.match(/^\/player\/(.+)$/);
      if (playerMatch && request.method === 'GET') {
        const cdkey = decodeURIComponent(playerMatch[1]);
        const [rows] = await pool.execute(
          `SELECT
             c.\`${COL.c_cdkey}\`             AS \`account\`,
             ${u8('c.`'+COL.c_charname+'`')}  AS \`charName\`,
             m.\`${COL.m_name}\`              AS \`masterName\`,
             c.\`${COL.c_online}\`            AS \`isOnline\`,
             c.\`${COL.c_gold}\`              AS \`gold\`,
             COALESCE(p.\`${COL.p_lifetime}\`, c.\`${COL.c_paytotal}\`, 0) AS \`payTotal\`,
             c.\`${COL.c_vippoint}\`          AS \`vipPoint\`,
             c.\`${COL.c_paypoint}\`          AS \`payPoint\`,
             c.\`${COL.c_logintime}\`         AS \`lastLogin\`,
             c.\`${COL.c_regtime}\`           AS \`regTime\`
           FROM \`${TABLE.character}\` c
           LEFT JOIN \`${TABLE.master}\` m
             ON m.\`${COL.m_id}\` = c.\`${COL.c_master}\`
           LEFT JOIN \`${TABLE.paydata}\` p
             ON p.\`${COL.p_cdkey}\` = c.\`${COL.c_cdkey}\`
           WHERE c.\`${COL.c_cdkey}\` = ?
           LIMIT 1`,
          [cdkey]
        );
        const char = rows && rows[0];
        if (!char) {
          return cors({ message: `找不到帳號「${cdkey}」` }, 404);
        }
        const payTotal = Number(char.payTotal) || 0;
        return cors({
          account:    char.account,
          charName:   decodeU8(char.charName),
          masterName: char.masterName,
          isOnline:   Number(char.isOnline) === 1,
          gold:       Number(char.gold) || 0,
          payTotal,
          vipPoint:   Number(char.vipPoint) || 0,
          payPoint:   Number(char.payPoint) || 0,
          lastLogin:  char.lastLogin || null,
          regTime:    char.regTime  || null,
          vipLevel:   payTotal >= 15000 ? 2 : payTotal >= 5000 ? 1 : 0,
        });
      }

      // ── GET /stats → 整體統計 ─────────────────────
      if (path === '/stats') {
        const [[totals]]   = await pool.execute(`SELECT COUNT(*) AS total FROM \`${TABLE.character}\``);
        const [[online]]   = await pool.execute(`SELECT COUNT(*) AS cnt FROM \`${TABLE.character}\` WHERE \`${COL.c_online}\` = 1`);
        const [[newToday]] = await pool.execute(
          `SELECT COUNT(*) AS cnt FROM \`${TABLE.character}\` WHERE DATE(\`${COL.c_regtime}\`) = CURDATE()`
        );
        const [[golds]]    = await pool.execute(`SELECT COALESCE(SUM(\`${COL.c_gold}\`),0) AS total FROM \`${TABLE.character}\``);
        const [[masters]]  = await pool.execute(`SELECT COUNT(*) AS total FROM \`${TABLE.master}\``);

        return cors({
          onlinePlayers: Number(online.cnt)     || 0,
          totalPlayers:  Number(totals.total)   || 0,
          totalMasters:  Number(masters.total)  || 0,
          newToday:      Number(newToday.cnt)   || 0,
          totalGold:     Number(golds.total)    || 0,
        });
      }

      // ── GET /vip → 儲值排行 TOP 10（用 paydata.lifetime_total） ──
      if (path === '/vip') {
        const [rows] = await pool.execute(
          `SELECT
             c.\`${COL.c_cdkey}\`             AS \`account\`,
             ${u8('c.`'+COL.c_charname+'`')}  AS \`charName\`,
             m.\`${COL.m_name}\`              AS \`masterName\`,
             c.\`${COL.c_online}\`            AS \`isOnline\`,
             c.\`${COL.c_gold}\`              AS \`gold\`,
             COALESCE(p.\`${COL.p_lifetime}\`, c.\`${COL.c_paytotal}\`, 0) AS \`payTotal\`,
             c.\`${COL.c_vippoint}\`          AS \`vipPoint\`
           FROM \`${TABLE.character}\` c
           LEFT JOIN \`${TABLE.master}\` m
             ON m.\`${COL.m_id}\` = c.\`${COL.c_master}\`
           LEFT JOIN \`${TABLE.paydata}\` p
             ON p.\`${COL.p_cdkey}\` = c.\`${COL.c_cdkey}\`
           ORDER BY \`payTotal\` DESC
           LIMIT 10`
        );
        return cors(rows.map(r => ({
          account:    r.account,
          charName:   decodeU8(r.charName),
          masterName: r.masterName,
          isOnline:   Number(r.isOnline) === 1,
          gold:       Number(r.gold) || 0,
          payTotal:   Number(r.payTotal) || 0,
          vipPoint:   Number(r.vipPoint) || 0,
        })));
      }

      // ── POST / → 自動入帳 ────────────────────────
      //   ★ csalogin.VipPoint  才是真正的「遊戲內金幣／元寶」
      //   ★ vippointlog        是金幣變動歷史（有 old/new/buff）
      //   流程：
      //     1) UPDATE csalogin.VipPoint += goldAmount          ← 真正發金幣
      //     2) INSERT vippointlog (point, oldpoint, newpoint)  ← 變動紀錄
      //     3) UPDATE csalogin.PayTotal += twdAmount           ← VIP 等級
      //     4) INSERT recharge_orders status='completed'       ← 站內儲值訂單
      //     5) UPSERT paydata.lifetime_total                   ← 累計統計
      if (path === '/' && request.method === 'POST') {
        const body = await request.json().catch(() => ({}));
        const account   = body.account;
        const twd       = Number(body.twdAmount)  || 0;
        const gold      = Number(body.goldAmount) || 0;
        const planLabel = (body.planLabel || '').toString().slice(0, 60);
        const updatePay = body.updatePaydata !== false;

        if (!account) return cors({ message: '缺少 account 參數' }, 400);
        if (gold <= 0 && twd <= 0) return cors({ message: 'goldAmount 或 twdAmount 至少一項要 > 0' }, 400);

        // 確認玩家存在 + 取得目前 VipPoint / PayTotal / MasterId
        const [rows] = await pool.execute(
          `SELECT \`${COL.c_cdkey}\`, ${u8('`'+COL.c_charname+'`')} AS \`charName\`,
                  \`${COL.c_master}\`, \`${COL.c_vippoint}\`, \`${COL.c_paytotal}\`
           FROM \`${TABLE.character}\` WHERE \`${COL.c_cdkey}\` = ? LIMIT 1`,
          [account]
        );
        const char = rows && rows[0];
        if (!char) return cors({ message: `找不到帳號「${account}」，請確認 CDKEY 是否正確` }, 404);

        const masterId  = Number(char[COL.c_master])   || 0;
        const vipBefore = Number(char[COL.c_vippoint]) || 0;
        const payBefore = Number(char[COL.c_paytotal]) || 0;
        const vipAfter  = vipBefore + gold;

        // 1) ★★★ 真正發金幣：UPDATE VipPoint
        if (gold > 0) {
          await pool.execute(
            `UPDATE \`${TABLE.character}\`
             SET \`${COL.c_vippoint}\` = \`${COL.c_vippoint}\` + ?
             WHERE \`${COL.c_cdkey}\` = ?`,
            [gold, account]
          );

          // 2) 寫變動紀錄（遊戲後台「金幣紀錄」會看到）
          const buffText = planLabel
            ? `官網儲值 NT$${twd.toLocaleString()}（${planLabel}）`
            : `官網儲值 NT$${twd.toLocaleString()} / ${gold.toLocaleString()}金幣`;
          try {
            await pool.execute(
              `INSERT INTO \`${TABLE.vipplog}\`
                 (\`cdkey\`, \`point\`, \`oldpoint\`, \`newpoint\`, \`buff\`, \`time\`)
               VALUES (?, ?, ?, ?, ?, NOW())`,
              [account, gold, vipBefore, vipAfter, buffText.slice(0, 128)]
            );
          } catch (e) { /* log 失敗不影響發放 */ }
        }

        // 3) 累加 PayTotal（VIP 等級用）
        if (twd > 0) {
          await pool.execute(
            `UPDATE \`${TABLE.character}\`
             SET \`${COL.c_paytotal}\` = \`${COL.c_paytotal}\` + ?
             WHERE \`${COL.c_cdkey}\` = ?`,
            [twd, account]
          );
        }

        // 4) INSERT recharge_orders（站內歷史，直接 completed）
        let orderNo = '';
        if (gold > 0) {
          orderNo = (typeof crypto !== 'undefined' && crypto.randomUUID)
            ? crypto.randomUUID()
            : `WEB-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
          const productName = planLabel
            ? `官網充值 NT$${twd.toLocaleString()} / ${gold.toLocaleString()}元寶（${planLabel}）`
            : `官網充值 NT$${twd.toLocaleString()} / ${gold.toLocaleString()}元寶`;
          try {
            await pool.execute(
              `INSERT INTO \`${TABLE.recharge}\`
                 (\`order_no\`, \`user_id\`, \`product_name\`, \`role_name\`, \`amount\`, \`status\`, \`created_at\`)
               VALUES (?, ?, ?, ?, ?, 'completed', NOW())`,
              [orderNo.slice(0, 32), masterId, productName.slice(0, 100), account, gold]
            );
          } catch (e) { /* 訂單記錄失敗不影響發放 */ }
        }

        // 5) UPSERT paydata
        if (updatePay && twd > 0) {
          try {
            await pool.execute(
              `INSERT INTO \`${TABLE.paydata}\`
                 (\`${COL.p_cdkey}\`, \`${COL.p_point}\`, \`${COL.p_time}\`, \`${COL.p_lifetime}\`)
               VALUES (?, ?, NOW(), ?)
               ON DUPLICATE KEY UPDATE
                 \`${COL.p_point}\`    = \`${COL.p_point}\` + VALUES(\`${COL.p_point}\`),
                 \`${COL.p_lifetime}\` = \`${COL.p_lifetime}\` + VALUES(\`${COL.p_point}\`),
                 \`${COL.p_time}\`     = NOW()`,
              [account, twd, twd]
            );
          } catch (e) { /* paydata 失敗不影響發放 */ }
        }

        return cors({
          success:    true,
          message:    `✅ 入帳成功：${account} +${gold.toLocaleString()} 金幣${twd > 0 ? `（NT$${twd.toLocaleString()}）` : ''}`,
          account,
          charName:   decodeU8(char.charName),
          orderNo,
          goldBefore: vipBefore,
          goldAfter:  vipAfter,
          goldGiven:  gold,
          twdAmount:  twd,
          payTotal:   payBefore + twd,
          note:       '金幣已直接寫入玩家帳號（VipPoint）。在線玩家可能要重整商城／重新登入才會看到新數字。',
        });
      }

      return cors({ message: '找不到此 API 路徑' }, 404);

    } catch (err) {
      console.error('[Worker Error]', err);
      return cors({ message: err.message || '伺服器內部錯誤', stack: err.stack }, 500);
    } finally {
      try { await pool.end(); } catch {}
    }
  },
};
