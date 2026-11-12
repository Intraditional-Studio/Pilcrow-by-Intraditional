# Security

## Supported versions

Security fixes are provided for the latest released version of Pilcrow.

| Version | Supported |
| ------- | --------- |
| 1.0.x   | Yes       |
| < 1.0   | No        |

## Reporting a vulnerability

Please report security issues privately rather than opening a public
issue. Include:

- the Pilcrow version (Settings → footer, or `CFBundleShortVersionString`)
- your macOS version and Mac architecture
- a description of the issue and, if possible, reproduction steps

You should receive an acknowledgement within a few business days. Please
allow reasonable time for a fix before disclosing the issue publicly.

## Scope

Pilcrow stores a GitHub token in the macOS Keychain and reads local git
repositories. Reports about token handling, credential leakage, path
traversal, shell invocation, or unintended network requests are especially
welcome.

## Release integrity

Release builds are ad-hoc signed unless noted otherwise. Published
archives include a SHA-256 checksum. Verify it before installing:

```sh
shasum -a 256 -c Pilcrow-1.0.0.zip.sha256
```
