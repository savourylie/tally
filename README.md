# tally

## Network Extension Signing

Ticket 023 adds `TallyFilterExtension`, a macOS System Extension that uses the
Network Extension content-filter provider entitlement. Local unsigned builds can
still compile with `CODE_SIGNING_ALLOWED=NO`, but real data collection needs an
Apple Developer team and provisioning profiles configured manually in Xcode.

Required capabilities on both the `Tally` app target and
`TallyFilterExtension` target:

- App Groups: `group.com.calvinku.Tally`
- Network Extensions: `content-filter-provider`

The `Tally` app target also needs the System Extension install capability
(`com.apple.developer.system-extension.install`) so it can submit
`OSSystemExtensionRequest` activation requests.

Use the normal Debug scheme with `OTHER_SWIFT_FLAGS="-DUSE_NETTOP"` when you
need the previous `nettop` collector during local development. Without that flag,
the app starts the Network Extension collector path.
