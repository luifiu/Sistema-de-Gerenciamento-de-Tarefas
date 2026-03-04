-- ═══════════════════════════════════════════════════════════════
--  TASKFLOW — Schema MySQL
--  Sistema de Gerenciamento de Tarefas
-- ═══════════════════════════════════════════════════════════════

-- 1. CRIAÇÃO DO BANCO DE DADOS
CREATE DATABASE IF NOT EXISTS taskflow
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE taskflow;

-- ─────────────────────────────────────────────────────────────
-- 2. TABELA PRINCIPAL: tasks
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tasks (
  id          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  title       VARCHAR(255)    NOT NULL,
  description TEXT,
  status      ENUM('ativa', 'concluida', 'cancelada')
                              NOT NULL DEFAULT 'ativa',
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_status (status),
  INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────
-- 3. DADOS DE EXEMPLO (seeds)
-- ─────────────────────────────────────────────────────────────
INSERT INTO tasks (title, description, status) VALUES
  ('Revisar relatório mensal',
   'Checar números de vendas e KPIs do mês anterior.',
   'ativa'),

  ('Reunião com equipe de design',
   'Apresentar wireframes do novo módulo.',
   'concluida'),

  ('Atualizar dependências do projeto',
   'npm update e verificar breaking changes.',
   'ativa'),

  ('Enviar proposta para cliente',
   NULL,
   'cancelada'),

  ('Configurar pipeline de CI/CD',
   'GitHub Actions para deploy automático em staging.',
   'ativa');

-- ═══════════════════════════════════════════════════════════════
--  QUERIES DE OPERAÇÃO (CRUD)
-- ═══════════════════════════════════════════════════════════════

-- ── CREATE ──────────────────────────────────────────────────────
/*
  INSERT INTO tasks (title, description, status)
  VALUES (?, ?, ?);
  -- Params: 'Título da tarefa', 'Descrição...', 'ativa'
*/

-- ── READ — buscar todas ─────────────────────────────────────────
/*
  SELECT id, title, description, status, created_at, updated_at
  FROM tasks
  ORDER BY created_at DESC;
*/

-- ── READ — filtrar por status ───────────────────────────────────
/*
  SELECT id, title, description, status, created_at, updated_at
  FROM tasks
  WHERE status = ?            -- 'ativa' | 'concluida' | 'cancelada'
  ORDER BY created_at DESC;
*/

-- ── READ — busca por texto ──────────────────────────────────────
/*
  SELECT id, title, description, status, created_at, updated_at
  FROM tasks
  WHERE (title LIKE ? OR description LIKE ?)
    AND status = ?            -- opcional: filtro combinado
  ORDER BY created_at DESC;
  -- Params: '%busca%', '%busca%', 'ativa'
*/

-- ── UPDATE — editar tarefa ──────────────────────────────────────
/*
  UPDATE tasks
  SET title       = ?,
      description = ?,
      status      = ?
  WHERE id = ?;
*/

-- ── UPDATE — alterar só o status ───────────────────────────────
/*
  UPDATE tasks
  SET status = ?
  WHERE id = ?;
*/

-- ── DELETE ──────────────────────────────────────────────────────
/*
  DELETE FROM tasks
  WHERE id = ?;
*/

-- ═══════════════════════════════════════════════════════════════
--  VIEWS ÚTEIS
-- ═══════════════════════════════════════════════════════════════

-- Resumo por status
CREATE OR REPLACE VIEW vw_task_summary AS
SELECT
  status,
  COUNT(*) AS total
FROM tasks
GROUP BY status
UNION ALL
SELECT 'total' AS status, COUNT(*) FROM tasks;

-- Tarefas recentes (últimas 24h)
CREATE OR REPLACE VIEW vw_tasks_recent AS
SELECT *
FROM tasks
WHERE created_at >= NOW() - INTERVAL 1 DAY
ORDER BY created_at DESC;

-- ═══════════════════════════════════════════════════════════════
--  STORED PROCEDURE: ciclar status (ativa → concluida → cancelada)
-- ═══════════════════════════════════════════════════════════════
DELIMITER $$

CREATE PROCEDURE sp_cycle_status(IN p_id INT UNSIGNED)
BEGIN
  DECLARE v_status VARCHAR(20);
  SELECT status INTO v_status FROM tasks WHERE id = p_id;

  SET v_status = CASE v_status
    WHEN 'ativa'     THEN 'concluida'
    WHEN 'concluida' THEN 'cancelada'
    WHEN 'cancelada' THEN 'ativa'
    ELSE 'ativa'
  END;

  UPDATE tasks SET status = v_status WHERE id = p_id;
  SELECT id, title, status, updated_at FROM tasks WHERE id = p_id;
END$$

DELIMITER ;

-- Uso: CALL sp_cycle_status(1);

-- ═══════════════════════════════════════════════════════════════
--  EXEMPLO DE INTEGRAÇÃO COM BACKEND (PHP / Node.js pseudocódigo)
-- ═══════════════════════════════════════════════════════════════

/*
  ── PHP (PDO) ───────────────────────────────────────────────────

  $pdo = new PDO('mysql:host=localhost;dbname=taskflow;charset=utf8mb4',
                 'usuario', 'senha');
  $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

  // GET /tasks?status=ativa
  $status = $_GET['status'] ?? null;
  if ($status) {
    $stmt = $pdo->prepare('SELECT * FROM tasks WHERE status = ? ORDER BY created_at DESC');
    $stmt->execute([$status]);
  } else {
    $stmt = $pdo->query('SELECT * FROM tasks ORDER BY created_at DESC');
  }
  echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));

  // POST /tasks
  $body  = json_decode(file_get_contents('php://input'), true);
  $stmt  = $pdo->prepare('INSERT INTO tasks (title, description, status) VALUES (?, ?, ?)');
  $stmt->execute([$body['title'], $body['description'] ?? null, $body['status'] ?? 'ativa']);
  echo json_encode(['id' => $pdo->lastInsertId()]);

  ── Node.js (mysql2/promise) ─────────────────────────────────────

  const mysql = require('mysql2/promise');
  const pool  = mysql.createPool({
    host: 'localhost', database: 'taskflow',
    user: 'usuario', password: 'senha',
    waitForConnections: true, connectionLimit: 10
  });

  // GET tasks
  app.get('/tasks', async (req, res) => {
    const { status, q } = req.query;
    let sql = 'SELECT * FROM tasks WHERE 1=1';
    const params = [];
    if (status) { sql += ' AND status = ?'; params.push(status); }
    if (q)      { sql += ' AND (title LIKE ? OR description LIKE ?)';
                  params.push(`%${q}%`, `%${q}%`); }
    sql += ' ORDER BY created_at DESC';
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  });

  // DELETE task
  app.delete('/tasks/:id', async (req, res) => {
    await pool.query('DELETE FROM tasks WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  });
*/
