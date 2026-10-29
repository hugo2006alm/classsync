# ClassSync v0.3.27

- Windows Settings → Automation now offers independent Launch with Windows and Start minimized switches, also available during setup.
- Choose a visible window or a quiet system tray launch at Windows sign-in. Shortcuts and tray actions open the window; background sync continues while hidden.
- Existing installations retain their startup choice and hidden-at-login behavior. Preferences remain local to each PC.
- Prevent the window flashing during hidden startup and keep duplicate login launches from raising an existing window.
- Restore the original window and taskbar entry reliably when opening a shortcut after a tray-only launch.
- Refresh relay development dependencies to patched versions required by the release security checks.
- Pin Java 17 for Android release CI to avoid incompatible runner defaults. v0.3.26 was not published.

Windows artifacts are unsigned because a publisher certificate is not configured. Android uses the existing release signing identity.
