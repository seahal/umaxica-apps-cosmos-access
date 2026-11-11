# Close the Unused Twilio Account (2026-11-11)

Owner: owner. Status: queued, low priority.

## Facts

- A Twilio Account SID (ending `c123`) and its Auth Token were in the development credentials
  decryptable from public Git history from 2025-09-03; the variable names were also in a committed
  `.env` from about 2025-04-29 (with short or empty values there).
- Twilio is not used: SMS was never successfully sent through it, and the application moved to AWS
  SNS. No current credentials in the four Cosmos repositories contain Twilio values.
- The owner cannot sign in: multi-factor authentication is bound to a telephone number no longer
  available (2026-11-11).

## Risk

Low. An account that never sent SMS is most likely a trial account (trial credit only, sending only
to verified numbers). If a payment method is registered, a leaked Auth Token could still incur
charges.

## To do

1. Check email and card statements for Twilio invoices, balance or suspension notices.
2. Ask Twilio support for an MFA reset or, preferably, to close the account, stating that the
   credentials leaked.
3. If access is restored first: review Monitor > Logs and billing since 2025-04, then close the
   account.

Record the outcome in `evidence/` without secrets.
