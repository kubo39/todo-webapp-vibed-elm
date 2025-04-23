module todoapp.dbmanager;

import std.datetime : DateTime;
import std.typecons : Nullable, nullable;

import vibe.core.log;

import dpq2.conv.time;
import vibe.db.postgresql;

import todoapp.task;

///
interface DBManager
{
    ///
    Nullable!(Task[]) getTasks();
    ///
    Nullable!Task getTask(int id);
    ///
    Nullable!Task updateTask(int id, bool completed);
    ///
    Nullable!Task insertTask(string text);
    ///
    Nullable!Task deleteTask(int id);
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

    Nullable!Task doQuery(string statementName, ARGS...)(ARGS args)
    {
        try
        {
            auto task = typeof(return).init;
            client.pickConnection(
                (scope conn)
                {
                    QueryParams params;
                    params.preparedStatementName = statementName;
                    params.argsVariadic(args);
                    auto rows = conn.execPreparedStatement(params);
                    if (rows.length)
                    {
                        task = Task(
                            rows[0]["id"].as!PGinteger,
                            rows[0]["text"].as!PGtext,
                            rows[0]["completed"].as!PGboolean,
                            rows[0]["created_at"].as!PGtimestamp.dateTime
                        );
                    }
                }
            );
            return task;
        }
        catch (Exception e)
        {
            logError(e.toString);
            return typeof(return).init;
        }
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
    Nullable!(Task[]) getTasks()
    {
        Task[] tasks;
        try
        {
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
                            row["created_at"].as!PGtimestamp.dateTime
                        );
                    }
                }
            );
            return tasks.nullable;
        }
        catch (Exception e)
        {
            logError(e.toString);
            return typeof(return).init;
        }
    }

    /// IDに紐づくTODOタスクを取得
    Nullable!Task getTask(int id)
    {
        return doQuery!GET_TASK_QUERY(id);
    }

    /// TODOタスクの完了状態を更新
    Nullable!Task updateTask(int id, bool completed)
    {
        return doQuery!UPDATE_TASK_QUERY(id, completed);
    }

    /// 新規にTODOタスクを登録
    Nullable!Task insertTask(string text)
    {
        return doQuery!INSERT_TASK_QUERY(text);
    }

    /// IDに紐づくTODOタスクを削除
    Nullable!Task deleteTask(int id)
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
    auto db = new PostgresManager("host=localhost dbname=postgres user=postgres password=postgres", 4, false);
    db.execute(`
        CREATE TEMPORARY TABLE task (
            id SERIAL PRIMARY KEY,
            text TEXT,
            completed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
        )
    `);
    db.sendPreparedStatements();

    const content = "Test task 1";
    const inserted = db.insertTask(content);
    assert(!inserted.isNull);

    const tasks = db.getTasks();
    assert(!tasks.isNull);
    const task = tasks.get[0];
    assert(task.text == content);
    assert(!task.completed);

    const updated = db.updateTask(task.id, true);
    assert(!updated.isNull);
    assert(updated.get.completed);

    const deleted = db.deleteTask(task.id);
    assert(!deleted.isNull);

    const got = db.getTask(task.id);
    assert(got.isNull);
}
