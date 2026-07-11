import std/[times, oids]

type
  DatabaseEngine* = enum
    dbSqlite = "sqlite"
    dbPostgres = "postgres"

  DatabaseStatus* = enum
    dsPending = "pending"
    dsActive = "active"
    dsFailed = "failed"
    dsDeleted = "deleted"

  User* = object
    id*: string
    username*: string
    email*: string
    passwordHash*: string
    createdAt*: DateTime

  Project* = object
    id*: string
    ownerId*: string
    name*: string
    createdAt*: DateTime

  ProvisionedDatabase* = object
    id*: string
    ownerId*: string
    projectId*: string
    name*: string
    engine*: DatabaseEngine
    status*: DatabaseStatus
    connectionInfo*: string
    createdAt*: DateTime

proc newId*(): string =
  $genOid()

proc now*(): DateTime =
  times.now()
