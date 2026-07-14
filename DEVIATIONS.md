# Deliberate deviations from Apple Core Data

CoreDataSwift aims for behavioral parity with Apple Core Data — the
`AppleCoreDataTests` target runs the same scenarios against the real framework
to keep us honest. The differences below are **on purpose**, mostly because
this implementation runs long-lived server processes against Postgres rather
than app processes against SQLite. Anything not listed here that behaves
differently is a bug.

## Change tracking

- **`setPrimitiveValue` is tracked.** The change appears in `changedValues()`
  and is saved. Apple's primitive writes bypass change tracking entirely
  (verified in `testSetPrimitiveValueIsNotTracked_DEVIATION`). Rationale:
  values written from `awakeFromInsert`/`awakeFromFetch` must survive refaults
  and reach the store; the untracked variant silently lost them. What
  `setPrimitiveValue` still skips versus `setValue`: the will/didChange
  observers and inverse-relationship maintenance.

- **`refresh(mergeChanges: false)` on an unsaved inserted object keeps its
  pending values** (including model defaults applied at creation). There is no
  committed state to reload, so discarding would leave a hollow object. Apple
  treats this as an edge case with data loss.

## Validation and save

- **Validation errors are Swift enums** (`NSManagedObjectValidationError`),
  not `NSCocoaErrorDomain` codes. Multiple failures wrap in `.multiple`;
  every error carries the object URI and a forensic detail (value never set
  vs explicitly nulled).

- **`mandatoryValidationPolicy`** (`.error` default / `.warning`) and
  **`validatesOnSave`** have no Apple equivalent — rollout levers for data
  sets that predate validation.

- **`DBDefaultValue` / `DBDefaultFunction` userInfo keys** exempt properties
  from the mandatory check: the database (DEFAULT expressions) or the server
  framework (request-scoped functions like `:appId`) fills them. Apple has no
  such concept.

- **Parent/child contexts are unsupported** — `save()` on a child context
  throws `parentContextsUnsupported` instead of propagating (Apple) or
  silently dropping changes (the old behavior here).

## Concurrency and lifetime

- **`mainQueueConcurrencyType` uses a private serial queue**, not
  `DispatchQueue.main`. On a server the main thread may never drain the main
  queue, and binding `performAndWait` to it would hang forever.

- **`perform` blocks are not wrapped in an autoreleasepool or a
  `processPendingChanges` call** (delete propagation runs eagerly at
  `delete()` time instead).

- **`retainsRegisteredObjects` defaults to `true`** (Apple: `false`). Existing
  consumers rely on the context keeping fetched objects alive. Long-lived
  contexts can opt into the weak registry.

- **`existingObject(with:)` never throws for an unknown ID** — it returns a
  hollow object faulted on first access. Apple throws when the object does
  not exist in the store.

## Fetching and sorting

- **Sort nil ordering follows Postgres**: ascending puts NULLs last,
  descending puts them first (`ASC NULLS LAST` / `DESC NULLS FIRST`), so
  in-memory sorts agree with the production database's `ORDER BY`. Apple's
  in-memory `NSSortDescriptor` raises on nil; its SQLite store sorts nulls
  first in both directions.

- **Incremental-store fetches keep the store's row order** and never re-sort
  in memory (the DB collation is authoritative); unsaved pending objects are
  appended after the store rows.

- Fetch flags the in-memory path does not implement
  (`fetchBatchSize`, `propertiesToFetch`, `propertiesToGroupBy`,
  `havingPredicate`, `returnsDistinctResults`) log a one-shot warning and are
  ignored. For incremental stores the request passes through to the store,
  which may honor them.

## KVC

- **Unmodeled keys**: `value(forKey:)` returns nil on Linux instead of
  trapping like Apple KVC (there is no `NSObject` KVC to fall back to).
