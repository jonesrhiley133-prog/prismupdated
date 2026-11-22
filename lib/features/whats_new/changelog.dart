import 'package:flutter/foundation.dart';

/// Text in each supported language; falls back to English.
@immutable
class LocalizedText {
  const LocalizedText(this.en, [this.es]);

  final String en;
  final String? es;

  String of(String languageCode) => languageCode == 'es' ? (es ?? en) : en;
}

@immutable
class ChangelogRelease {
  const ChangelogRelease({
    required this.version,
    required this.date,
    this.features = const [],
    this.improvements = const [],
    this.fixes = const [],
  });

  /// Matches `version:` in pubspec.yaml (without the build number).
  final String version;
  final DateTime date;
  final List<LocalizedText> features;
  final List<LocalizedText> improvements;
  final List<LocalizedText> fixes;
}

/// Newest first. Add an entry (and bump pubspec.yaml) with every release.
final List<ChangelogRelease> prismChangelog = [
  ChangelogRelease(
    version: '0.39.1',
    date: DateTime(2026, 11, 22),
    fixes: const [
      LocalizedText(
        'Updates install over the app again instead of needing an uninstall: every build is now signed with the same key (a build without it stops instead of using a throwaway key) and gets a version number higher than any before it.',
        'Las actualizaciones vuelven a instalarse encima de la app sin desinstalarla: cada versión se firma con la misma clave (sin ella, la compilación se detiene en lugar de usar una clave temporal) y recibe un número de versión mayor que cualquier anterior.',
      ),
      LocalizedText(
        'In-app updates now come from GitLab builds, and before opening the installer Prism checks that the download can replace the app, explaining a different key or an older build instead of Android’s “App not installed”.',
        'Las actualizaciones dentro de la app llegan ahora de las compilaciones de GitLab y, antes de abrir el instalador, Prism comprueba que la descarga puede reemplazar la app; si la clave es otra o la versión es más antigua, lo explica en lugar del «App no instalada» de Android.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.39.0',
    date: DateTime(2026, 11, 22),
    features: const [
      LocalizedText(
        'Medium brightness: a new setting between Light and Dark — soft mid-tone surfaces with light text. Pick it in Settings › Appearance › Brightness; it works with the Prism and Palette styles and with your looks.',
        'Brillo medio: un ajuste nuevo entre Claro y Oscuro, con superficies de tono medio y texto claro. Elígelo en Ajustes › Apariencia › Brillo; funciona con los estilos Prism y Paleta y con tus apariencias.',
      ),
      LocalizedText(
        'Each alter’s profile page can have its own brightness: Light, Medium, Dark or follow the app. Set it in the profile studio under Colours & background.',
        'La página de perfil de cada alter puede tener su propio brillo: Claro, Medio, Oscuro o como la app. Configúralo en el estudio de perfil, en Colores y fondo.',
      ),
      LocalizedText(
        'Seventeen new Palette moods: Neutral, Content, Rainbow and Fruit salad; Prism moods Pastel, Neon, Earthy, Jewel, Sunset, Ocean, Forest and Candy; colour harmonies Complementary, Analogous, Triadic and Split complementary; and Custom, where you pick the second and highlight accents that go with your colour.',
        'Diecisiete estilos nuevos de Paleta: Neutro, Contenido, Arcoíris y Macedonia; estilos de Prism Pastel, Neón, Terroso, Joya, Atardecer, Océano, Bosque y Caramelo; armonías Complementario, Análogo, Triádico y Complementario dividido; y Personalizado, donde eliges el segundo acento y el de realce que combinan con tu color.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.38.1',
    date: DateTime(2026, 11, 20),
    improvements: const [
      LocalizedText(
        'Smoother typing in chat: a keystroke no longer redraws the whole message bar, and proxy tags are no longer re-read for every headmate on each letter.',
        'Escribir en el chat es más fluido: una tecla ya no vuelve a dibujar toda la barra de mensajes y las etiquetas de proxy ya no se releen para cada alter con cada letra.',
      ),
      LocalizedText(
        'Music no longer keeps the screen redrawing several times a second: the progress bar moves when it would actually move, and the full player only updates its seek bar.',
        'La música ya no hace que la pantalla se vuelva a dibujar varias veces por segundo: la barra de progreso se mueve cuando de verdad cambia y el reproductor completo solo actualiza su barra de avance.',
      ),
      LocalizedText(
        'Long Headmates lists with banners scroll more smoothly: banners and avatars that scroll back into view reuse the image already loaded instead of loading it again.',
        'Las listas largas de alters con banners se desplazan con más fluidez: los banners y avatares que vuelven a verse reutilizan la imagen ya cargada en lugar de cargarla de nuevo.',
      ),
      LocalizedText(
        'Live timers (fronting, habits) pause while their page is hidden and catch up the moment it shows again; opening a profile reuses its colour theme; the Headspace Mapper, analytics, Relationships, Subsystems and Dictionary load when you open them.',
        'Los temporizadores en vivo (frente, hábitos) se pausan mientras su página está oculta y se ponen al día al volver; abrir un perfil reutiliza su tema de color; el mapa del espacio interno, las estadísticas, Relaciones, Subsistemas y el Diccionario se cargan al abrirlos.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.38.0',
    date: DateTime(2026, 11, 20),
    features: const [
      LocalizedText(
        'Health: a private place to record how you feel. Log a symptom in a word or add full details — onset, severity, pattern, triggers, what helped, effects on sleep or school, temperature and notes — with follow-ups (still happening, changed, resolved), illness episodes and a filtered summary export.',
        'Salud: un lugar privado para anotar cómo te sientes. Registra un síntoma con una palabra o con todos los detalles (inicio, gravedad, evolución, desencadenantes, qué ayudó, efectos en el sueño o la escuela, temperatura y notas), con seguimientos (sigue, cambió, resuelto), episodios y un resumen exportable con filtros.',
      ),
      LocalizedText(
        'The Body Map moved from Mood into Health and was rebuilt: front and back figures plus face, hand and foot views, the body’s own left and right, exact points or whole areas, several spots per entry, region-specific sensation words, custom words and “spreads to”. Body sensations already saved on Mood check-ins appear there unchanged.',
        'El mapa corporal pasó de Ánimo a Salud y se rehízo: figuras de frente y espalda, vistas de cara, manos y pies, izquierda y derecha del propio cuerpo, puntos exactos o zonas completas, varios puntos por entrada, palabras según la zona, palabras propias y “se extiende a”. Las sensaciones guardadas en Ánimo aparecen allí sin cambios.',
      ),
      LocalizedText(
        'Fitness › Connected apps: connect Health Connect or Apple Health type by type, see each type’s result after a sync, choose how much history to import, and import Apple Health, Google Fit or Samsung Health export files on any device.',
        'Ejercicio › Apps conectadas: conecta Health Connect o Apple Health tipo por tipo, mira el resultado de cada tipo tras sincronizar, elige cuánto historial importar e importa archivos de Apple Health, Google Fit o Samsung Health en cualquier dispositivo.',
      ),
    ],
    fixes: const [
      LocalizedText(
        'Fixed workouts never importing from Health Connect: Prism didn’t ask for the calorie, distance and step access that reading a workout needs, and the failure was silent. Partly allowed access no longer blocks the whole sync, Samsung Health calories are read, and syncing again never duplicates days or workouts.',
        'Corregido que los entrenamientos nunca se importaran desde Health Connect: Prism no pedía el acceso a calorías, distancia y pasos que necesita leer un entrenamiento, y el fallo era silencioso. Un permiso parcial ya no bloquea toda la sincronización, se leen las calorías de Samsung Health y sincronizar otra vez nunca duplica días ni entrenamientos.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.37.0',
    date: DateTime(2026, 11, 16),
    improvements: const [
      LocalizedText(
        'Tabs, views and step-by-step screens inside pages now animate too: Calendar, Availability, Mood, Fitness, Finance, School, Dream journal, Cycle insights, Scrapbook, Statuses, Bulletin, Social hub, Automations, the look editor, Profile Studio, the data browser, and the import, backup, PIN, device setup and upgrade wizards.',
        'Las pestañas, vistas y pantallas paso a paso dentro de las páginas ahora también se animan: Calendario, Disponibilidad, Ánimo, Fitness, Finanzas, Escuela, Diario de sueños, Ciclo, Álbum, Estados, Tablón, Social, Automatizaciones, el editor de apariencia, Profile Studio, el explorador de datos y los asistentes de importación, copia de seguridad, PIN, configuración de dispositivo y actualización.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.36.0',
    date: DateTime(2026, 11, 16),
    improvements: const [
      LocalizedText(
        'Every way of moving between sections is animated: the navigation bar, the desktop sidebar, search (Ctrl/⌘+K) and links into another section fade the new section in. Pages opened on top keep their slide/fade transition on every platform, including the web on Windows and Linux. Turning on Reduce motion switches these off.',
        'Todas las formas de cambiar de sección están animadas: la barra de navegación, la barra lateral de escritorio, la búsqueda (Ctrl/⌘+K) y los enlaces a otra sección muestran la nueva sección con un fundido. Las páginas que se abren encima mantienen su transición en todas las plataformas, incluida la web en Windows y Linux. Reducir movimiento las desactiva.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.35.0',
    date: DateTime(2026, 11, 15),
    fixes: const [
      LocalizedText(
        'Tapping an introduction card on the table flips it again; long-press or Enlarge in its menu shows it large.',
        'Tocar una tarjeta de presentación en la mesa vuelve a girarla; mantén pulsado o usa Ampliar en su menú para verla en grande.',
      ),
      LocalizedText(
        'Headmate banners fill the whole row in the Headmates list instead of a panel on the right, with an even dim (no fade) and light text so names stay readable.',
        'Los banners de los headmates ocupan toda la fila en la lista en lugar de un panel a la derecha, con un oscurecido uniforme (sin degradado) y texto claro para que los nombres se lean bien.',
      ),
      LocalizedText(
        'The navigation bar opens smoothly: its extra rows stay ready instead of being built in the first frame of the animation.',
        'La barra de navegación se abre con fluidez: sus filas extra quedan preparadas en lugar de crearse en el primer fotograma de la animación.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Smoother busy pages: dashboard cards, introduction cards and the navigation bar repaint on their own instead of together.',
        'Páginas con mucho contenido más fluidas: las tarjetas del panel, las de presentación y la barra de navegación se redibujan por separado.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.34.0',
    date: DateTime(2026, 11, 15),
    features: const [
      LocalizedText(
        '17 new app icons, all keeping the Prism pyramid: five new designs (Eclipse, Opal, Obsidian, Ultraviolet, Tide) and 12 gentle plurality designs — Constellation, Facets, Many Moons, Chrysalis, Headspace, Harmony, Garden, Reflection, Murmuration, Threads, Lanterns and Chorus.',
        '17 iconos nuevos, todos con la pirámide de Prism: cinco diseños nuevos (Eclipse, Ópalo, Obsidiana, Ultravioleta, Marea) y 12 diseños suaves sobre la pluralidad: Constelación, Facetas, Muchas lunas, Crisálida, Espacio interior, Armonía, Jardín, Reflejo, Bandada, Hilos, Faroles y Coro.',
      ),
      LocalizedText(
        'The icon designer can use any of 56 symbols instead of the Prism, with its own colour, and every colour — background, aura and symbol — can be fine-tuned with hue, saturation and brightness sliders. Backgrounds can be a gradient, radial or solid.',
        'El diseñador de iconos puede usar cualquiera de 56 símbolos en lugar del prisma, con su propio color, y cada color (fondo, aura y símbolo) se ajusta con controles de tono, saturación y brillo. El fondo puede ser degradado, radial o sólido.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Introductions are laid out like a deck on a table: smaller cards with a slight hand-dealt tilt. Tap a card to flip it; long-press (or Enlarge in its menu) to lift it up large.',
        'Las presentaciones se muestran como una baraja sobre la mesa: tarjetas más pequeñas con una ligera inclinación. Toca una tarjeta para girarla; mantén pulsado (o Ampliar en su menú) para verla en grande.',
      ),
      LocalizedText(
        'Recolour any introduction card with hue, saturation and brightness sliders for its background, border and text — card designs use the same sliders.',
        'Cambia los colores de cualquier tarjeta con controles de tono, saturación y brillo para el fondo, el borde y el texto; los diseños de tarjeta usan los mismos controles.',
      ),
      LocalizedText(
        'Rings and glows on the Prism icons are centred on the pyramid.',
        'Los anillos y brillos de los iconos de Prism se centran en la pirámide.',
      ),
      LocalizedText(
        'The web version shows its progress while it starts, and explains what to do if it gets stuck instead of staying blank.',
        'La versión web muestra su progreso al iniciar y explica qué hacer si se queda atascada en lugar de quedarse en blanco.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.33.0',
    date: DateTime(2026, 11, 15),
    features: const [
      LocalizedText(
        'The web version is now laid out for desktop: a docked sidebar with every section grouped by category, wider pages, a two-column home dashboard, left-aligned page titles and Ctrl/⌘+K to jump anywhere. Phones and the mobile apps are unchanged.',
        'La versión web ahora está diseñada para escritorio: barra lateral con todas las secciones por categoría, páginas más anchas, panel de inicio a dos columnas, títulos a la izquierda y Ctrl/⌘+K para ir a cualquier sitio. Los teléfonos y las apps móviles no cambian.',
      ),
      LocalizedText(
        'Change Prism’s icon in Settings › Appearance › App icon: 14 aura designs plus the classic icon — or design your own with colours, an aura and the Prism, an emoji or a photo.',
        'Cambia el icono de Prism en Ajustes › Apariencia › Icono de la app: 14 diseños con aura además del clásico, o crea el tuyo con colores, un aura y el prisma, un emoji o una foto.',
      ),
    ],
    fixes: const [
      LocalizedText(
        'Fixed the web version looking grainy, dithered or garbled on some computers: Prism detects problem graphics drivers and switches to compatibility rendering (also selectable in Settings › Appearance).',
        'Corregido que la versión web se viera granulada o corrupta en algunos ordenadores: Prism detecta drivers gráficos problemáticos y usa el renderizado de compatibilidad (también en Ajustes › Apariencia).',
      ),
      LocalizedText(
        'Month calendars stay a comfortable size on large screens.',
        'Los calendarios mensuales mantienen un tamaño cómodo en pantallas grandes.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.32.0',
    date: DateTime(2026, 11, 15),
    features: const [
      LocalizedText(
        'Dictionary wiki imports keep going in the background: leave the import page, move around Prism or switch apps and the import continues (with a progress notification on Android). If Prism is closed, it picks up where it left off next time.',
        'Las importaciones de wikis al diccionario siguen en segundo plano: sal de la página, muévete por Prism o cambia de app y la importación continúa (con una notificación de progreso en Android). Si Prism se cierra, continúa donde se quedó.',
      ),
      LocalizedText(
        'New “All” option imports every article of a wiki or category, about 20× faster than before.',
        'Nueva opción «Todos» para importar todos los artículos de una wiki o categoría, unas 20 veces más rápido.',
      ),
      LocalizedText(
        'Flags are imported from wikis that have them, including alternate flags, and shown on each term. Download one flag, or all of them as a ZIP, to your device.',
        'Se importan las banderas de las wikis que las tienen, también las alternativas, y se muestran en cada término. Descarga una o todas (en ZIP) a tu dispositivo.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'The import list scrolls smoothly even with thousands of terms, the Import button stays at the top, and new buttons jump to the top or bottom.',
        'La lista de importación se desplaza con fluidez incluso con miles de términos, el botón Importar queda arriba y hay botones para ir al principio o al final.',
      ),
      LocalizedText(
        'Large dictionaries scroll faster.',
        'Los diccionarios grandes se desplazan más rápido.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.31.0',
    date: DateTime(2026, 11, 15),
    features: const [
      LocalizedText(
        'Prism Social can now connect to a Prism Social server (Social settings › Connection), so systems on different people’s phones can become friends, message each other — alter to alter too — post, comment and react. Photos are shared through the server.',
        'Prism Social ahora puede conectarse a un servidor de Prism Social (Ajustes sociales › Conexión): sistemas en teléfonos de distintas personas pueden ser amigos, escribirse —también de alter a alter—, publicar, comentar y reaccionar. Las fotos se comparten a través del servidor.',
      ),
      LocalizedText(
        'Bring your existing Social profiles and alter profiles to the server when you connect. All your devices share the connection automatically.',
        'Lleva tus perfiles sociales y de alters al servidor al conectarte. Todos tus dispositivos comparten la conexión automáticamente.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'The server enforces the same privacy rules as the app: blocked people disappear both ways, friends-only and circle posts stay private, and nothing from the rest of Prism is ever sent. You can delete your server account at any time.',
        'El servidor aplica las mismas reglas de privacidad que la app: las personas bloqueadas desaparecen en ambos sentidos, las publicaciones de amigos y círculos siguen privadas y nunca se envía nada más de Prism. Puedes eliminar tu cuenta del servidor cuando quieras.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.30.0',
    date: DateTime(2026, 11, 15),
    features: const [
      LocalizedText(
        'Prism Social: a feed, friends, friend requests, messages, Discover, profiles and notifications between systems. Alters can have their own profiles and message each other, always shown together with their system.',
        'Prism Social: muro, amigos, solicitudes, mensajes, Descubrir, perfiles y avisos entre sistemas. Los alters pueden tener perfil propio y escribirse entre ellos, siempre junto a su sistema.',
      ),
      LocalizedText(
        'Posts with likes, comments, bookmarks and reblogs that keep credit to the original author, plus private circles and per-post audiences.',
        'Publicaciones con me gusta, comentarios, guardados y rebloqueos que mantienen el crédito del autor original, además de círculos privados y audiencias por publicación.',
      ),
      LocalizedText(
        'Custom profile themes (accent, background, cards, font, layout) with a live preview and a “Use my custom profile theme” switch.',
        'Temas de perfil personalizados (acento, fondo, tarjetas, fuente, diseño) con vista previa y el interruptor “Usar mi tema de perfil personalizado”.',
      ),
      LocalizedText(
        'Share to Social from Achievements, Habits, Fitness and School — you choose exactly which details to include. Nothing is ever shared automatically.',
        'Comparte en Social desde Logros, Hábitos, Fitness y Escuela — eliges qué detalles incluir. Nunca se comparte nada automáticamente.',
      ),
      LocalizedText(
        'Social works between the systems managed in your Prism account and syncs across your devices. Reaching other people’s systems will need a Prism Social server, which isn’t available yet.',
        'Social funciona entre los sistemas de tu cuenta y se sincroniza entre tus dispositivos. Llegar a sistemas de otras personas requerirá un servidor de Prism Social, aún no disponible.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Social privacy controls: who can request, message, see your profile and alters; read receipts, online status, Discover visibility and blocking.',
        'Controles de privacidad social: quién puede enviarte solicitudes, escribirte, ver tu perfil y alters; confirmaciones de lectura, estado en línea, visibilidad en Descubrir y bloqueo.',
      ),
    ],
    fixes: const [
      LocalizedText(
        'Member card banners are no longer faded into the card colour — they show as they are with only a light dim.',
        'Los banners de las tarjetas de miembros ya no se funden con el color de la tarjeta: se ven tal cual, solo con un leve oscurecido.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.29.0',
    date: DateTime(2026, 11, 15),
    features: const [
      LocalizedText(
        'Settings › Features now lists every Prism feature by category, with descriptions, switches, dependencies, permissions and shortcuts — plus Minimal and Maximum presets (Minimal can be customised). Turning a feature off hides it and pauses its reminders and background work; its data is kept.',
        'Ajustes › Funciones ahora muestra todas las funciones de Prism por categoría, con descripciones, interruptores, dependencias, permisos y accesos — y los preajustes Mínimo y Máximo (Mínimo se puede personalizar). Desactivar una función la oculta y pausa sus avisos y procesos; sus datos se conservan.',
      ),
      LocalizedText(
        'Data management in every feature: reset today, this week, this month, this year or custom dates, or clear everything — with a clear confirmation, undo for 7 days where possible, and a reset history that keeps only counts.',
        'Gestión de datos en cada función: restablece hoy, esta semana, este mes, este año o fechas propias, o bórralo todo, con confirmación clara, deshacer durante 7 días cuando es posible y un historial que solo guarda recuentos.',
      ),
      LocalizedText(
        'Fitness connects to Health Connect (Android) or Apple Health (iPhone): an integration assistant walks you through setup, then workouts, steps, distance, calories, heart rate, active minutes and (optionally) sleep are imported with their source app, duplicates skipped, and each workout can belong to the system or an alter.',
        'Ejercicio se conecta con Health Connect (Android) o Apple Health (iPhone): un asistente te guía y luego se importan entrenamientos, pasos, distancia, calorías, frecuencia cardiaca, minutos activos y (opcional) sueño con su app de origen, sin duplicados, y cada entrenamiento puede ser del sistema o de un alter.',
      ),
      LocalizedText(
        'A universal Dictionary importer: paste any MediaWiki link (Wikipedia, Fandom, Miraheze, Pluralpedia, LGBTQ wikis, self-hosted), Wikidot, DokuWiki or public page; import single articles, categories or whole wikis with progress, cancel and retry; or import XML dumps, wikitext, HTML, JSON, CSV, Markdown and ZIP files. Preview and edit before saving, with import history and attribution.',
        'Importador universal del diccionario: pega cualquier enlace MediaWiki (Wikipedia, Fandom, Miraheze, Pluralpedia, wikis LGBTQ, propias), Wikidot, DokuWiki o página pública; importa artículos, categorías o wikis enteras con progreso, cancelar y reintentar; o importa volcados XML, wikitext, HTML, JSON, CSV, Markdown y ZIP. Vista previa y edición antes de guardar, con historial y atribución.',
      ),
    ],
    fixes: const [
      LocalizedText(
        'Subsystems (and the new Relationships pages) now reach both edges of the screen, and orbit cards no longer get cut off on phones.',
        'Subsistemas (y las nuevas páginas de Relaciones) ahora llegan a ambos bordes de la pantalla, y las tarjetas de la órbita ya no se cortan en teléfonos.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.28.0',
    date: DateTime(2026, 11, 15),
    features: const [
      LocalizedText(
        'A new Relationships hub: live statistics, an interactive relationship map (network, family, romantic, social and individual views) with zoom, pan, search, category filters, highlighting and hand-arranged positions, plus a list view for anyone who prefers text.',
        'Nuevo centro de Relaciones: estadísticas en vivo, un mapa interactivo de relaciones (vistas de red, familia, romántica, social e individual) con zoom, desplazamiento, búsqueda, filtros por categoría, resaltado y posiciones organizadas a mano, además de una vista de lista para quien prefiera texto.',
      ),
      LocalizedText(
        'Relationship profiles with multiple labels at once (siblings and best friends, for example), romantic, platonic, familial and other labels plus your own, status, confidence (confirmed, suspected, developing, uncertain, outdated), privacy, a description and ten optional dynamics.',
        'Perfiles de relación con varias etiquetas a la vez (por ejemplo hermanos y mejores amigos), etiquetas románticas, platónicas, familiares y otras más las tuyas, estado, certeza (confirmada, sospechada, en desarrollo, incierta, desactualizada), privacidad, descripción y diez dinámicas opcionales.',
      ),
      LocalizedText(
        'Notes, a chronological timeline with categories and attachments, and dated check-ins with your own questions, a ratings chart and side-by-side comparison for every relationship.',
        'Notas, una cronología con categorías y adjuntos, y registros fechados con tus propias preguntas, gráfico de puntuaciones y comparación lado a lado para cada relación.',
      ),
      LocalizedText(
        'Family tree: family groups arranged by generation, with add, edit and remove, family notes, and alters in more than one family.',
        'Árbol familiar: grupos familiares ordenados por generación, con añadir, editar y quitar, notas familiares y alters en varias familias.',
      ),
      LocalizedText(
        'Randomize relationship: suggests a possible connection from what you documented — ages, roles, interests and existing relationships — explains why, lists what’s missing, and only saves after you confirm (as “suspected”).',
        'Relación aleatoria: sugiere una conexión posible a partir de lo documentado (edades, roles, intereses y relaciones existentes), explica por qué, indica lo que falta y solo guarda tras tu confirmación (como «sospechada»).',
      ),
      LocalizedText(
        'Insights and per-relationship summaries drawn only from your records, each showing the relationships it’s based on. They can be turned off.',
        'Perspectivas y síntesis por relación basadas solo en tus registros, cada una indicando de qué relaciones procede. Se pueden desactivar.',
      ),
      LocalizedText(
        'Each alter’s profile lists their relationships, read from their side (a parent’s child sees “Child”). It’s the same single record everywhere.',
        'El perfil de cada alter muestra sus relaciones desde su lado (el hijo ve «Hija/hijo»). Es el mismo registro en todas partes.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Relationship settings for colours, custom categories and labels, map preferences, check-in questions, insights, privacy and randomizer rules.',
        'Ajustes de relaciones para colores, categorías y etiquetas propias, preferencias del mapa, preguntas de registro, perspectivas, privacidad y reglas del aleatorizador.',
      ),
      LocalizedText(
        'Existing relationships carry over unchanged, and adding a relationship for two alters who already have one adds its labels instead of creating a duplicate.',
        'Las relaciones existentes se conservan sin cambios, y añadir una relación entre dos alters que ya tienen una suma sus etiquetas en lugar de duplicarla.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.27.1',
    date: DateTime(2026, 11, 15),
    improvements: const [
      LocalizedText(
        'Subsystems now match the rest of Prism: your theme’s background and colours, the same rounded cards, buttons and section headings, and quiet orbit lines instead of the space effects.',
        'Los subsistemas ahora combinan con el resto de Prism: el fondo y los colores de tu tema, las mismas tarjetas redondeadas, botones y títulos de sección, y órbitas discretas en lugar de efectos espaciales.',
      ),
      LocalizedText(
        'Profile Studio has Cancel, Reset and Save buttons, and edits the alter’s bio directly instead of showing a second copy.',
        'Profile Studio tiene botones de Cancelar, Restablecer y Guardar, y edita la bio del alter directamente en lugar de mostrar una segunda copia.',
      ),
      LocalizedText(
        'Calmer Habits pages: the large glows behind headers, icons, rings and buttons are gone.',
        'Páginas de hábitos más tranquilas: se quitaron los grandes brillos detrás de cabeceras, iconos, anillos y botones.',
      ),
    ],
    fixes: const [
      LocalizedText(
        'Profile Studio always opens on the saved profile, so saving no longer risks replacing it with an empty one.',
        'Profile Studio siempre se abre con el perfil guardado, así que guardar ya no puede reemplazarlo por uno vacío.',
      ),
      LocalizedText(
        'Saving in Profile Studio keeps the avatar and banner unless you change or remove them there, and keeps changes made elsewhere since the editor opened.',
        'Guardar en Profile Studio conserva el avatar y el banner salvo que los cambies o quites ahí, y respeta los cambios hechos en otro sitio mientras estaba abierto.',
      ),
      LocalizedText(
        'Alter profiles no longer repeat the bio and pronouns in the Profile Studio section.',
        'Los perfiles de los alters ya no repiten la bio y los pronombres en la sección de Profile Studio.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.27.0',
    date: DateTime(2026, 11, 14),
    features: const [
      LocalizedText(
        'A new cosmic Subsystems hub: your subsystems orbit your system on glowing rings in a dark, starry space, with a create button front and centre when you have none and a Learn more guide.',
        'Nuevo centro cósmico de Subsistemas: tus subsistemas orbitan tu sistema en anillos brillantes dentro de un espacio oscuro y estrellado, con un botón de crear bien visible cuando no tienes ninguno y una guía «Más información».',
      ),
      LocalizedText(
        'Create a subsystem step by step: pick a founding alter, give it a name, icon, description and colours, add members with their own subsystem roles and permissions, then choose its settings.',
        'Crea un subsistema paso a paso: elige un alter fundador, dale nombre, icono, descripción y colores, añade miembros con sus propios roles y permisos, y elige sus ajustes.',
      ),
      LocalizedText(
        'Every subsystem is a small system of its own: overview, members, internal relationships, fronting history, journal, notes, internal groups, nested subsystems, rules and boundaries, connections, chat and announcements, and settings for general, members, structure, fronting, communication, privacy, appearance and data.',
        'Cada subsistema es un pequeño sistema propio: resumen, miembros, relaciones internas, historial de frente, diario, notas, grupos internos, subsistemas anidados, normas y límites, conexiones, chat y anuncios, y ajustes de general, miembros, estructura, frente, comunicación, privacidad, apariencia y datos.',
      ),
      LocalizedText(
        'Profile Studio: design an alter’s profile in four sections — basic identity, appearance, personality & identity, and advanced settings — with a live preview, undo and redo, autosaved drafts, templates, presets and import/export.',
        'Profile Studio: diseña el perfil de un alter en cuatro secciones —identidad básica, apariencia, personalidad e identidad, y ajustes avanzados— con vista previa en vivo, deshacer y rehacer, borradores guardados, plantillas, preajustes e importación/exportación.',
      ),
      LocalizedText(
        'Roles typed with spaces become separate pills you can colour, style, hide and drag into order, and appear on the banner as “Host · Protector · …”.',
        'Los roles escritos con espacios se convierten en píldoras que puedes colorear, estilizar, ocultar y reordenar, y aparecen en el banner como «Anfitrión · Protector · …».',
      ),
      LocalizedText(
        'Profiles gain alternative names, pronoun sets, gender, age range, species, origin, subtitle and status, traits with intensity, interests and favourites, memories, music, links, a gallery, custom cards and a pinned note — with modules you can reorder or hide, four layouts, per-field labels and privacy, animated avatars and banners, avatar shapes, fonts, borders and stickers.',
        'Los perfiles suman nombres alternativos, pronombres, género, rango de edad, especie, origen, subtítulo y estado, rasgos con intensidad, intereses y favoritos, recuerdos, música, enlaces, galería, tarjetas personalizadas y nota fijada —con módulos que puedes reordenar u ocultar, cuatro diseños, etiquetas y privacidad por campo, avatares y banners animados, formas de avatar, fuentes, bordes y pegatinas.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Members of an isolated subsystem only appear inside that subsystem — not in Headmates, alter searches or other system-wide member pickers. Adding an alter to a subsystem creates a membership record; the alter is never copied and their main profile stays the same.',
        'Los miembros de un subsistema aislado solo aparecen dentro de él —no en Headmates, búsquedas ni otros selectores del sistema. Añadir un alter crea un registro de membresía: el alter nunca se copia y su perfil principal no cambia.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.26.0',
    date: DateTime(2026, 11, 14),
    features: const [
      LocalizedText(
        'Habit & Routine Center: complete habits as many times a day as you need, with daily targets, counts, minutes or amounts, one-tap logging, partial progress, timers, notes, ratings, photos, places and alter attribution for every completion.',
        'Centro de hábitos y rutinas: completa hábitos tantas veces al día como necesites, con metas diarias, veces, minutos o cantidades, registro con un toque, progreso parcial, temporizador, notas, valoraciones, fotos, lugares y alter en cada registro.',
      ),
      LocalizedText(
        'Every habit has its own dashboard: progress ring, today’s timeline, weekly chart, rhythm heatmap, streaks, who completes it, your patterns, milestones, reflections and connected records.',
        'Cada hábito tiene su panel: anillo de progreso, actividad de hoy, gráfico semanal, mapa de ritmo, rachas, quién lo completa, tus patrones, hitos, reflexiones y registros conectados.',
      ),
      LocalizedText(
        'Routines and templates (morning, evening, school, self-care, music practice, wellness), “up next” suggestions, skip and pause without losing streaks, rest days, monthly habits, multiple reminders with an evening nudge, automatic counting from drinks, meals, workouts, journal, dreams, mood and sleep, challenges and shared system habits. Habits also appear in the calendar.',
        'Rutinas y plantillas, sugerencias de lo siguiente, omitir y pausar sin perder rachas, días de descanso, hábitos mensuales, varios recordatorios, conteo automático desde bebidas, comidas, entrenos, diario, sueños, ánimo y sueño, retos y hábitos compartidos. Los hábitos aparecen también en el calendario.',
      ),
    ],
    improvements: const [
      LocalizedText('Nourish now uses your theme’s colours throughout.', 'Nutrición usa ahora los colores de tu tema en todo.'),
    ],
  ),
  ChangelogRelease(
    version: '0.25.1',
    date: DateTime(2026, 11, 14),
    fixes: const [
      LocalizedText(
        'New pages (Nourish, Scrapbook, Connections, Analytics, Availability, Introductions, Bulletin Board, Stories) now slide in like the rest of the app when opened from Settings or Home.',
        'Las páginas nuevas ahora se deslizan al abrirse desde Ajustes o Inicio, como el resto de la app.',
      ),
      LocalizedText(
        'Alter profiles: the top bar now takes the profile’s colours straight away instead of only after scrolling.',
        'Perfiles de alters: la barra superior toma los colores del perfil al instante, no solo al desplazarse.',
      ),
      LocalizedText(
        'Starting Demo Mode no longer freezes the screen while sample data is prepared.',
        'Iniciar el modo demo ya no congela la pantalla mientras se preparan los datos.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.25.0',
    date: DateTime(2026, 11, 14),
    features: const [
      LocalizedText(
        'Themes rewritten: every theme now has a full colour palette — accent, secondary, highlight, page background, surfaces, raised surfaces, text, secondary text, lines, error, success, caution, chips, switches, progress and links — so colours change across the whole app, not just the accent.',
        'Temas reescritos: cada tema tiene una paleta completa (acento, secundario, resalte, fondo, superficies, texto, líneas, error, éxito, precaución, fichas, interruptores, progreso y enlaces), así que los colores cambian en toda la app, no solo el acento.',
      ),
      LocalizedText(
        'Reset appearance: put Prism back to how it looked on install, keeping or deleting your saved themes and pictures.',
        'Restablecer apariencia: devuelve Prism a su aspecto original, conservando o borrando tus temas e imágenes.',
      ),
    ],
    fixes: const [
      LocalizedText(
        'Pages with their own theme no longer break: they are built from a clean base that fits their colours, with text kept readable.',
        'Las páginas con su propio tema ya no se rompen: se construyen desde una base limpia acorde a sus colores y con texto legible.',
      ),
      LocalizedText(
        'Switching between light and dark now changes everything at once (no slow backgrounds or cards).',
        'Cambiar entre claro y oscuro ahora cambia todo a la vez (sin fondos ni tarjetas lentos).',
      ),
      LocalizedText(
        'Alter profiles now follow the active theme fully; the alter’s colour only replaces the accent.',
        'Los perfiles de alters siguen el tema activo por completo; el color del alter solo reemplaza el acento.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.24.0',
    date: DateTime(2026, 11, 13),
    features: const [
      LocalizedText(
        'System Scrapbook: shared memory books with freeform pages — photos, GIFs, videos, voice clips, drawings, notes, stickers, tape and shapes, with themes, layouts, captions, timeline and gallery views, and contributor permissions.',
        'Álbum del sistema: álbumes compartidos con páginas libres — fotos, GIF, vídeos, audios, dibujos, notas, pegatinas, cinta y formas, con temas, diseños, pies de foto, cronología, galería y permisos.',
      ),
      LocalizedText(
        'Connected records: link alters, fronting, moods, journal entries, dreams, meals, events, places, sleep and more; see links on each page and in a visual explorer with custom categories.',
        'Registros conectados: enlaza alters, frente, ánimos, diario, sueños, comidas, eventos, lugares, sueño y más; mira los enlaces en cada página y en un explorador visual.',
      ),
      LocalizedText(
        'Co-fronting analytics and mood correlations: rankings, combinations, calendar, timeline, and mood compared with fronting, sleep, food, activity, places and more — with confidence levels, on-device insights and downloadable reports.',
        'Análisis de co-frente y correlaciones de ánimo: clasificaciones, combinaciones, calendario, cronología y el ánimo comparado con frente, sueño, comida, actividad, lugares y más, con niveles de confianza, observaciones e informes.',
      ),
      LocalizedText(
        'Internal Connections maps, Nourish (nutrition & hydration), alter statuses, availability schedules, tarot-style introduction cards, a Dream Journal tab, custom automations and Demo Mode.',
        'Mapas de conexiones internas, Nutrición e hidratación, estados de alters, disponibilidad, tarjetas de presentación estilo tarot, pestaña de sueños, automatizaciones y modo demo.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.23.1',
    date: DateTime(2026, 11, 13),
    improvements: const [
      LocalizedText(
        'Freeze recorder: if Prism stops responding, a short technical '
            'report (pages and app components, never your data) is saved. '
            'Copy it from Settings → About and send it to the developer.',
        'Registro de bloqueos: si Prism deja de responder, se guarda un '
            'breve informe técnico (páginas y componentes, nunca tus datos). '
            'Cópialo en Ajustes → Acerca de y envíalo al desarrollador.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.23.0',
    date: DateTime(2026, 11, 13),
    features: const [
      LocalizedText(
        'Bulletin Board feed: alters post text, pictures, polls, questions '
            'and videos; react with any emoji, comment in threads, reblog '
            'and quote with credit, follow each other, pin posts, use '
            '#tags and search, save drafts and schedule posts, choose who '
            'sees each post, and block, mute, hide or report. Activity shows '
            'reactions, replies, mentions and new followers. Every post '
            "belongs to the alter who wrote it, whoever is fronting. Each "
            'alter gets a blog with a banner, colours and layout.',
        'Tablón: los alters publican texto, fotos, encuestas, preguntas y '
            'vídeos; reaccionan con cualquier emoji, comentan en hilos, '
            'rebloguean y citan con crédito, se siguen, fijan publicaciones, '
            'usan #etiquetas y búsqueda, guardan borradores y programan, '
            'eligen quién ve cada publicación y bloquean, silencian, ocultan '
            'o denuncian. Cada alter tiene su blog con banner y colores.',
      ),
      LocalizedText(
        'Alter Stories: photo, video and text stories with stickers, GIFs, '
            'fonts, colours and music from your library, several slides at '
            'a time, views, reactions and replies, highlights with '
            'categories, and an archive. Stories last 24 hours and anyone '
            'can watch them without switching front. New Stories section on '
            'Home (Customize to hide it).',
        'Historias de alters: historias de foto, vídeo y texto con '
            'pegatinas, GIF, fuentes, colores y música de tu biblioteca, '
            'varias diapositivas, vistas, reacciones y respuestas, '
            'destacadas con categorías y archivo. Duran 24 horas y '
            'cualquiera puede verlas sin cambiar el frente. Nueva sección '
            'de Historias en Inicio.',
      ),
      LocalizedText(
        'Headmates: optional profile banners on each card, with cropping '
            'and positioning (Headmates display settings → Show alter '
            'banners).',
        'Headmates: banners de perfil opcionales en cada tarjeta, con '
            'recorte y posición.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Much smoother with a theme or background: backgrounds are now '
            'prepared once instead of being blurred again on every frame, '
            'which could freeze pages like Headmates.',
        'Mucho más fluido con un tema o fondo: los fondos se preparan una '
            'vez en lugar de desenfocarse en cada fotograma, lo que podía '
            'congelar páginas como Headmates.',
      ),
      LocalizedText(
        'Lighter page transitions and a cheaper blurred-artwork effect in '
            'the music player.',
        'Transiciones más ligeras y un efecto de portada desenfocada más '
            'eficiente en el reproductor.',
      ),
      LocalizedText(
        'App updates: downloads resume after a dropped connection instead '
            'of starting over, the newest build is always found, and the '
            'update card checks again when you open it and shows your '
            'installed version.',
        'Actualizaciones: las descargas se reanudan si se corta la '
            'conexión, siempre se encuentra la compilación más nueva y la '
            'tarjeta vuelve a comprobar al abrirla y muestra tu versión.',
      ),
      LocalizedText(
        'The Bulletin Board and Stories are now easy to find: in Settings, '
            'in the navigation "More" menu and on Home.',
        'El Tablón y las Historias ahora son fáciles de encontrar: en '
            'Ajustes, en el menú "Más" y en Inicio.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.22.0',
    date: DateTime(2026, 11, 13),
    features: const [
      LocalizedText(
        'Music player: import your own songs (MP3, M4A, AAC, WAV, OGG and '
            'more), build playlists, favourites and a queue, edit song info '
            'and covers. Music keeps playing while you move around Prism, '
            'with a compact bar or floating player on every page, a full '
            'player with artwork, and lock-screen / notification controls '
            'on Android.',
        'Reproductor de música: importa tus canciones (MP3, M4A, AAC, WAV, '
            'OGG y más), crea listas, favoritas y una cola, y edita datos y '
            'portadas. La música sigue sonando mientras navegas por Prism, '
            'con barra compacta o reproductor flotante en cada página, '
            'reproductor completo con portada y controles en la pantalla '
            'de bloqueo en Android.',
      ),
      LocalizedText(
        'Themes & backgrounds: eight designed presets plus your own. Upload '
            'backgrounds or pick from a collection, use solid colours or '
            'multi-colour gradients, adjust blur, brightness, contrast and '
            'saturation, and add overlays. Style buttons, cards, the '
            'navigation bar, headers, text fields, dialogs, dividers, icons '
            'and badges. Different backgrounds or themes per page, automatic '
            'light/dark switching, live preview, and import/export to share '
            'themes. Settings → Themes & backgrounds.',
        'Temas y fondos: ocho temas diseñados y los tuyos. Sube fondos o '
            'elige de una colección, usa colores sólidos o degradados, ajusta '
            'desenfoque, brillo, contraste y saturación, y añade capas. '
            'Estiliza botones, tarjetas, la barra de navegación, '
            'encabezados, campos, diálogos, separadores, iconos e insignias. '
            'Fondos o temas por página, cambio automático claro/oscuro, '
            'vista previa e importar/exportar temas.',
      ),
      LocalizedText(
        'Accessibility: interface size, line height and word spacing, bold '
            'text, high and adjustable contrast, reduced transparency and '
            'effects, colour-blind palettes, a strong keyboard-focus '
            'outline, larger icons and touch targets, reduce motion and '
            'animation speed, vibration and confirmation options, and a '
            'quick accessibility panel (Alt+Shift+A).',
        'Accesibilidad: tamaño de la interfaz, interlineado y espacio entre '
            'palabras, negrita, contraste alto y ajustable, menos '
            'transparencia y efectos, paletas para daltonismo, contorno de '
            'foco marcado, iconos y zonas táctiles más grandes, reducir '
            'movimiento y velocidad de animación, vibración, confirmaciones '
            'y panel de accesibilidad rápida (Alt+Mayús+A).',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Appearance and accessibility settings sync across your devices '
            '(uploaded pictures stay on the device they were added on).',
        'Los ajustes de apariencia y accesibilidad se sincronizan entre '
            'dispositivos (las imágenes subidas se quedan en su dispositivo).',
      ),
      LocalizedText(
        'Home screen widgets no longer gather data until one is placed.',
        'Los widgets de inicio ya no recopilan datos hasta que colocas uno.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.21.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Home screen widgets (Android, tuned for Samsung One UI): 20 '
            'widgets across fronting, wellness, productivity and system '
            'tools, each in small, medium and large sizes that switch as '
            'you resize. Settings → Home screen widgets.',
        'Widgets de inicio (Android, pensados para Samsung One UI): 20 '
            'widgets de frente, bienestar, productividad y sistema, cada '
            'uno en tamaño pequeño, mediano y grande. Ajustes → Widgets '
            'de inicio.',
      ),
      LocalizedText(
        'Widget Customization Studio with live preview: themes (light, '
            'dark, AMOLED), colours and gradients, glass transparency, '
            'corners, borders, fonts, text size, avatar shapes, background '
            'images with blur, compact or detailed layouts, and saved '
            'configurations. Add the same widget several times, each with '
            'its own look.',
        'Estudio de personalización con vista previa en vivo: temas '
            '(claro, oscuro, AMOLED), colores y degradados, transparencia, '
            'esquinas, bordes, fuentes, tamaño de texto, forma de avatar, '
            'imágenes de fondo con desenfoque, diseño compacto o detallado '
            'y configuraciones guardadas.',
      ),
      LocalizedText(
        'Quick actions from the home screen: switch fronters, log a mood, '
            'check in to a place, start or end sleep and tick off tasks '
            'without opening Prism.',
        'Acciones rápidas desde la pantalla de inicio: cambiar el frente, '
            'registrar ánimo, registrarte en un lugar, dormir o despertar y '
            'marcar tareas sin abrir Prism.',
      ),
      LocalizedText(
        'New To-do list with per-member tasks and due dates.',
        'Nueva lista de tareas con tareas por miembro y fechas límite.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Widgets are private by default: journal and note text, finances, '
            'symptoms and private entries stay hidden until you turn them '
            'on for a specific widget. You can also show initials instead '
            'of names and mask amounts.',
        'Los widgets son privados por defecto: el texto del diario y las '
            'notas, las finanzas, los síntomas y las entradas privadas '
            'permanecen ocultos hasta que los actives en un widget concreto.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.20.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Fronting notification (Android): a live notification showing who '
            'is fronting, co-fronters, a running timer, mood, location, '
            'activity and your own status, updated the moment the front '
            'changes. Customise the title, greeting, icon, colours, layout, '
            'buttons (switch, quick front, mood, status, details), lock '
            'screen privacy and per-member styles. Settings → Fronting '
            'notification.',
        'Notificación de frente (Android): una notificación continua con '
            'quién está al frente, co-frente, cronómetro, ánimo, ubicación, '
            'actividad y tu estado, que se actualiza al cambiar el frente. '
            'Personaliza título, saludo, icono, colores, diseño, botones, '
            'privacidad en la pantalla de bloqueo y estilos por miembro. '
            'Ajustes → Notificación de frente.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.19.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Relationships: between headmates and with people outside the '
            'system, with types, status, closeness, trust, dynamics, '
            'boundaries, event history, statistics and a relationship map.',
        'Relaciones: entre miembros y con personas de fuera, con tipo, '
            'estado, cercanía, confianza, dinámica, límites, historial, '
            'estadísticas y un mapa de relaciones.',
      ),
      LocalizedText(
        'Subsystems: nested subsystems with members and roles, purpose, '
            'origin, rules, connections, internal relationships and share '
            'of fronting; members can be brought in from a group.',
        'Subsistemas: subsistemas anidados con miembros y roles, propósito, '
            'origen, normas, conexiones, relaciones internas y parte del '
            'frente; se pueden traer miembros de un grupo.',
      ),
      LocalizedText(
        'Headspace Mapper: draw your inner world with draggable areas, '
            'connections, descriptions, residents and a list view.',
        'Mapa del espacio interior: dibuja tu mundo interior con zonas que '
            'se arrastran, conexiones, descripciones, residentes y vista de '
            'lista.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.18.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Sleep analysis: log room temperature, lighting, noise, comfort, '
            'interruptions, habits, dreams and who woke up; set a sleep '
            'schedule; see sleep debt, regularity and what goes with better '
            'sleep.',
        'Análisis del sueño: registra temperatura, luz, ruido, comodidad, '
            'interrupciones, hábitos, sueños y quién despertó; define un '
            'horario; ve la deuda de sueño, la regularidad y qué acompaña a '
            'un mejor descanso.',
      ),
      LocalizedText(
        'Cycle insights: customizable phases, your own symptoms, body signs '
            '(energy, pain, basal temperature, tests), cycle history, '
            'fertile-window estimates and personal patterns.',
        'Análisis del ciclo: fases personalizables, síntomas propios, señales '
            'del cuerpo (energía, dolor, temperatura basal, tests), historial, '
            'ventana fértil estimada y patrones personales.',
      ),
      LocalizedText(
        'Polls: yes/no, numeric scale, ranked-choice and rating polls, '
            'categories, results analytics with turnout, and poll history '
            'with participation per member.',
        'Encuestas: sí/no, escala numérica, por orden y valoración, '
            'categorías, análisis de resultados con participación e historial '
            'con participación por miembro.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Journal entries, workouts, transactions, classes and study sessions '
            'are attributed to the current fronter and can be filtered by '
            'member.',
        'Entradas, ejercicios, movimientos, clases y sesiones de estudio se '
            'atribuyen a quien está al frente y se pueden filtrar por miembro.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.17.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Finance: income, expenses, transfers, accounts and balances, '
            'monthly budgets, savings goals, recurring payments, statistics '
            'and a privacy toggle to hide amounts.',
        'Finanzas: ingresos, gastos, transferencias, cuentas y saldos, '
            'presupuestos mensuales, metas de ahorro, pagos recurrentes, '
            'estadísticas y un botón para ocultar importes.',
      ),
      LocalizedText(
        'Fitness: workouts with a live timer, distance, calories, effort, '
            'sets and reps, exercise history, personal bests and goals.',
        'Ejercicio: sesiones con cronómetro, distancia, calorías, esfuerzo, '
            'series y repeticiones, historial, mejores marcas y metas.',
      ),
      LocalizedText(
        'School: classes with weekly schedules, assignments and deadlines, '
            'grades and GPA, study timer and progress.',
        'Escuela: clases con horario, tareas y entregas, notas y promedio, '
            'cronómetro de estudio y progreso.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'Finance can record estimated Work earnings as income.',
        'Finanzas puede registrar las ganancias estimadas de Trabajo como '
            'ingreso.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.16.0',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'Journal: entries with categories, tags, mood, writing prompts, '
            'search, pinning, private entries and version history.',
        'Diario: entradas con categorías, etiquetas, ánimo, ideas para '
            'escribir, búsqueda, fijado, entradas privadas e historial de '
            'versiones.',
      ),
      LocalizedText(
        'Dictionary: your own terms and collections, plus import from '
            'wikis (any MediaWiki or Fandom page or category), files or '
            'pasted text.',
        'Diccionario: tus propios términos y colecciones, e importación '
            'desde wikis (cualquier página o categoría de MediaWiki o '
            'Fandom), archivos o texto pegado.',
      ),
      LocalizedText(
        'Achievements: milestones across fronting, wellbeing, journaling, '
            'habits and more, with tiers, progress and unlock history.',
        'Logros: metas de frente, bienestar, diario, hábitos y más, con '
            'niveles, progreso e historial.',
      ),
      LocalizedText(
        "What's New: this page, shown once after each update.",
        'Novedades: esta página, que aparece una vez tras cada '
            'actualización.',
      ),
    ],
    improvements: const [
      LocalizedText(
        'The Home journal quick action now opens the new Journal.',
        'La acción rápida de diario en Inicio ahora abre el nuevo Diario.',
      ),
      LocalizedText(
        'New data is included in backups, sync and Reset data.',
        'Los nuevos datos se incluyen en copias de seguridad, '
            'sincronización y Restablecer datos.',
      ),
    ],
  ),
  ChangelogRelease(
    version: '0.15.3',
    date: DateTime(2026, 11, 12),
    features: const [
      LocalizedText(
        'In-app updates: new versions install over the current app and '
            'keep your data.',
        'Actualizaciones en la app: las nuevas versiones se instalan sobre '
            'la actual y conservan tus datos.',
      ),
      LocalizedText(
        'Customisable Home dashboard, System Timeline, Pattern Explorer '
            'and How We Feel.',
        'Panel de Inicio personalizable, Línea de tiempo del sistema, '
            'Explorador de patrones y Cómo nos sentimos.',
      ),
      LocalizedText(
        'Cycle tracking, contacts with birthdays and the Import Center.',
        'Seguimiento del ciclo, contactos con cumpleaños y el Centro de '
            'importación.',
      ),
      LocalizedText(
        'Daily Insights, emotion library, locations and work tracking.',
        'Resumen diario, biblioteca de emociones, lugares y trabajo.',
      ),
    ],
    fixes: const [
      LocalizedText(
        'Reminders can repeat several times a day.',
        'Los recordatorios pueden repetirse varias veces al día.',
      ),
    ],
  ),
];

/// The release for [version], if it has notes.
ChangelogRelease? releaseFor(String version) {
  for (final r in prismChangelog) {
    if (r.version == version) return r;
  }
  return null;
}
