/// 'auto', 'cpu' or 'gpu'.
String webRendererMode() => 'auto';

/// Whether software rendering is in use right now.
bool webUsesCpuRendering() => false;

/// Why automatic mode chose software rendering (null if it didn't).
String? webRendererReason() => null;

/// Saves the choice and reloads the page so it takes effect.
void setWebRendererMode(String mode) {}

/// Tells the page's startup check how far Prism got (web only).
void markWebStage(String stage) {}

/// Records an error for the page's startup check (web only).
void reportWebError(String message) {}
