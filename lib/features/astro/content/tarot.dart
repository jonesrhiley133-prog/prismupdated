import 'dart:math' as math;

import 'package:prism_plurality/features/astro/content/zodiac.dart';

/// The 78-card tarot, for reflection. Meanings follow common modern
/// (Rider–Waite–Smith tradition) readings.
enum Suit {
  wands(Bi('Wands', 'Bastos'), '🔥', AstroElement.fire, Bi('drive, creativity and passion', 'el impulso, la creatividad y la pasión')),
  cups(Bi('Cups', 'Copas'), '💧', AstroElement.water, Bi('feelings, relationships and intuition', 'los sentimientos, las relaciones y la intuición')),
  swords(Bi('Swords', 'Espadas'), '🗡️', AstroElement.air, Bi('thoughts, truth and communication', 'los pensamientos, la verdad y la comunicación')),
  pentacles(Bi('Pentacles', 'Oros'), '🪙', AstroElement.earth, Bi('the body, work, money and home', 'el cuerpo, el trabajo, el dinero y el hogar'));

  const Suit(this.title, this.emoji, this.element, this.domain);
  final Bi title;
  final String emoji;
  final AstroElement element;
  final Bi domain;
}

class TarotCard {
  const TarotCard({
    required this.id,
    required this.name,
    required this.upright,
    required this.reversed,
    this.suit,
    this.number,
    this.meaning,
    this.reversedMeaning,
    this.love,
    this.growth,
  });

  /// Stable id: "major-0" … "major-21", "wands-1" … "pentacles-14".
  final String id;
  final Bi name;
  final Bi upright;
  final Bi reversed;
  final Suit? suit;

  /// Majors: 0–21. Minors: 1 (Ace) – 14 (King).
  final int? number;
  final Bi? meaning;
  final Bi? reversedMeaning;
  final Bi? love;
  final Bi? growth;

  bool get major => suit == null;

  String symbol() => major ? _roman(number!) : suit!.emoji;

  String meaningOf(bool rev, bool es) {
    if (rev) {
      return reversedMeaning?.of(es) ??
          (es
              ? 'Invertida, la energía de ${suit!.domain.es} puede estar bloqueada o vuelta hacia dentro: ${reversed.es}.'
              : 'Reversed, the energy of ${suit!.domain.en} may be blocked or turned inward: ${reversed.en}.');
    }
    return meaning?.of(es) ??
        (es
            ? 'En el ámbito de ${suit!.domain.es}, esta carta habla de ${upright.es}.'
            : 'In the realm of ${suit!.domain.en}, this card speaks of ${upright.en}.');
  }

  String loveOf(bool rev, bool es) =>
      love?.of(es) ??
      switch (suit!) {
        Suit.cups => es ? 'En los vínculos, el corazón está en primer plano: ${upright.es}.' : 'In connections, the heart takes centre stage: ${upright.en}.',
        Suit.wands => es ? 'En los vínculos: chispa, entusiasmo y ${upright.es}.' : 'In connections: spark, enthusiasm and ${upright.en}.',
        Suit.swords => es ? 'En los vínculos, la comunicación es clave: ${upright.es}.' : 'In connections, communication is key: ${upright.en}.',
        Suit.pentacles => es ? 'En los vínculos, los gestos prácticos cuentan: ${upright.es}.' : 'In connections, practical gestures count: ${upright.en}.',
      };

  String growthOf(bool rev, bool es) =>
      growth?.of(es) ??
      (rev
          ? (es ? 'Para crecer: fíjate en dónde aparece ${reversed.es} y qué necesita.' : 'For growth: notice where ${reversed.en} shows up and what it needs.')
          : (es ? 'Para crecer: apóyate en ${upright.es}.' : 'For growth: lean into ${upright.en}.'));
}

String _roman(int n) {
  if (n == 0) return '0';
  const vals = [10, 9, 5, 4, 1];
  const syms = ['X', 'IX', 'V', 'IV', 'I'];
  var x = n;
  final b = StringBuffer();
  for (var i = 0; i < vals.length; i++) {
    while (x >= vals[i]) {
      b.write(syms[i]);
      x -= vals[i];
    }
  }
  return b.toString();
}

TarotCard _major(int n, String en, String es, String up, String upEs, String rev, String revEs, String mean, String meanEs, String rmean, String rmeanEs, String love, String loveEs, String growth, String growthEs) =>
    TarotCard(
      id: 'major-$n',
      number: n,
      name: Bi(en, es),
      upright: Bi(up, upEs),
      reversed: Bi(rev, revEs),
      meaning: Bi(mean, meanEs),
      reversedMeaning: Bi(rmean, rmeanEs),
      love: Bi(love, loveEs),
      growth: Bi(growth, growthEs),
    );

final List<TarotCard> majorArcana = [
  _major(0, 'The Fool', 'El Loco', 'new beginnings, trust, spontaneity', 'comienzos, confianza, espontaneidad', 'hesitation, recklessness', 'vacilación, imprudencia',
      'A leap into the unknown with an open heart. Traditionally the start of a journey.', 'Un salto a lo desconocido con el corazón abierto. Tradicionalmente, el inicio de un viaje.',
      'Holding back from a leap, or leaping without looking.', 'Contenerse ante un salto, o saltar sin mirar.',
      'Fresh, playful energy in connection; let things be new.', 'Energía fresca y juguetona en los vínculos; deja que las cosas sean nuevas.',
      'Try something you\'ve never done before.', 'Prueba algo que nunca hayas hecho.'),
  _major(1, 'The Magician', 'El Mago', 'skill, focus, making things happen', 'habilidad, concentración, hacer que las cosas pasen', 'scattered energy, untapped potential', 'energía dispersa, potencial sin usar',
      'You have the tools you need; focus turns ideas into reality.', 'Tienes las herramientas que necesitas; la concentración convierte ideas en realidad.',
      'Talents unused or energy pulled in too many directions.', 'Talentos sin usar o energía repartida en demasiadas direcciones.',
      'Say what you want clearly; intention shapes connection.', 'Di con claridad lo que quieres; la intención da forma al vínculo.',
      'Pick one project and give it your full attention.', 'Elige un proyecto y dale toda tu atención.'),
  _major(2, 'The High Priestess', 'La Sacerdotisa', 'intuition, inner knowing, mystery', 'intuición, saber interior, misterio', 'ignored intuition, secrets', 'intuición ignorada, secretos',
      'Quiet wisdom; listen to what you already know inside.', 'Sabiduría silenciosa; escucha lo que ya sabes por dentro.',
      'Tuning out your inner voice, or something kept hidden.', 'Desoír tu voz interior, o algo que se mantiene oculto.',
      'Read between the lines; not everything needs saying yet.', 'Lee entre líneas; no todo hace falta decirlo todavía.',
      'Make space for stillness and notice what arises.', 'Haz espacio para la quietud y observa lo que surge.'),
  _major(3, 'The Empress', 'La Emperatriz', 'nurture, abundance, creativity', 'cuidado, abundancia, creatividad', 'neglecting yourself, creative block', 'descuidarse, bloqueo creativo',
      'Growth through care, comfort and creativity.', 'Crecimiento a través del cuidado, la comodidad y la creatividad.',
      'Giving to everyone but yourself; creativity on hold.', 'Darlo todo a los demás menos a ti; creatividad en pausa.',
      'Warmth, affection and caring for each other.', 'Calidez, cariño y cuidarse mutuamente.',
      'Nurture yourself the way you nurture others.', 'Cuídate como cuidas a los demás.'),
  _major(4, 'The Emperor', 'El Emperador', 'structure, stability, leadership', 'estructura, estabilidad, liderazgo', 'rigidity, control', 'rigidez, control',
      'Order and steady leadership create safety.', 'El orden y un liderazgo firme crean seguridad.',
      'Holding on too tightly, or a lack of healthy structure.', 'Aferrarse demasiado, o falta de una estructura sana.',
      'Reliability and clear boundaries build trust.', 'La fiabilidad y los límites claros construyen confianza.',
      'Create one routine that supports you.', 'Crea una rutina que te sostenga.'),
  _major(5, 'The Hierophant', 'El Hierofante', 'tradition, learning, shared values', 'tradición, aprendizaje, valores compartidos', 'questioning rules, finding your own way', 'cuestionar normas, encontrar tu camino',
      'Wisdom passed down; learning from a mentor or tradition.', 'Sabiduría transmitida; aprender de un mentor o una tradición.',
      'Outgrowing a rule or belief that no longer fits.', 'Dejar atrás una norma o creencia que ya no encaja.',
      'Shared values and commitment matter now.', 'Ahora importan los valores compartidos y el compromiso.',
      'Ask what you believe, and why.', 'Pregúntate qué crees y por qué.'),
  _major(6, 'The Lovers', 'Los Enamorados', 'connection, choice, harmony', 'conexión, elección, armonía', 'imbalance, misalignment', 'desequilibrio, desajuste',
      'Deep connection and choices that reflect your values.', 'Conexión profunda y elecciones que reflejan tus valores.',
      'Values out of sync, or a choice being avoided.', 'Valores desajustados, o una elección que se evita.',
      'Mutual respect and honest choosing of each other.', 'Respeto mutuo y elegirse con sinceridad.',
      'Make a choice that\'s true to who you are.', 'Toma una decisión fiel a quien eres.'),
  _major(7, 'The Chariot', 'El Carro', 'determination, momentum, willpower', 'determinación, impulso, fuerza de voluntad', 'lack of direction, scattered effort', 'falta de dirección, esfuerzo disperso',
      'Moving forward with focus and resolve.', 'Avanzar con concentración y determinación.',
      'Pulled in two directions; regain the reins.', 'Tirado en dos direcciones; recupera las riendas.',
      'Work together toward a shared goal.', 'Trabajad juntos hacia una meta común.',
      'Decide where you\'re heading and take the first step.', 'Decide hacia dónde vas y da el primer paso.'),
  _major(8, 'Strength', 'La Fuerza', 'gentle courage, patience, compassion', 'valentía suave, paciencia, compasión', 'self-doubt, frayed patience', 'inseguridad, paciencia agotada',
      'Quiet strength that comes from kindness, not force.', 'Una fuerza tranquila que nace de la bondad, no de la fuerza bruta.',
      'Doubting yourself or running low on patience.', 'Dudar de ti o quedarte sin paciencia.',
      'Patience and compassion soften difficult moments.', 'La paciencia y la compasión suavizan los momentos difíciles.',
      'Be gentle with the part of you that\'s struggling.', 'Sé amable con la parte de ti que lo está pasando mal.'),
  _major(9, 'The Hermit', 'El Ermitaño', 'solitude, reflection, inner guidance', 'soledad, reflexión, guía interior', 'isolation, avoiding reflection', 'aislamiento, evitar la reflexión',
      'Stepping back to find your own light.', 'Dar un paso atrás para encontrar tu propia luz.',
      'Withdrawing too far, or avoiding time alone with your thoughts.', 'Aislarse demasiado, o evitar estar a solas con tus pensamientos.',
      'Space can be healthy; say what you need.', 'El espacio puede ser sano; di lo que necesitas.',
      'Spend some intentional time alone.', 'Pasa un rato a solas a propósito.'),
  _major(10, 'Wheel of Fortune', 'La Rueda de la Fortuna', 'cycles, change, turning points', 'ciclos, cambio, puntos de inflexión', 'resisting change, feeling stuck', 'resistirse al cambio, estancamiento',
      'Life moves in cycles; a new turn is coming.', 'La vida se mueve en ciclos; se acerca un nuevo giro.',
      'Fighting the current, or feeling caught in a loop.', 'Luchar contra la corriente, o sentirse en un bucle.',
      'Relationships change and grow; flow with it.', 'Las relaciones cambian y crecen; fluye con ello.',
      'Notice the pattern you\'re in — and where it\'s turning.', 'Observa el patrón en el que estás y hacia dónde gira.'),
  _major(11, 'Justice', 'La Justicia', 'fairness, truth, accountability', 'justicia, verdad, responsabilidad', 'imbalance, avoiding accountability', 'desequilibrio, evitar responsabilidades',
      'Clear truth and fair choices bring balance.', 'La verdad clara y las decisiones justas traen equilibrio.',
      'Something feels unfair, or a truth is being avoided.', 'Algo parece injusto, o se evita una verdad.',
      'Fairness and honesty keep things balanced.', 'La justicia y la sinceridad mantienen el equilibrio.',
      'Look honestly at your part in a situation.', 'Mira con sinceridad tu parte en una situación.'),
  _major(12, 'The Hanged One', 'El Colgado', 'pause, new perspective, surrender', 'pausa, nueva perspectiva, rendición', 'stalling, resisting the pause', 'estancarse, resistirse a la pausa',
      'A pause that lets you see things differently.', 'Una pausa que te deja ver las cosas de otro modo.',
      'Waiting without purpose, or fighting a needed pause.', 'Esperar sin propósito, o luchar contra una pausa necesaria.',
      'Try seeing things from the other person\'s side.', 'Intenta ver las cosas desde el lado de la otra persona.',
      'Let go of forcing an outcome for now.', 'Deja de forzar un resultado por ahora.'),
  _major(13, 'Death', 'La Muerte', 'endings, transformation, transition', 'finales, transformación, transición', 'clinging, fear of change', 'aferrarse, miedo al cambio',
      'Not literal death: one chapter closes so another can open.', 'No es una muerte literal: un capítulo se cierra para que otro se abra.',
      'Holding on to something that has already ended.', 'Aferrarse a algo que ya ha terminado.',
      'A relationship may be changing shape, not ending.', 'Una relación puede estar cambiando de forma, no terminando.',
      'Name what you\'re ready to leave behind.', 'Nombra lo que estás listo para dejar atrás.'),
  _major(14, 'Temperance', 'La Templanza', 'balance, patience, moderation', 'equilibrio, paciencia, moderación', 'excess, imbalance', 'exceso, desequilibrio',
      'Blending opposites patiently into something whole.', 'Combinar opuestos con paciencia hasta formar un todo.',
      'Too much of something, or rushing the process.', 'Demasiado de algo, o apresurar el proceso.',
      'Meeting in the middle and moving gently.', 'Encontrarse a medio camino y avanzar con suavidad.',
      'Find a little more balance in one area.', 'Encuentra un poco más de equilibrio en un área.'),
  _major(15, 'The Devil', 'El Diablo', 'attachments, habits, shadow', 'apegos, hábitos, sombra', 'breaking free, awareness', 'liberarse, toma de conciencia',
      'Noticing what has a hold on you — habits, fears or patterns.', 'Darte cuenta de lo que te tiene atrapado: hábitos, miedos o patrones.',
      'Loosening a hold and stepping toward freedom.', 'Aflojar un apego y dar un paso hacia la libertad.',
      'Watch for patterns that feel more like habit than choice.', 'Atento a patrones que parecen más hábito que elección.',
      'Gently look at one habit that doesn\'t serve you.', 'Mira con cariño un hábito que no te ayuda.'),
  _major(16, 'The Tower', 'La Torre', 'sudden change, revelation, breakthrough', 'cambio repentino, revelación, avance', 'avoiding upheaval, delayed change', 'evitar el cambio, cambio aplazado',
      'Something shaky comes down so something truer can be built.', 'Algo inestable cae para que se pueda construir algo más auténtico.',
      'Resisting a change that is already underway.', 'Resistirse a un cambio que ya está en marcha.',
      'Honest shake-ups can clear the air.', 'Una sacudida sincera puede despejar el ambiente.',
      'What would you rebuild differently?', '¿Qué reconstruirías de otra manera?'),
  _major(17, 'The Star', 'La Estrella', 'hope, healing, renewal', 'esperanza, sanación, renovación', 'discouragement, lost faith', 'desánimo, fe perdida',
      'Calm hope after a storm; healing and inspiration.', 'Esperanza tranquila tras la tormenta; sanación e inspiración.',
      'Feeling disconnected from hope — it\'s still there.', 'Sentirte lejos de la esperanza: sigue ahí.',
      'Openness and gentle hope between people.', 'Apertura y esperanza suave entre personas.',
      'Do one small thing that restores you.', 'Haz una pequeña cosa que te restaure.'),
  _major(18, 'The Moon', 'La Luna', 'intuition, dreams, the unknown', 'intuición, sueños, lo desconocido', 'confusion clearing, facing fears', 'confusión que se aclara, enfrentar miedos',
      'Not everything is clear; trust your intuition through the fog.', 'No todo está claro; confía en tu intuición entre la niebla.',
      'Confusion lifting, or fears losing their power.', 'La confusión se disipa, o los miedos pierden fuerza.',
      'Ask instead of assuming.', 'Pregunta en lugar de suponer.',
      'Write down a dream or a feeling you can\'t quite name.', 'Apunta un sueño o un sentimiento que no sabes nombrar.'),
  _major(19, 'The Sun', 'El Sol', 'joy, warmth, vitality', 'alegría, calidez, vitalidad', 'clouded joy, low energy', 'alegría nublada, poca energía',
      'Warmth, success and simple joy.', 'Calidez, éxito y alegría sencilla.',
      'Joy is there but temporarily clouded.', 'La alegría está ahí, aunque nublada por un momento.',
      'Playfulness and openness light things up.', 'El juego y la apertura lo iluminan todo.',
      'Do something that makes you feel like yourself.', 'Haz algo que te haga sentir tú mismo.'),
  _major(20, 'Judgement', 'El Juicio', 'awakening, reflection, renewal', 'despertar, reflexión, renovación', 'self-judgement, hesitation', 'autojuicio, vacilación',
      'A call to rise, reflect and begin a new chapter.', 'Una llamada a levantarse, reflexionar y empezar un nuevo capítulo.',
      'Being too hard on yourself, or ignoring the call.', 'Ser demasiado duro contigo, o ignorar la llamada.',
      'Forgiveness opens new beginnings.', 'El perdón abre nuevos comienzos.',
      'Look back with kindness at how far you\'ve come.', 'Mira atrás con cariño todo lo que has avanzado.'),
  _major(21, 'The World', 'El Mundo', 'completion, wholeness, integration', 'culminación, plenitud, integración', 'loose ends, almost there', 'cabos sueltos, casi a punto',
      'A cycle completes; things come together as a whole.', 'Un ciclo se completa; las cosas se unen en un todo.',
      'Nearly finished — tie up the loose ends.', 'Casi terminado: ata los cabos sueltos.',
      'Feeling whole together, and whole apart.', 'Sentirse completos juntos y por separado.',
      'Celebrate something you\'ve finished.', 'Celebra algo que hayas terminado.'),
];

/// Upright and reversed keywords for each minor card, Ace to King.
const _minorKeys = <Suit, List<(Bi, Bi)>>{
  Suit.wands: [
    (Bi('inspiration and a spark of something new', 'inspiración y la chispa de algo nuevo'), Bi('delays and a spark that won\'t catch', 'retrasos y una chispa que no prende')),
    (Bi('planning and looking ahead', 'planificar y mirar adelante'), Bi('fear of the unknown', 'miedo a lo desconocido')),
    (Bi('expansion and progress', 'expansión y progreso'), Bi('obstacles and frustration', 'obstáculos y frustración')),
    (Bi('celebration and homecoming', 'celebración y regreso a casa'), Bi('transitions and unsettled plans', 'transiciones y planes inestables')),
    (Bi('friendly competition and clashing ideas', 'competencia amistosa e ideas que chocan'), Bi('avoiding conflict', 'evitar el conflicto')),
    (Bi('recognition and victory', 'reconocimiento y victoria'), Bi('self-doubt about success', 'dudas sobre el éxito')),
    (Bi('standing your ground', 'defender tu postura'), Bi('feeling overwhelmed', 'sentirse desbordado')),
    (Bi('speed and swift progress', 'rapidez y avances veloces'), Bi('waiting and slowing down', 'esperar y bajar el ritmo')),
    (Bi('resilience and persistence', 'resiliencia y perseverancia'), Bi('exhaustion and defensiveness', 'agotamiento y estar a la defensiva')),
    (Bi('carrying a heavy load', 'cargar con mucho peso'), Bi('putting down burdens', 'soltar cargas')),
    (Bi('enthusiasm and exploration', 'entusiasmo y exploración'), Bi('scattered enthusiasm', 'entusiasmo disperso')),
    (Bi('adventure and bold action', 'aventura y acción audaz'), Bi('impulsiveness', 'impulsividad')),
    (Bi('confidence, warmth and determination', 'confianza, calidez y determinación'), Bi('insecurity and jealousy', 'inseguridad y celos')),
    (Bi('vision and inspiring leadership', 'visión y liderazgo inspirador'), Bi('impatience and high expectations', 'impaciencia y expectativas altas')),
  ],
  Suit.cups: [
    (Bi('new feelings and an open heart', 'sentimientos nuevos y un corazón abierto'), Bi('blocked or bottled-up emotions', 'emociones bloqueadas o reprimidas')),
    (Bi('partnership and mutual attraction', 'unión y atracción mutua'), Bi('imbalance in a connection', 'desequilibrio en un vínculo')),
    (Bi('friendship and celebration', 'amistad y celebración'), Bi('overindulgence or feeling left out', 'excesos o sentirse excluido')),
    (Bi('apathy and reevaluating', 'apatía y reevaluación'), Bi('new motivation and awareness', 'nueva motivación y conciencia')),
    (Bi('grief and disappointment', 'pena y decepción'), Bi('acceptance and moving on', 'aceptación y pasar página')),
    (Bi('nostalgia and childhood memories', 'nostalgia y recuerdos de infancia'), Bi('living in the past', 'vivir en el pasado')),
    (Bi('choices and daydreams', 'elecciones y ensoñaciones'), Bi('clarity and making a choice', 'claridad y tomar una decisión')),
    (Bi('walking away to seek something deeper', 'alejarse para buscar algo más profundo'), Bi('fear of leaving', 'miedo a irse')),
    (Bi('contentment and wishes fulfilled', 'satisfacción y deseos cumplidos'), Bi('unmet expectations', 'expectativas sin cumplir')),
    (Bi('harmony, family and emotional fulfilment', 'armonía, familia y plenitud emocional'), Bi('disconnection at home', 'desconexión en casa')),
    (Bi('creative feelings and gentle messages', 'sentimientos creativos y mensajes suaves'), Bi('emotional immaturity', 'inmadurez emocional')),
    (Bi('romance and following the heart', 'romance y seguir el corazón'), Bi('moodiness and unrealistic hopes', 'cambios de humor y esperanzas irreales')),
    (Bi('compassion and emotional security', 'compasión y seguridad emocional'), Bi('emotional overwhelm', 'desbordamiento emocional')),
    (Bi('emotional balance and calm', 'equilibrio emocional y calma'), Bi('emotional manipulation or coldness', 'manipulación emocional o frialdad')),
  ],
  Suit.swords: [
    (Bi('clarity and a breakthrough idea', 'claridad y una idea reveladora'), Bi('confusion and mixed messages', 'confusión y mensajes contradictorios')),
    (Bi('a difficult decision and stalemate', 'una decisión difícil y un punto muerto'), Bi('information coming to light', 'información que sale a la luz')),
    (Bi('heartache and painful truth', 'dolor y verdades duras'), Bi('healing and releasing pain', 'sanar y soltar el dolor')),
    (Bi('rest and recovery', 'descanso y recuperación'), Bi('restlessness and burnout', 'inquietud y agotamiento')),
    (Bi('conflict and winning at a cost', 'conflicto y ganar a un precio'), Bi('reconciliation and making amends', 'reconciliación y reparar')),
    (Bi('transition and moving on', 'transición y seguir adelante'), Bi('unfinished business', 'asuntos pendientes')),
    (Bi('strategy and acting alone', 'estrategia y actuar en solitario'), Bi('coming clean', 'sincerarse')),
    (Bi('feeling trapped by thoughts', 'sentirse atrapado por los pensamientos'), Bi('release and new perspective', 'liberación y nueva perspectiva')),
    (Bi('anxiety and worry', 'ansiedad y preocupación'), Bi('hope and reaching out for help', 'esperanza y pedir ayuda')),
    (Bi('an ending and hitting bottom', 'un final y tocar fondo'), Bi('recovery and regeneration', 'recuperación y regeneración')),
    (Bi('curiosity and new ideas', 'curiosidad e ideas nuevas'), Bi('gossip and scattered thoughts', 'chismes y pensamientos dispersos')),
    (Bi('ambition and fast thinking', 'ambición y pensamiento rápido'), Bi('rushing in without a plan', 'lanzarse sin un plan')),
    (Bi('clear boundaries and honesty', 'límites claros y sinceridad'), Bi('coldness or harsh words', 'frialdad o palabras duras')),
    (Bi('intellect, truth and fairness', 'intelecto, verdad y justicia'), Bi('misused power of words', 'mal uso del poder de las palabras')),
  ],
  Suit.pentacles: [
    (Bi('a new opportunity and solid start', 'una nueva oportunidad y un buen comienzo'), Bi('a missed chance or poor planning', 'una oportunidad perdida o mala planificación')),
    (Bi('balancing priorities and adaptability', 'equilibrar prioridades y adaptarse'), Bi('overcommitment', 'comprometerse de más')),
    (Bi('teamwork and skill', 'trabajo en equipo y destreza'), Bi('lack of teamwork', 'falta de trabajo en equipo')),
    (Bi('security and saving', 'seguridad y ahorro'), Bi('holding on too tightly', 'aferrarse demasiado')),
    (Bi('hardship and feeling left out in the cold', 'dificultades y sentirse a la intemperie'), Bi('recovery and finding support', 'recuperación y encontrar apoyo')),
    (Bi('generosity and giving and receiving', 'generosidad y dar y recibir'), Bi('strings attached', 'condiciones ocultas')),
    (Bi('patience and long-term investment', 'paciencia e inversión a largo plazo'), Bi('impatience with slow results', 'impaciencia con los resultados lentos')),
    (Bi('practice and craftsmanship', 'práctica y oficio'), Bi('perfectionism or lack of focus', 'perfeccionismo o falta de concentración')),
    (Bi('independence and self-sufficiency', 'independencia y autosuficiencia'), Bi('overworking', 'trabajar en exceso')),
    (Bi('lasting stability and legacy', 'estabilidad duradera y legado'), Bi('family or money tension', 'tensiones familiares o económicas')),
    (Bi('learning and a new practical goal', 'aprendizaje y una nueva meta práctica'), Bi('procrastination', 'procrastinación')),
    (Bi('steady progress and routine', 'progreso constante y rutina'), Bi('feeling stuck or bored', 'sentirse estancado o aburrido')),
    (Bi('nurturing, practical care and comfort', 'cuidado práctico y comodidad'), Bi('self-neglect', 'descuidarse')),
    (Bi('abundance and dependable leadership', 'abundancia y liderazgo fiable'), Bi('stubbornness or materialism', 'terquedad o materialismo')),
  ],
};

const _rankNames = <(String, String)>[
  ('Ace', 'As'), ('Two', 'Dos'), ('Three', 'Tres'), ('Four', 'Cuatro'), ('Five', 'Cinco'),
  ('Six', 'Seis'), ('Seven', 'Siete'), ('Eight', 'Ocho'), ('Nine', 'Nueve'), ('Ten', 'Diez'),
  ('Page', 'Sota'), ('Knight', 'Caballo'), ('Queen', 'Reina'), ('King', 'Rey'),
];

final List<TarotCard> fullDeck = [
  ...majorArcana,
  for (final suit in Suit.values)
    for (var r = 0; r < 14; r++)
      TarotCard(
        id: '${suit.name}-${r + 1}',
        suit: suit,
        number: r + 1,
        name: Bi('${_rankNames[r].$1} of ${suit.title.en}', '${_rankNames[r].$2} de ${suit.title.es}'),
        upright: _minorKeys[suit]![r].$1,
        reversed: _minorKeys[suit]![r].$2,
      ),
];

TarotCard? cardById(String id) => fullDeck.where((c) => c.id == id).firstOrNull;

class SpreadPosition {
  const SpreadPosition(this.emoji, this.label);
  final String emoji;
  final Bi label;
}

class Spread {
  const Spread(this.id, this.name, this.positions);
  final String id;
  final Bi name;
  final List<SpreadPosition> positions;
}

const spreads = <Spread>[
  Spread('one', Bi('One Card', 'Una carta'), [SpreadPosition('🔮', Bi('Message', 'Mensaje'))]),
  Spread('three', Bi('Three Card', 'Tres cartas'), [SpreadPosition('1️⃣', Bi('First', 'Primera')), SpreadPosition('2️⃣', Bi('Second', 'Segunda')), SpreadPosition('3️⃣', Bi('Third', 'Tercera'))]),
  Spread('ppf', Bi('Past / Present / Future', 'Pasado / Presente / Futuro'), [SpreadPosition('⏪', Bi('Past', 'Pasado')), SpreadPosition('⏺️', Bi('Present', 'Presente')), SpreadPosition('⏩', Bi('Future', 'Futuro'))]),
  Spread('sca', Bi('Situation / Challenge / Advice', 'Situación / Desafío / Consejo'), [SpreadPosition('🧭', Bi('Situation', 'Situación')), SpreadPosition('🌧️', Bi('Challenge', 'Desafío')), SpreadPosition('✨', Bi('Advice', 'Consejo'))]),
  Spread('self', Bi('Self Reflection', 'Autorreflexión'), [SpreadPosition('🪞', Bi('How I see myself', 'Cómo me veo')), SpreadPosition('👀', Bi('How others see me', 'Cómo me ven')), SpreadPosition('💗', Bi('What I need', 'Lo que necesito')), SpreadPosition('🌱', Bi('How to grow', 'Cómo crecer'))]),
  Spread('relationship', Bi('Relationship', 'Relación'), [SpreadPosition('🙋', Bi('Me', 'Yo')), SpreadPosition('🧑‍🤝‍🧑', Bi('Them', 'La otra persona')), SpreadPosition('🔗', Bi('The connection', 'El vínculo')), SpreadPosition('🌧️', Bi('The challenge', 'El desafío')), SpreadPosition('✨', Bi('Advice', 'Consejo'))]),
  Spread('friendship', Bi('Friendship', 'Amistad'), [SpreadPosition('🤝', Bi('What we share', 'Lo que compartimos')), SpreadPosition('🎁', Bi('What I bring', 'Lo que aporto')), SpreadPosition('💝', Bi('What they bring', 'Lo que aporta')), SpreadPosition('🌱', Bi('How to grow together', 'Cómo crecer juntos'))]),
  Spread('decision', Bi('Decision', 'Decisión'), [SpreadPosition('🅰️', Bi('Option A', 'Opción A')), SpreadPosition('🅱️', Bi('Option B', 'Opción B')), SpreadPosition('🔑', Bi('What matters most', 'Lo que más importa')), SpreadPosition('✨', Bi('Advice', 'Consejo'))]),
  Spread('weekly', Bi('Weekly', 'Semanal'), [SpreadPosition('🌱', Bi('Where you are', 'Dónde estás')), SpreadPosition('🧭', Bi('What you\'re moving toward', 'Hacia dónde vas')), SpreadPosition('🪞', Bi('What needs attention', 'Qué necesita atención')), SpreadPosition('❤️', Bi('Relationships', 'Relaciones')), SpreadPosition('✨', Bi('Advice', 'Consejo')), SpreadPosition('🔮', Bi('Week ahead', 'La semana'))]),
  Spread('monthly', Bi('Monthly', 'Mensual'), [SpreadPosition('🌑', Bi('Theme of the month', 'Tema del mes')), SpreadPosition('🌓', Bi('What to begin', 'Qué empezar')), SpreadPosition('🌕', Bi('What to celebrate', 'Qué celebrar')), SpreadPosition('🌗', Bi('What to release', 'Qué soltar')), SpreadPosition('🌱', Bi('Growth', 'Crecimiento')), SpreadPosition('✨', Bi('Advice', 'Consejo'))]),
];

class DrawnCard {
  const DrawnCard(this.card, this.reversed);
  final TarotCard card;
  final bool reversed;

  Map<String, Object?> toJson() => {'id': card.id, 'rev': reversed};

  static DrawnCard? fromJson(Object? v) {
    if (v is! Map) return null;
    final c = cardById('${v['id']}');
    return c == null ? null : DrawnCard(c, v['rev'] == true);
  }
}

/// Draws [count] distinct cards. Reversals come up about a third of the
/// time. A fixed [seed] gives the same draw (used for the daily card).
List<DrawnCard> drawCards(int count, {int? seed}) {
  final rng = seed == null ? math.Random() : math.Random(seed);
  final deck = [...fullDeck]..shuffle(rng);
  return [for (var i = 0; i < count; i++) DrawnCard(deck[i], rng.nextDouble() < 0.33)];
}

/// The day's card for an alter: the same all day, different per alter.
DrawnCard dailyCard(String memberId, DateTime day) {
  var h = day.year * 10000 + day.month * 100 + day.day;
  for (final c in memberId.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return drawCards(1, seed: h).first;
}
