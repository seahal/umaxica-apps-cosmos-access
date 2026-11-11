# AWS Account: Keep an Audit Trail and Spending Alerts (2026-11-11)

Owner: owner (AWS account operations). Status: queued.

## Why

On 2026-11-11 an IAM access key leaked through public Git history (decryptable from 2025-09-03) was
found still present in AWS account `841162677945`: created 2025-05-02, last used 2026-03-19 15:30
JST, attached to a user with `AmazonSesSendingAccess`. The user was deleted the same day. What the
2026-03-19 use was could not be determined: CloudTrail event history keeps only 90 days and no trail
stored older events. SES showed no sending activity.

## To do

- Create one CloudTrail trail for management events, all Regions, delivered to an S3 bucket with a
  retention policy (the first management-event trail has no CloudTrail charge; S3 storage applies).
  CloudTrail Lake is closed to new customers since 2026-05-31 and is not used.
- AWS Budgets alert on daily cost (for example above 100 yen; normal spend is about 10 yen a day).
- Consider enabling GuardDuty for anomalous credential use.
- Keep root MFA enabled; review IAM users and access keys periodically (no unused long-term keys).

Record results in `evidence/` without secrets.
