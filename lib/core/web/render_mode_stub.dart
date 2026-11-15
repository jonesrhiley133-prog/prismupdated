/// 'auto', 'cpu' or 'gpu'.
String webRendererMode() => 'auto';

/// Whether software rendering is in use right now.
bool webUsesCpuRendering() => false;

/// Why automatic mode chose software rendering (null if it didn't).
String? webRendererReason() => null;

/// Saves the choice and reloads the page so it takes effect.
void setWebRendererMode(String mode) {}
