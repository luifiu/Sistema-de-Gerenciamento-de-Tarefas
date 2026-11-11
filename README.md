# ✅ TaskFlow — Gerenciador de Tarefas

Aplicação web para organizar tarefas do dia a dia, com interface escura e responsiva e um **schema MySQL** completo já modelado.

> ℹ️ Nesta versão, a interface salva as tarefas no **`localStorage`** do navegador (simulando a camada de dados). O arquivo `schema.sql` define o banco MySQL que serve de base para uma futura integração com back-end.

## Funcionalidades

- Criar, editar e excluir tarefas (título e descrição)
- Três status: **ativa**, **concluída** e **cancelada**
- Filtros por status
- Dados de exemplo carregados na primeira abertura
- Persistência local entre sessões

## Banco de dados (`schema.sql`)

- Tabela `tasks` com `ENUM` de status, `created_at` e `updated_at` automáticos
- Índices em `status` e `created_at`
- Dados de exemplo e consultas úteis
- Stored procedure `sp_cycle_status` (ativa → concluída → cancelada → ativa)

Para criar o banco no MySQL:

```bash
mysql -u root -p < schema.sql
```

## Tecnologias

HTML5, CSS3, JavaScript puro e MySQL.

## Como rodar

```bash
git clone https://github.com/luifiu/Sistema-de-Gerenciamento-de-Tarefas.git
cd Sistema-de-Gerenciamento-de-Tarefas
```

Abra o `index.html` no navegador.

## Próximos passos

- Criar uma API (Node.js, Python ou Java) conectando a interface ao MySQL
- Adicionar prazos e prioridades às tarefas
- Publicar uma demo online com GitHub Pages

## Licença

Distribuído sob a licença MIT. Veja [LICENSE](LICENSE).
