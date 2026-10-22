# eMudhra TLS trust regression fixtures

These are public certificates from the incident checker maintained by Dennis Jackson and contributors:

- Incident details: https://emudhra.we-have-a-problem.com/
- Cloudflare guidance: https://blog.cloudflare.com/emudhra-certificate-compromise/
- Source revision: https://github.com/galadran/we-have-a-problem.com/tree/45ebb3affd94fcbc09258d5ae6c96eef7a8097e6
- Chains: https://emudhra.we-have-a-problem.com/chains.zip
- Control roots: https://emudhra.we-have-a-problem.com/roots.json

Retrieved on 2026-10-22. `chains/*.pem` contains the twelve original TLS chains, leaf first.
`roots.pem` concatenates the four original root certificates from `roots.json` solely for positive
controls. These roots must never be installed into the image's actual trust stores.
`fixtures.sha256` records SHA-256 digests of all certificate fixture files.

`control-root.pem` and `control-chain.pem` are locally generated, unrelated EC test certificates
used as Java's positive control. Their private keys were discarded. This control must validate,
while each compromised chain must be rejected by the actual Java trust manager. Using the
compromised chains as Java's positive control would incorrectly fail on JDKs with a global blocklist.

The chains cover DV, OV and EV TLS intermediates in the G3B/G3C generations, including their
AAA cross-signs. They are certificate data, not executable code, and no private keys are included.
The leaf certificates expire in May 2027; renew the fixtures from the source before expiry.

See `DEVELOPER.md` for how to run the check. Exit 0 means the tested stores reject all fixture
chains, exit 1 means compromised trust was detected, and exit 2 means validation was inconclusive.
Both nonzero outcomes fail image validation. Runtime network access is disabled by the caller.
