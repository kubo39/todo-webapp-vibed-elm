module todoapp.task;

import std.datetime : DateTime;

/// TODOタスク
struct Task
{
    /// ID
    int id;
    /// 内容
    string text;
    /// 完了状態
    bool completed;
    /// 作成時刻
    DateTime createdAt;
}
