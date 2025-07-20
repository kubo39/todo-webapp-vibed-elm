module app;

import std.conv : ConvException, to;
import std.exception : enforce;
import std.process : environment;

import vibe.core.core : runApplication;
import vibe.core.log;

import vibe.data.json;

import vibe.http.common;
import vibe.http.fileserver;
import vibe.http.router;
import vibe.http.server;

import todoapp.dbmanager;
import todoapp.task;

version(VibeNoSSL) {}
else static assert(false, "NoSSL is required.");

/**
 * DB操作を扱うマネージャ層
 *   DBインスタンスはTLS上に保持。
 *   vibe.dはシングルスレッドなので問題ない。
 */
DBManager db;

///
void getIndex(HTTPServerRequest _, HTTPServerResponse res)
{
    res.redirect("/index.html");
}

///
void getTasks(HTTPServerRequest _, HTTPServerResponse res)
{
    Task[] tasks;
    try tasks = db.getTasks();
    catch (Exception e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("something is wrong")]);
        res.writeJsonBody(j, 500);
        return;
    }
    res.writeJsonBody(tasks, 200);
}

///
void getTask(HTTPServerRequest req, HTTPServerResponse res)
{
    int postId;
    try postId = req.params["id"].to!int;
    catch (ConvException e)
    {
        logError("Request parameter \"id\" parse error: %s", e.toString);
        Json j = Json(["message": Json("invalid id")]);
        res.writeJsonBody(j, 400);
        return;
    }

    Task task;
    try task = db.getTask(postId);
    catch (TaskNotFound e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("task not found")]);
        res.writeJsonBody(j, 404);
        return;
    }
    catch (Exception e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("something is wrong")]);
        res.writeJsonBody(j, 500);
        return;
    }
    res.writeJsonBody(task, 200);
}

///
void postTaskUpdate(HTTPServerRequest req, HTTPServerResponse res)
{
    int postId;
    bool completed;

    try postId = req.params["id"].to!int;
    catch (ConvException e)
    {
        logError("Request parameter \"id\" parse error: %s", e.toString);
        Json j = Json(["message": Json("invalid id")]);
        res.writeJsonBody(j, 400);
        return;
    }

    if (postId <= 0)
    {
        logError("Invalid task ID: %d", postId);
        Json j = Json(["message": Json("invalid task ID")]);
        res.writeJsonBody(j, 400);
        return;
    }

    try completed = req.json["completed"].get!bool;
    catch (ConvException e)
    {
        logError("Request parameter \"completed\" parse error: %s", e.toString);
        Json j = Json(["message": Json("invalid completed status")]);
        res.writeJsonBody(j, 400);
        return;
    }

    Task task;
    try task = db.updateTask(postId, completed);
    catch (TaskNotFound e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("task not found")]);
        res.writeJsonBody(j, 404);
        return;
    }
    catch (Exception e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("something is wrong")]);
        res.writeJsonBody(j, 500);
        return;
    }
    res.writeJsonBody(task, 200);
}

///
void postTaskNew(HTTPServerRequest req, HTTPServerResponse res)
{
    string text;
    try text = req.json["text"].get!string;
    catch (Exception e)
    {
        logError("Request parameter \"text\" parse error: %s", e.toString);
        Json j = Json(["message": Json("invalid or missing text parameter")]);
        res.writeJsonBody(j, 400);
        return;
    }
    if (text.length > 80)
    {
        logError("text is too long");
        Json j = Json(["message": Json("タスクのテキストが長すぎます")]);
        res.writeJsonBody(j, 400);
        return;
    }

    if (text.length == 0)
    {
        logError("text is empty");
        Json j = Json(["message": Json("テキストが空です")]);
        res.writeJsonBody(j, 400);
        return;
    }

    Task task;
    try task = db.insertTask(text);
    catch (TaskNotFound e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("task not found")]);
        res.writeJsonBody(j, 500);
        return;
    }
    catch (Exception e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("something is wrong")]);
        res.writeJsonBody(j, 500);
        return;
    }
    res.writeJsonBody(task, 200);
}

///
void deleteTask(HTTPServerRequest req, HTTPServerResponse res)
{
    int postId;
    try postId = req.params["id"].to!int;
    catch (ConvException e)
    {
        logError("Request parameter \"id\" parse error: %s", e.toString);
        Json j = Json(["message": Json("invalid id")]);
        res.writeJsonBody(j, 400);
        return;
    }

    Task task;
    try task = db.deleteTask(postId);
    catch (TaskNotFound e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("task not found")]);
        res.writeJsonBody(j, 404);
        return;
    }
    catch (Exception e)
    {
        logError(e.toString);
        Json j = Json(["message": Json("something is wrong")]);
        res.writeJsonBody(j, 500);
        return;
    }
    res.writeJsonBody(task, 200);
}

///
version(unittest) {}
else
shared static this()
{
    const string host = environment.get("DB_HOST", "postgres");
    const string dbname = environment.get("DB_NAME", "postgres");
    const string user = environment.get("DB_USER", "postgres");
    const string password = environment.get("DB_PASSWORD", "postgres");
    const string port = environment.get("DB_PORT", "5432");
    const string connString = "host=" ~ host ~ " dbname=" ~ dbname ~ " user=" ~ user ~
        " password=" ~ password ~ " port=" ~ port;
    db = new PostgresManager(connString);
}

version(unittest) {}
else
int main()
{
    auto settings = new HTTPServerSettings;
    const host = environment.get("SERVER_HOST", "127.0.0.1");
    settings.bindAddresses = [host];
    settings.port = environment.get("SERVER_PORT", "8080").to!short;

    auto router = new URLRouter;
    router.get("/", &getIndex);
    router.get("/tasks", &getTasks);
    router.get("/tasks/:id", &getTask);
    router.post("/tasks", &postTaskNew);
    router.post("/tasks/:id", &postTaskUpdate);
    router.delete_("/tasks/:id", &deleteTask);

    router.get("*", serveStaticFiles("../public/",));

    auto listener = listenHTTP(settings, router);
    scope(exit) listener.stopListening();

    logInfo("Please open http://127.0.0.1:8080/ in your browser.");
    return runApplication();
}


/// smoke test
unittest
{
    import std.datetime;
    import vibe.inet.url : URL;
    import vibe.stream.memory : createMemoryOutputStream;

    class SmokeMockDBManager : DBManager
    {
        Task[] getTasks()
        {
            auto task = Task(1, "test", false, DateTime(2000, 6, 1, 10, 30, 0));
            return [task];
        }
        Task getTask(int id)
        {
            return Task(id, "test", false, DateTime(2000, 6, 1, 10, 30, 0));
        }
        Task updateTask(int id, bool completed)
        {
            return Task(id, "test", completed, DateTime(2000, 6, 1, 10, 30, 0));
        }
        Task insertTask(string text)
        {
            return Task(1, text, true, DateTime(2000, 6, 1, 10, 30, 0));
        }
        Task deleteTask(int id)
        {
            return Task(id, "test", true, DateTime(2000, 6, 1, 10, 30, 0));
        }
    }

    db = new SmokeMockDBManager;

    // Use test utilities from vibe-http.
    auto req = createTestHTTPServerRequest(URL("http://example.com"), HTTPMethod.GET);
    auto output = createMemoryOutputStream();
    auto res = createTestHTTPServerResponse(output, null, TestHTTPResponseMode.bodyOnly);

    getTasks(req, res);
    res.finalize();

    assert(res.statusCode == 200);
    Json value = (cast(string) output.data).parseJsonString;
    assert(value[0]["id"] == Json(1));
    assert(value[0]["text"] == Json("test"));
    assert(value[0]["completed"] == Json(false));
    assert(value[0]["createdAt"] == Json("2000-06-01T10:30:00"));
}
