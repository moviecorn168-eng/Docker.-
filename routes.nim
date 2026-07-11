import jester
import std/[json, tables, strutils, sha1, options]
import models
import db_manager

var
  users {.threadvar.}: Table[string, User]
  databases {.threadvar.}: Table[string, ProvisionedDatabase]

proc initStore*() =
  users = initTable[string, User]()
  databases = initTable[string, ProvisionedDatabase]()

proc hashPassword(pw: string): string =
  $secureHash(pw)

proc findUserByEmail(email: string): Option[User] =
  for u in users.values:
    if u.email == email:
      return some(u)
  none(User)

routes:

  post "/api/users/register":
    let body =
      try: parseJson(request.body)
      except: JsonNode(nil)

    if body.isNil or not body.hasKey("email") or not body.hasKey("password"):
      resp Http400, %*{"error": "email and password are required"}
    else:
      let email = body["email"].getStr
      if findUserByEmail(email).isSome:
        resp Http409, %*{"error": "an account with that email already exists"}
      else:
        let user = User(
          id: newId(),
          username: body{"username"}.getStr(email),
          email: email,
          passwordHash: hashPassword(body["password"].getStr),
          createdAt: now()
        )
        users[user.id] = user
        resp Http201, %*{
          "id": user.id,
          "username": user.username,
          "email": user.email
        }

  post "/api/databases/create":
    let body =
      try: parseJson(request.body)
      except: JsonNode(nil)

    if body.isNil or not body.hasKey("ownerId") or not body.hasKey("name"):
      resp Http400, %*{"error": "ownerId and name are required"}
    else:
      let ownerId = body["ownerId"].getStr
      if not users.hasKey(ownerId):
        resp Http404, %*{"error": "unknown ownerId"}
      else:
        let
          rawName = body["name"].getStr
          engineStr = body{"engine"}.getStr("sqlite")
          engine = if engineStr == "postgres": dbPostgres else: dbSqlite

        var record = ProvisionedDatabase(
          id: newId(),
          ownerId: ownerId,
          projectId: body{"projectId"}.getStr(""),
          name: rawName,
          engine: engine,
          status: dsPending,
          connectionInfo: "",
          createdAt: now()
        )

        try:
          record.connectionInfo = provisionDatabase(ownerId, rawName, engine)
          record.status = dsActive
          databases[record.id] = record
          resp Http201, %*{
            "id": record.id,
            "name": record.name,
            "engine": $record.engine,
            "status": $record.status,
            "connectionInfo": record.connectionInfo
          }
        except ValueError as e:
          resp Http400, %*{"error": e.msg}
        except IOError as e:
          record.status = dsFailed
          resp Http409, %*{"error": e.msg}
        except CatchableError as e:
          record.status = dsFailed
          resp Http500, %*{"error": "provisioning failed: " & e.msg}

  get "/api/databases/list":
    let ownerId = request.params.getOrDefault("ownerId", "")
    if ownerId == "":
      resp Http400, %*{"error": "ownerId query param is required"}
    else:
      var results: seq[JsonNode] = @[]
      for db in databases.values:
        if db.ownerId == ownerId:
          results.add %*{
            "id": db.id,
            "name": db.name,
            "engine": $db.engine,
            "status": $db.status,
            "connectionInfo": db.connectionInfo,
            "createdAt": $db.createdAt
          }
      resp Http200, %*{"databases": results}
