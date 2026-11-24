# Relating the integration inventory to proof results

Run `just source-status` for aggregate JSON, or
`python3 scripts/source_verification_status.py --details` to include the
v1 rule IDs, verification records and theorem names for every v0.1 entry.
The input is the current `rules/meta.json` load manifest and the current
`v1/integration.osr.json`; the report includes the v1 SHA-256 and build data.
It does not fetch RUBI or modify either input.

The tool joins exact `identity:id` provenance identifiers. It reports the
original migrated entry separately for each domain as certified, proved but
not certified, counterexample, unproved, unsupported, missing domain evidence, or absent.
The categories partition the v0.1 entries. A separately counted certified
`strengthened:` variant can overlap any of those categories; its additional
assumptions do not prove the original entry. `generalized:` variants are also
reported separately. The variant classification relies on these markers in the
v1 `findings` field; duplicate original records or inconsistent proof status
cause an error instead of silently picking one.

These numbers refer to **OSR entries**, not independent source identities or
all rules executed by RUBI. A matching legacy ID is provenance, not a proof
of faithful source translation, of an identical matcher's evaluation order,
or of the completeness of the source's assumptions. The v1 file may contain
records from files outside the current default manifest; these are counted
separately and excluded from the partition. Missing v1 evidence means that no
corresponding original v1 entry was found; it does not mean the rule is false.

A certified theorem establishes the encoded Lean statement in its named domain
and fragment. For example, the present power interpretation covers integer
exponents only. Consumers must also respect all applicability, definedness,
independence and domain conditions; a theorem about that fragment does not by
itself license applying a corresponding RUBI rule to arbitrary powers. The
certificate and its theorem are evidence for a specified statement, not a
blanket guarantee about CAS execution. See [OSR v1](osr-v1.md) and
[symbolic verification](symbolic-verification.md).
