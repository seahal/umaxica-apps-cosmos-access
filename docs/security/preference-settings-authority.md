# Preference Settings Authority

## Current local writers

The retained preference write boundary is limited to Auth and Visa APP/ORG:

- Auth APP and ORG save actor and anonymous Preference state through their explicit writer.
- Visa APP and ORG reflect explicit actor preferences after sign-in and rebuild anonymous state
  after sign-out.
- No removed product surface has local Preference route or write authority in Access.

The full operation map and transition rules are in the current
[Preference behavior contract](../architecture/preference-behavior-contract.md). The Preference JWT
is a signed read projection; request parameters and cookie contents do not select a database row or
account.

## Retained persistence history

Preference models, option records, consent receipts, browser-binding records, migrations, and
database connections remain pending the separate model/database usage report. Their presence does
not establish an active route or writer. The former Base/COM, Core, Warp, Edit, and Tech writer
assignments are retired and must not be used as current guidance.

## Related

- [Preference architecture](../architecture/preference.md)
- [Preference behavior contract](../architecture/preference-behavior-contract.md)
- [Identity authority boundary](../identity/authority-boundary.md)
