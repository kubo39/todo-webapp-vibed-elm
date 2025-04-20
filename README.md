# TODOアプリ

## 起動

### フロントエンド

#### ビルド(Elm)

```console
make build-frontend
```

### バックエンド

#### ビルド(D言語)

##### ローカルでのビルド

```console
make build-backend
```

##### Dockerでのビルド

```console
docker build -t "todo-webapp-backend:latest" -f backend.Dockerfile .
```

#### 実行

##### ローカルでの実行

```console
make run-backend
```

##### Dockerでの実行

```console
docker run -p 127.0.0.1:8080:8080 todo-webapp-backend
```

##### docker-composeでの実行

```console
docker-compose up -d --remove-orphans
```

## 使ってる技術

- backend
  - vibe.d
  - PostgreSQL
- frontend
  - elm

## 例(API)

### 作成

```console
curl -X POST -H "Content-Type: application/json" -d "{\"text\" : \"test\"}" http://localhost:8080/tasks
```

### 更新

```console
curl -X POST -H "Content-Type: application/json" -d "{\"completed\" : true}" http://localhost:8080/tasks/1
```

### 削除

```console
curl -X DELETE -H "Content-Type: application/json" http://localhost:8080/tasks/1
```
