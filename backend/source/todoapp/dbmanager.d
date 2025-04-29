module todoapp.dbmanager;

import std.datetime : DateTime;
import std.exception : enforce;

import vibe.core.log;

import dpq2.conv.time;
import vibe.db.postgresql;

import todoapp.task;

///
interface DBManager
{
    ///
    Task[] getTasks();
    ///
    Task getTask(int id);
    ///
    Task updateTask(int id, bool completed);
    ///
    Task insertTask(string text);
    ///
    Task deleteTask(int id);
}

///
class TaskNotFound : Exception
{
    ///
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

/// データベース操作を集約
final class PostgresManager : DBManager
{
private:
    PostgresClient client;

    enum
    {
        GET_TASK_QUERY = "SELECT * FROM task where task.id = $1",
        UPDATE_TASK_QUERY = "UPDATE task SET completed = $2 WHERE task.id = $1 RETURNING *",
        INSERT_TASK_QUERY = "INSERT INTO task (text) VALUES($1) RETURNING *",
        DELETE_TASK_QUERY = "DELETE FROM task WHERE task.id = $1 RETURNING *",
    }

    Task doQuery(string statementName, ARGS...)(ARGS args)
    {
        Task task;
        client.pickConnection(
            (scope conn)
            {
                QueryParams params;
                params.preparedStatementName = statementName;
                params.argsVariadic(args);
                auto rows = conn.execPreparedStatement(params);
                enforce!TaskNotFound(rows.length, "task not found");
                task = Task(
                    rows[0]["id"].as!PGinteger,
                    rows[0]["text"].as!PGtext,
                    rows[0]["completed"].as!PGboolean,
                    rows[0]["created_at"].as!PGtimestamptz.dateTime
                );
            }
        );
        return task;
    }

public:
    ///
    this(string connString, uint connNum = 4, bool sendPrepared = true)
    {
        client = new PostgresClient(connString, connNum);
        if (sendPrepared)
            sendPreparedStatements();
    }

    ///
    void sendPreparedStatements()
    {
        client.pickConnection(
            (scope conn)
            {
                conn.prepareStatement(GET_TASK_QUERY, GET_TASK_QUERY);
                conn.prepareStatement(UPDATE_TASK_QUERY, UPDATE_TASK_QUERY);
                conn.prepareStatement(INSERT_TASK_QUERY, INSERT_TASK_QUERY);
                conn.prepareStatement(DELETE_TASK_QUERY, DELETE_TASK_QUERY);
            }
        );
    }

    ///ToDoタスク一覧を取得
    Task[] getTasks()
    {
        Task[] tasks;
        client.pickConnection(
            (scope conn)
            {
                auto rows = conn.execStatement("SELECT * FROM task ORDER BY id ASC");
                foreach (row; rows.rangify)
                {
                    tasks ~= Task(
                        row["id"].as!PGinteger,
                        row["text"].as!PGtext,
                        row["completed"].as!PGboolean,
                        row["created_at"].as!PGtimestamptz.dateTime
                    );
                }
            }
        );
        return tasks;
    }

    /// IDに紐づくTODOタスクを取得
    Task getTask(int id)
    {
        return doQuery!GET_TASK_QUERY(id);
    }

    /// TODOタスクの完了状態を更新
    Task updateTask(int id, bool completed)
    {
        return doQuery!UPDATE_TASK_QUERY(id, completed);
    }

    /// 新規にTODOタスクを登録
    Task insertTask(string text)
    {
        return doQuery!INSERT_TASK_QUERY(text);
    }

    /// IDに紐づくTODOタスクを削除
    Task deleteTask(int id)
    {
        return doQuery!DELETE_TASK_QUERY(id);
    }

    // For testing purposes only.
    version(unittest)
    void execute(string sql)
    {
        auto conn = client.lockConnection;
        conn.execStatement(sql);
    }
}

unittest
{
    import std.exception : assertThrown;

    auto db = new PostgresManager("host=localhost dbname=postgres user=postgres password=postgres", 4, false);
    db.execute(`
        CREATE TEMPORARY TABLE task (
            id SERIAL PRIMARY KEY,
            text TEXT,
            completed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
        )
    `);
    db.sendPreparedStatements();

    const content = "Test task 1";
    const inserted = db.insertTask(content);
    assert(!inserted.completed);

    const tasks = db.getTasks();
    assert(tasks[0].text == content);
    assert(!tasks[0].completed);

    const updated = db.updateTask(tasks[0].id, true);
    assert(updated.completed);

    const deleted = db.deleteTask(tasks[0].id);
    assert(deleted.id == tasks[0].id);

    assertThrown!TaskNotFound(db.getTask(tasks[0].id));
}
