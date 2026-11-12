# Building the Android APK on GitHub

`.github/workflows/android.yml` builds release APKs on GitHub's servers, so
you don't need Flutter, Rust or the Android SDK locally.

## Getting an APK

The workflow runs on every push to `main` or any `claude/**` branch. You can
also start it by hand: **Actions → Android APK → Run workflow**.

When the run finishes (roughly 20–40 minutes; the Rust code is compiled for
both phone architectures), open it and download **prism-android-apk** under
**Artifacts**. It's a zip containing `Prism-<version>-<commit>.apk` (works on
any ARM Android phone running Android 8.0 or later) and `SHA256SUMS`.

On the phone, open the APK and allow "Install unknown apps" for your browser
or file manager when Android asks.

Artifacts are kept for 30 days.

## Installing updates without losing data (recommended)

Android only installs an APK over an existing one if both are signed with the
same key. Without setup, each GitHub build is signed with a new throwaway
debug key, so to install a newer build you must uninstall the old one first,
which **erases the app's data**. Export your data first (Settings → Import &
export) if you go that way.

To sign every build with the same key, create a keystore once and add it as
repository secrets.

1. Create the keystore (needs Java's `keytool`; any machine works, including
   GitHub Codespaces):

   ```bash
   keytool -genkey -v -keystore prism-upload.jks -storetype JKS \
     -keyalg RSA -keysize 2048 -validity 10000 -alias prism
   ```

2. Turn it into text:

   ```bash
   base64 -w0 prism-upload.jks > prism-upload.jks.b64
   ```

3. In GitHub: **Settings → Secrets and variables → Actions → New repository
   secret**, add:

   | Secret | Value |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | contents of `prism-upload.jks.b64` |
   | `ANDROID_KEYSTORE_PASSWORD` | the keystore password you chose |
   | `ANDROID_KEY_ALIAS` | `prism` |
   | `ANDROID_KEY_PASSWORD` | the key password (same as the keystore password if you pressed Enter) |

4. Keep `prism-upload.jks` and its password somewhere safe. If you lose it,
   future builds can't update an installed app.

The first signed build still needs one uninstall if you previously installed
a debug-signed one.
