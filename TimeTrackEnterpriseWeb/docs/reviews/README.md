# Review reports

| Document | Scope |
| --- | --- |
| [`migration.md`](migration.md) | Legacy → Django migration: mapping, parity, open items |
| [`security.md`](security.md) | Security review of the migrated code and deployment defaults |

These documents record what was checked and **how**. They are not marketing
material: unresolved items stay listed until they are verified on a machine
with Python and Django installed.

## Status at the time of writing

The migration was performed in an environment without a Python interpreter,
Django, Node or Flutter. Verification was therefore **static**:

* every module was read after writing it;
* imports and URL names were cross-checked with `grep`/`Select-String`;
* the test suite was ported and reviewed, but **not executed**;
* `manage.py check`, `migrate`, `pytest`, `flutter test` and a real browser
  session must still be run on the target machine (see
  [`../TESTING.md`](../TESTING.md)).

This constraint is repeated in both reports so nobody mistakes a green
checklist for a successful test run.
