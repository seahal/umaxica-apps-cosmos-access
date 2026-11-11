# Historical Auth Settings to Base Identity Migration

This document records the earlier proposal to move general identity-management pages from Auth to
Base. The 2026-11-10 Access surface reset removed Base routes and controllers; this migration is not
a current Access route or ownership contract.

Current local ownership is Auth APP/ORG credential ceremonies and Visa APP/ORG OpenID Provider and
session authority. Access has no Base identity-management surface. External relying parties own
their account and profile interfaces in their own repositories. Persisted models and migrations
remain pending the separate model/database usage report.

Keep the earlier accepted decisions as historical context in
[`adr/identity-authority-boundary.md`](../../adr/identity-authority-boundary.md) and
[`adr/base-auth-ceremony-and-seven-rp-boundary.md`](../../adr/base-auth-ceremony-and-seven-rp-boundary.md).
Do not use the route proposals below as instructions for adding routes to Access.
