# Freshservice Self-Healing Workflow

## Overview

This project documents a service-desk automation pattern that allows a common infrastructure issue to be remediated automatically from an IT service request.

The goal is to resolve predictable problems without requiring a technician to manually connect to a server every time.

## Scenario

A business-critical reporting process depends on a Windows service.

When the service stops:

1. a user notices that a report was not generated
2. the user submits a service request
3. the workflow checks or triggers the appropriate remediation
4. a least-privileged service identity restarts the required service
5. the requester receives an automated status update
6. unresolved cases remain available for technician escalation

## Why This Matters

Without automation, the same issue requires repeated manual intervention.

With automation:

- response time improves
- repetitive technician work decreases
- the user receives faster feedback
- engineers focus on exceptions instead of routine remediation

## Security Principles

- least-privileged service account
- limited remediation scope
- audit trail
- clear failure path
- human escalation when automation does not resolve the issue

## Repository Status

This project is a sanitized reconstruction of an enterprise automation pattern. No employer code, credentials, customer information, or internal infrastructure details are included.
