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
    auto tasks = db.getTasks();
    if (tasks.isNull)
    {
        res.writeJsonBody(Json.emptyObject, 500);
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
        cast(void) enforceBadRequest(false);
    }

    auto task = db.getTask(postId);
    if (task.isNull)
    {
        res.writeJsonBody(Json.emptyObject, 404);
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
        cast(void) enforceBadRequest(false);
    }
    try completed = req.json["completed"].get!bool;
    catch (ConvException e)
    {
        logError("Request parameter \"completed\" parse error: %s", e.toString);
        cast(void) enforceBadRequest(false);
    }

    auto tasks = db.updateTask(postId, completed);
    if (tasks.isNull)
    {
        res.writeJsonBody(Json.emptyObject, 500);
        return;
    }
    res.writeJsonBody(tasks, 200);
}

///
void postTaskNew(HTTPServerRequest req, HTTPServerResponse res)
{
    const text = req.json["text"].get!string;
    if (text.length > 80)
    {
        cast(void) enforceBadRequest(false, "タスクのテキストが長すぎます");
    }

    if (text.length == 0)
    {
        res.writeJsonBody(Json.emptyObject, 400);
        return;
    }
    auto tasks = db.insertTask(text);
    if (tasks.isNull)
    {
        res.writeJsonBody(Json.emptyObject, 500);
        return;
    }
    res.writeJsonBody(tasks, 200);
}

///
void deleteTask(HTTPServerRequest req, HTTPServerResponse res)
{
    int postId;
    try postId = req.params["id"].to!int;
    catch (ConvException e)
    {
        logError("Request parameter \"id\" parse error: %s", e.toString);
        cast(void) enforceBadRequest(false);
    }
    auto tasks = db.deleteTask(postId);
    if (tasks.isNull)
    {
        res.writeJsonBody(Json.emptyObject, 500);
        return;
    }
    res.writeJsonBody(tasks, 200);
}

///
shared static this()
{
    db = DBManager("host=postgres dbname=postgres user=postgres password=postgres");
}

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
