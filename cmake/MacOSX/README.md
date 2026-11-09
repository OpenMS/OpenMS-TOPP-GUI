## macOS Code Signing and Notarization

The macOS package of the OpenMS GUI is code signed and notarized to ensure users can run it without security warnings from Gatekeeper.

The GUI package installs into the folder of the OpenMS core package of the same version, and its
applications load the libraries of the core. With the hardened runtime, macOS loads only libraries
signed by the same team, so both packages have to be signed with the certificates of the same team
(OpenMS Inc., `C64UCGJ5PL`).

### Prerequisites

1. **Apple Developer Account** ($99/year) - https://developer.apple.com
2. **Xcode** installed with developer tools (`xcode-select --install`)
3. **Certificates** exported from Xcode:
   - **Developer ID Application** - for signing binaries
   - **Developer ID Installer** - for signing .pkg installers

### Required GitHub Secrets

For CI/CD, the following secrets must be configured in your GitHub repository.

**Note:** Only certificates and passwords need to be secrets. Identity strings and email addresses are public information.

| Secret | Description |
|--------|-------------|
| `APPLE_DEVELOPER_ID_APPLICATION_CERT` | Base64-encoded Developer ID Application .p12 certificate |
| `APPLE_DEVELOPER_ID_APPLICATION_PASSWORD` | Password for the Application certificate |
| `APPLE_DEVELOPER_ID_INSTALLER_CERT` | Base64-encoded Developer ID Installer .p12 certificate |
| `APPLE_DEVELOPER_ID_INSTALLER_PASSWORD` | Password for the Installer certificate |
| `APPLE_APP_SPECIFIC_NOTARIZATION_PASSWORD` | App-specific password for notarization |
| `KEYCHAIN_PASSWORD` | Password for the temporary CI keychain |

The following are configured directly in the workflow (not secrets):
- **Signing Identity**: `Developer ID Application: OpenMS Inc. (C64UCGJ5PL)`
- **Installer Identity**: `Developer ID Installer: OpenMS Inc. (C64UCGJ5PL)`
- **Email**: `apple@openms.de`
- **Team ID**: `C64UCGJ5PL` (extracted from the identity string)

### Exporting Certificates

1. Open **Xcode → Settings → Accounts**
2. Select your Team and click **Manage Certificates**
3. Create or select **Developer ID Application** certificate
4. Right-click → **Export Certificate** → save as `.p12` with a password
5. Base64 encode for CI: `base64 -i certificate.p12 | pbcopy`
6. Repeat for **Developer ID Installer** certificate

### Finding Your Identity Strings and Team ID

Run this command to see your available signing identities:

```shell
security find-identity -v -p codesigning
```

Output example:
```
1) ABC123XYZ... "Developer ID Application: OpenMS Inc. (C64UCGJ5PL)"
2) DEF456ABC... "Developer ID Installer: OpenMS Inc. (C64UCGJ5PL)"
   2 valid identities found
```

- The full quoted string is your identity (e.g., `Developer ID Application: OpenMS Inc. (C64UCGJ5PL)`)
- The 10-character code in parentheses is your Team ID (e.g., `C64UCGJ5PL`)

### Creating an App-Specific Password

For notarization, create an app-specific password:

1. Go to https://appleid.apple.com
2. Sign in → Security → App-Specific Passwords → Generate
3. Use this password for `APPLE_APP_SPECIFIC_NOTARIZATION_PASSWORD`

### Local Testing

To test code signing locally:

```shell
# Sign a binary
codesign --force --options runtime --timestamp -s "Developer ID Application: Your Name (TEAMID)" /path/to/binary

# Verify signature
codesign -dv --verbose=4 /path/to/binary

# Notarize a package (requires CODESIGNPW environment variable)
export CODESIGNPW="your-app-specific-password"
./cmake/MacOSX/notarize.sh package.pkg de.openms.gui your@email.com CODESIGNPW TEAMID .

# Verify notarization
spctl -a -vvv -t install package.pkg
```

### Troubleshooting

**"The specified item could not be found in the keychain"**
- Ensure the certificate is imported in the keychain
- Verify the identity string matches exactly (run `security find-identity -v`)

**Notarization fails with "Invalid"**
- Check if all binaries inside the package are signed with hardened runtime
- Get detailed log: `xcrun notarytool log <submission-id> --apple-id EMAIL --password PW --team-id TEAM log.json`

**"Developer cannot be verified" warning for users**
- The package was not notarized or stapling failed
- Users can override: System Settings → Privacy & Security → Allow

### Files in this Directory

- `notarize.sh` - Script for notarizing packages (.pkg, .dmg, .zip) using notarytool:
  `notarize.sh <package> <bundle_id> <apple_id> <password_env_var> <team_id> [log_folder]`
- `fix_dependencies.rb` - Script to fix library paths for distribution (cmake/package_mac_productbuild.cmake)
- `openms_logo_corner_small.png` - Background of the installer
