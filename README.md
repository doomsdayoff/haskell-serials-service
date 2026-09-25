# serials-api

[![CI](https://github.com/doomsdayoff/haskell-serials-service/actions/workflows/ci.yml/badge.svg)](https://github.com/doomsdayoff/haskell-serials-service/actions/workflows/ci.yml)

REST API каталога сериалов на Haskell и Servant.

Проект вырос из курсовой работы по дисциплине «Функциональное и логическое
программирование» (ТУСУР, кафедра АОИ, 2024) — консольного приложения,
которое читало каталог из JSON и умело фильтровать, сортировать и искать
сериалы. Логика отбора там с самого начала жила отдельно от ввода-вывода,
поэтому переезд на HTTP свёлся к замене оболочки: `Serials.Query` не
изменился по существу, вокруг него появились `Serials.API`, `Serials.Server`
и хранилище. Консольная версия осталась вторым исполняемым файлом и
использует те же функции, что и веб-сервис.

## Запуск

```
cabal build
cabal test
cabal run serials-api     # REST API на http://localhost:8080
cabal run serials-cli     # исходное консольное меню
```

Переменные окружения: `PORT` (по умолчанию 8080) и `SERIALS_DATA`
(по умолчанию `serials.json`).

В Docker:

```
docker build -t serials-api .
docker run --rm -p 8080:8080 serials-api
```

## Эндпоинты

| Метод  | Путь                        | Описание                                       |
|--------|-----------------------------|------------------------------------------------|
| `GET`  | `/api/v1/health`            | проверка живости, `{"status":"ok"}`            |
| `GET`  | `/api/v1/serials`           | весь каталог                                   |
| `GET`  | `/api/v1/serials/filter`    | отбор по `genre`, `actor`, `director`          |
| `GET`  | `/api/v1/serials/sort`      | сортировка по `by` и `order`                   |
| `GET`  | `/api/v1/serials/search`    | поиск по подстроке, параметр `query`           |
| `POST` | `/api/v1/serials/reload`    | перечитать файл каталога, вернуть число записей |
| `GET`  | `/api/v1/serials/{title}`   | один сериал по названию, иначе 404             |

```
curl localhost:8080/api/v1/health
curl localhost:8080/api/v1/serials
curl 'localhost:8080/api/v1/serials/filter?genre=Drama&director=Vince%20Gilligan'
curl 'localhost:8080/api/v1/serials/sort?by=rating&order=desc'
curl 'localhost:8080/api/v1/serials/search?query=gilligan'
curl 'localhost:8080/api/v1/serials/Breaking%20Bad'
curl -X POST localhost:8080/api/v1/serials/reload
```

Параметры `filter` необязательны и складываются: незаданный критерий ничего
не отсекает, а заданные сужают выборку одновременно. У `sort` есть значения
по умолчанию — `by=rating&order=desc`; неизвестное значение даёт `400`
с перечислением допустимых. Сравнение значений регистронезависимое.

Ошибки возвращаются в том же формате, что и данные:

```
$ curl -i 'localhost:8080/api/v1/serials/sort?by=duration'
HTTP/1.1 400 Bad Request
Content-Type: application/json;charset=utf-8

{"error":"by=duration: ожидается одно из rating|year"}
```

## Структура

| Модуль            | Назначение                                                  |
|-------------------|-------------------------------------------------------------|
| `Serials.Types`   | доменная модель `Serial` и тела ответов, инстансы Aeson      |
| `Serials.Query`   | чистые функции фильтрации, сортировки и поиска              |
| `Serials.Storage` | каталог в памяти под `TVar`, чтение и перечитывание JSON     |
| `Serials.API`     | описание маршрутов на уровне типов                          |
| `Serials.Server`  | хэндлеры, значения по умолчанию и коды ошибок               |

Маршруты описаны типом, поэтому хэндлеры не могут разойтись с контрактом:
если добавить в `SerialsAPI` параметр или поменять тип ответа, `Serials.Server`
перестанет компилироваться, пока его не поправят.

Статические сегменты (`filter`, `sort`, `search`, `reload`) объявлены раньше
`Capture "title"` — иначе `/api/v1/serials/filter` разобрался бы как запрос
сериала с названием `filter`.

## Тесты

```
cabal test
```

На каждый push в `main` GitHub Actions собирает проект и прогоняет тесты
на GHC 9.6.7; статус — в бейдже наверху.

Тесты на HUnit покрывают чистый слой: фильтрацию по каждому критерию и их
сочетаниям, стабильность сортировки при равных рейтингах, разбор параметров
`by` и `order`, регистронезависимый поиск. Отдельный тест разбирает
`serials.json` текущей структурой `Serial`, чтобы расхождение модели и данных
ловилось сборкой, а не первым запросом.

## Данные

Каталог — обычный JSON-массив, читается один раз на старте и лежит в памяти:

```json
{
  "title": "Breaking Bad",
  "genre": ["Drama", "Crime", "Thriller"],
  "actors": ["Bryan Cranston", "Aaron Paul"],
  "director": "Vince Gilligan",
  "country": "USA",
  "year": 2008,
  "rating": 9.5,
  "duration": 47,
  "seasons": 5
}
```

Хранилище спрятано за `TVar` и интерфейсом `openStore` / `readCatalog` /
`reloadCatalog`, так что замена файла на Postgres не затрагивает ни хэндлеры,
ни `Serials.Query`.
