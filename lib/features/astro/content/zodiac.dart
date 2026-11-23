import 'package:prism_plurality/features/astro/engine/ephemeris.dart';

/// Text in English and Spanish.
class Bi {
  const Bi(this.en, this.es);
  final String en;
  final String es;
  String of(bool spanish) => spanish ? es : en;
}

enum AstroElement {
  fire(Bi('Fire', 'Fuego'), '🔥'),
  earth(Bi('Earth', 'Tierra'), '🌱'),
  air(Bi('Air', 'Aire'), '💨'),
  water(Bi('Water', 'Agua'), '💧');

  const AstroElement(this.label, this.emoji);
  final Bi label;
  final String emoji;

  Bi get meaning => switch (this) {
    fire => const Bi('drive, spontaneity and warmth', 'impulso, espontaneidad y calidez'),
    earth => const Bi('steadiness, practicality and the senses', 'estabilidad, sentido práctico y los sentidos'),
    air => const Bi('ideas, words and connection', 'ideas, palabras y conexión'),
    water => const Bi('feeling, intuition and closeness', 'sentimiento, intuición y cercanía'),
  };
}

enum Modality {
  cardinal(Bi('Cardinal', 'Cardinal')),
  fixed(Bi('Fixed', 'Fija')),
  mutable(Bi('Mutable', 'Mutable'));

  const Modality(this.label);
  final Bi label;

  Bi get meaning => switch (this) {
    cardinal => const Bi('starting things and taking the lead', 'empezar cosas y tomar la iniciativa'),
    fixed => const Bi('persistence, loyalty and follow-through', 'constancia, lealtad y perseverancia'),
    mutable => const Bi('adapting, learning and changing course', 'adaptarse, aprender y cambiar de rumbo'),
  };
}

/// Areas each placement is read through.
enum Facet {
  personality(Bi('Personality', 'Personalidad'), '✨'),
  emotions(Bi('Emotional patterns', 'Patrones emocionales'), '💭'),
  communication(Bi('Communication', 'Comunicación'), '🗣️'),
  relationships(Bi('Relationships', 'Relaciones'), '❤️'),
  creativity(Bi('Creativity', 'Creatividad'), '🎨'),
  motivation(Bi('Motivation', 'Motivación'), '🎯'),
  strengths(Bi('Strengths', 'Fortalezas'), '💪'),
  challenges(Bi('Challenges', 'Desafíos'), '🌧️'),
  social(Bi('Social tendencies', 'Tendencias sociales'), '🤝'),
  growth(Bi('Personal growth', 'Crecimiento personal'), '🌱');

  const Facet(this.label, this.emoji);
  final Bi label;
  final String emoji;
}

class SignInfo {
  const SignInfo({
    required this.name,
    required this.glyph,
    required this.element,
    required this.modality,
    required this.ruler,
    required this.dates,
    required this.keywords,
    required this.style,
    required this.facets,
  });

  final Bi name;

  /// The zodiac glyph (draw with [astroGlyphStyle]).
  final String glyph;
  final AstroElement element;
  final Modality modality;
  final Body ruler;
  final Bi dates;
  final Bi keywords;

  /// How things are expressed in this sign ("boldly and directly").
  final Bi style;
  final Map<Facet, Bi> facets;
}

const signs = <SignInfo>[
  SignInfo(
    name: Bi('Aries', 'Aries'),
    glyph: '♈',
    element: AstroElement.fire,
    modality: Modality.cardinal,
    ruler: Body.mars,
    dates: Bi('Mar 21 – Apr 19', '21 mar – 19 abr'),
    keywords: Bi('courage, initiative, directness, energy', 'valentía, iniciativa, franqueza, energía'),
    style: Bi('boldly, quickly and directly', 'con audacia, rapidez y franqueza'),
    facets: {
      Facet.personality: Bi('Often described as brave, honest and quick to act — a natural starter.', 'Suele describirse como valiente, sincero y rápido para actuar: alguien que inicia.'),
      Facet.emotions: Bi('Feelings tend to flare up fast and pass quickly; anger and joy are both out in the open.', 'Los sentimientos suelen encenderse rápido y pasar pronto; el enfado y la alegría se ven a la vista.'),
      Facet.communication: Bi('Says it straight. Values honesty over diplomacy and dislikes beating around the bush.', 'Lo dice claro. Valora la sinceridad por encima de la diplomacia y no le gustan los rodeos.'),
      Facet.relationships: Bi('Loves the spark of new connection and shows care through action and loyalty.', 'Le encanta la chispa de una conexión nueva y demuestra cariño con acciones y lealtad.'),
      Facet.creativity: Bi('Creates in bursts: first drafts, bold ideas, starting projects others will finish.', 'Crea a ráfagas: primeros borradores, ideas audaces, proyectos que otros terminan.'),
      Facet.motivation: Bi('Driven by challenge, competition and the thrill of being first.', 'Le mueve el desafío, la competencia y la emoción de ser el primero.'),
      Facet.strengths: Bi('Courage, enthusiasm, independence and the nerve to try.', 'Valentía, entusiasmo, independencia y el atrevimiento de intentarlo.'),
      Facet.challenges: Bi('Impatience, acting before thinking, and losing interest once the excitement fades.', 'Impaciencia, actuar antes de pensar y perder el interés cuando pasa la emoción.'),
      Facet.social: Bi('Energises a room and often takes the lead in groups.', 'Llena de energía un lugar y a menudo toma la iniciativa en los grupos.'),
      Facet.growth: Bi('Growth often comes from patience, pausing to listen and seeing things through.', 'El crecimiento suele llegar con paciencia, parando a escuchar y terminando lo empezado.'),
    },
  ),
  SignInfo(
    name: Bi('Taurus', 'Tauro'),
    glyph: '♉',
    element: AstroElement.earth,
    modality: Modality.fixed,
    ruler: Body.venus,
    dates: Bi('Apr 20 – May 20', '20 abr – 20 may'),
    keywords: Bi('stability, comfort, patience, the senses', 'estabilidad, comodidad, paciencia, los sentidos'),
    style: Bi('steadily, patiently and sensually', 'con constancia, paciencia y sensualidad'),
    facets: {
      Facet.personality: Bi('Traditionally grounded, calm and reliable, with a love of beauty and comfort.', 'Tradicionalmente arraigado, tranquilo y fiable, con amor por la belleza y la comodidad.'),
      Facet.emotions: Bi('Slow to upset and slow to let go; feels safest with routine and familiar things.', 'Tarda en alterarse y en soltar; se siente más seguro con la rutina y lo conocido.'),
      Facet.communication: Bi('Speaks thoughtfully and means what it says; prefers practical talk to abstractions.', 'Habla con calma y dice lo que piensa; prefiere lo práctico a lo abstracto.'),
      Facet.relationships: Bi('Loyal and affectionate; shows love through presence, touch, food and dependability.', 'Leal y cariñoso; demuestra amor con presencia, contacto, comida y fiabilidad.'),
      Facet.creativity: Bi('Drawn to crafts, music, cooking, gardening — anything made by hand and enjoyed by the senses.', 'Atraído por la artesanía, la música, la cocina, la jardinería: lo hecho a mano y disfrutado con los sentidos.'),
      Facet.motivation: Bi('Moved by security, comfort and building something that lasts.', 'Le mueve la seguridad, la comodidad y construir algo duradero.'),
      Facet.strengths: Bi('Patience, persistence, loyalty and a calming presence.', 'Paciencia, constancia, lealtad y una presencia tranquilizadora.'),
      Facet.challenges: Bi('Stubbornness, resisting change and holding on longer than helps.', 'Testarudez, resistirse al cambio y aferrarse más de lo que conviene.'),
      Facet.social: Bi('Prefers a few close people and cosy gatherings to big crowds.', 'Prefiere pocas personas cercanas y reuniones acogedoras a las multitudes.'),
      Facet.growth: Bi('Growth often comes from trusting change and staying flexible.', 'El crecimiento suele llegar al confiar en el cambio y mantenerse flexible.'),
    },
  ),
  SignInfo(
    name: Bi('Gemini', 'Géminis'),
    glyph: '♊',
    element: AstroElement.air,
    modality: Modality.mutable,
    ruler: Body.mercury,
    dates: Bi('May 21 – Jun 20', '21 may – 20 jun'),
    keywords: Bi('curiosity, wit, variety, conversation', 'curiosidad, ingenio, variedad, conversación'),
    style: Bi('curiously, playfully and with many words', 'con curiosidad, juego y muchas palabras'),
    facets: {
      Facet.personality: Bi('Often seen as quick, curious, funny and endlessly interested in things.', 'Se le suele ver rápido, curioso, divertido e interesado por todo.'),
      Facet.emotions: Bi('Processes feelings by talking or thinking them through; moods can shift quickly.', 'Procesa los sentimientos hablándolos o pensándolos; el ánimo puede cambiar rápido.'),
      Facet.communication: Bi('A natural talker and writer who loves questions, stories and wordplay.', 'Habla y escribe con facilidad; le encantan las preguntas, las historias y los juegos de palabras.'),
      Facet.relationships: Bi('Needs mental connection and conversation; boredom is the real deal-breaker.', 'Necesita conexión mental y conversación; el aburrimiento es lo que de verdad le aleja.'),
      Facet.creativity: Bi('Juggles many ideas at once; thrives in writing, media and mixing different interests.', 'Maneja muchas ideas a la vez; brilla en la escritura, los medios y mezclando intereses.'),
      Facet.motivation: Bi('Moved by learning, novelty and the next interesting thing.', 'Le mueve aprender, la novedad y lo siguiente interesante.'),
      Facet.strengths: Bi('Adaptability, humour, quick thinking and seeing many sides.', 'Adaptabilidad, humor, rapidez mental y ver muchos lados.'),
      Facet.challenges: Bi('Scattered focus, restlessness and staying on the surface.', 'Atención dispersa, inquietud y quedarse en la superficie.'),
      Facet.social: Bi('Sociable and well connected; knows a bit about everyone.', 'Sociable y bien conectado; sabe un poco de todo el mundo.'),
      Facet.growth: Bi('Growth often comes from depth: following one thread all the way through.', 'El crecimiento suele llegar con profundidad: seguir un hilo hasta el final.'),
    },
  ),
  SignInfo(
    name: Bi('Cancer', 'Cáncer'),
    glyph: '♋',
    element: AstroElement.water,
    modality: Modality.cardinal,
    ruler: Body.moon,
    dates: Bi('Jun 21 – Jul 22', '21 jun – 22 jul'),
    keywords: Bi('care, home, memory, protection', 'cuidado, hogar, memoria, protección'),
    style: Bi('protectively, tenderly and from the heart', 'con protección, ternura y desde el corazón'),
    facets: {
      Facet.personality: Bi('Traditionally nurturing, intuitive and deeply loyal to the people it calls home.', 'Tradicionalmente protector, intuitivo y muy leal a quienes considera su hogar.'),
      Facet.emotions: Bi('Feels deeply and remembers everything; needs a safe place to land.', 'Siente profundamente y lo recuerda todo; necesita un lugar seguro donde refugiarse.'),
      Facet.communication: Bi('Reads the mood before speaking; says a lot through tone and care.', 'Lee el ambiente antes de hablar; dice mucho con el tono y el cuidado.'),
      Facet.relationships: Bi('Devoted and protective; builds family wherever it goes.', 'Entregado y protector; forma familia allá donde va.'),
      Facet.creativity: Bi('Inspired by memories, nostalgia, home and stories about belonging.', 'Se inspira en recuerdos, nostalgia, el hogar e historias de pertenencia.'),
      Facet.motivation: Bi('Moved by keeping loved ones safe and creating a sense of home.', 'Le mueve proteger a los suyos y crear un sentido de hogar.'),
      Facet.strengths: Bi('Empathy, loyalty, intuition and a caring memory.', 'Empatía, lealtad, intuición y una memoria afectuosa.'),
      Facet.challenges: Bi('Moodiness, retreating into its shell and taking things personally.', 'Cambios de humor, encerrarse en su caparazón y tomarse las cosas a pecho.'),
      Facet.social: Bi('Warm with familiar people, shy with strangers at first.', 'Cálido con lo conocido, tímido al principio con desconocidos.'),
      Facet.growth: Bi('Growth often comes from caring for itself as well as it cares for others.', 'El crecimiento suele llegar al cuidarse tanto como cuida de los demás.'),
    },
  ),
  SignInfo(
    name: Bi('Leo', 'Leo'),
    glyph: '♌',
    element: AstroElement.fire,
    modality: Modality.fixed,
    ruler: Body.sun,
    dates: Bi('Jul 23 – Aug 22', '23 jul – 22 ago'),
    keywords: Bi('self-expression, warmth, play, pride', 'expresión, calidez, juego, orgullo'),
    style: Bi('warmly, generously and with flair', 'con calidez, generosidad y estilo'),
    facets: {
      Facet.personality: Bi('Often radiant, generous and expressive, with a big heart and a love of play.', 'Suele ser radiante, generoso y expresivo, de gran corazón y amante del juego.'),
      Facet.emotions: Bi('Feels proudly and openly; needs to feel seen and appreciated.', 'Siente con orgullo y abiertamente; necesita sentirse visto y valorado.'),
      Facet.communication: Bi('Expressive and dramatic in the best way; a natural storyteller.', 'Expresivo y teatral en el mejor sentido; un narrador nato.'),
      Facet.relationships: Bi('Loyal, affectionate and generous; loves celebrating the people it loves.', 'Leal, cariñoso y generoso; le encanta celebrar a quienes quiere.'),
      Facet.creativity: Bi('Creativity is central: performing, making, hosting and being playful.', 'La creatividad es central: actuar, crear, organizar y jugar.'),
      Facet.motivation: Bi('Moved by recognition, joy and leaving a personal mark.', 'Le mueve el reconocimiento, la alegría y dejar huella.'),
      Facet.strengths: Bi('Confidence, warmth, generosity and courage of the heart.', 'Confianza, calidez, generosidad y valentía de corazón.'),
      Facet.challenges: Bi('Pride, needing approval and feeling hurt when overlooked.', 'Orgullo, necesitar aprobación y dolerse cuando no se le tiene en cuenta.'),
      Facet.social: Bi('Lights up groups and often becomes the centre of the fun.', 'Ilumina los grupos y a menudo se vuelve el centro de la diversión.'),
      Facet.growth: Bi('Growth often comes from shining without needing an audience.', 'El crecimiento suele llegar al brillar sin necesitar público.'),
    },
  ),
  SignInfo(
    name: Bi('Virgo', 'Virgo'),
    glyph: '♍',
    element: AstroElement.earth,
    modality: Modality.mutable,
    ruler: Body.mercury,
    dates: Bi('Aug 23 – Sep 22', '23 ago – 22 sep'),
    keywords: Bi('care, skill, analysis, usefulness', 'cuidado, destreza, análisis, utilidad'),
    style: Bi('carefully, precisely and helpfully', 'con cuidado, precisión y ganas de ayudar'),
    facets: {
      Facet.personality: Bi('Traditionally observant, thoughtful and quietly devoted to doing things well.', 'Tradicionalmente observador, reflexivo y entregado en silencio a hacer bien las cosas.'),
      Facet.emotions: Bi('Tends to analyse feelings and may worry; calmed by order and useful tasks.', 'Tiende a analizar los sentimientos y puede preocuparse; le calma el orden y lo útil.'),
      Facet.communication: Bi('Precise, helpful and detailed; notices what others miss.', 'Preciso, servicial y detallista; nota lo que otros pasan por alto.'),
      Facet.relationships: Bi('Shows love through acts of service, practical help and remembering details.', 'Demuestra amor con favores, ayuda práctica y recordando detalles.'),
      Facet.creativity: Bi('Loves craft, editing and perfecting; creativity through skill and refinement.', 'Le encanta el oficio, editar y perfeccionar; crea con destreza y pulido.'),
      Facet.motivation: Bi('Moved by being useful, improving things and doing a job right.', 'Le mueve ser útil, mejorar las cosas y hacer bien el trabajo.'),
      Facet.strengths: Bi('Attention to detail, reliability, humility and practical care.', 'Atención al detalle, fiabilidad, humildad y cuidado práctico.'),
      Facet.challenges: Bi('Self-criticism, perfectionism and overthinking.', 'Autocrítica, perfeccionismo y pensar demasiado.'),
      Facet.social: Bi('The helper in the group: organised, attentive and modest.', 'El que ayuda en el grupo: organizado, atento y modesto.'),
      Facet.growth: Bi('Growth often comes from accepting "good enough" and being gentle with itself.', 'El crecimiento suele llegar al aceptar lo "suficientemente bueno" y ser amable consigo.'),
    },
  ),
  SignInfo(
    name: Bi('Libra', 'Libra'),
    glyph: '♎',
    element: AstroElement.air,
    modality: Modality.cardinal,
    ruler: Body.venus,
    dates: Bi('Sep 23 – Oct 22', '23 sep – 22 oct'),
    keywords: Bi('harmony, fairness, beauty, partnership', 'armonía, justicia, belleza, pareja'),
    style: Bi('gracefully, diplomatically and in balance', 'con elegancia, diplomacia y equilibrio'),
    facets: {
      Facet.personality: Bi('Often charming, fair-minded and drawn to beauty and balance.', 'Suele ser encantador, justo y atraído por la belleza y el equilibrio.'),
      Facet.emotions: Bi('Seeks calm and may smooth over conflict; feels best when things are fair.', 'Busca calma y puede suavizar los conflictos; se siente mejor cuando hay justicia.'),
      Facet.communication: Bi('Diplomatic and considerate; good at seeing both sides.', 'Diplomático y considerado; sabe ver ambos lados.'),
      Facet.relationships: Bi('Partnership-minded; values harmony, mutual respect and shared beauty.', 'Piensa en pareja; valora la armonía, el respeto mutuo y la belleza compartida.'),
      Facet.creativity: Bi('A strong eye for design, style, music and pleasing arrangements.', 'Buen ojo para el diseño, el estilo, la música y lo armonioso.'),
      Facet.motivation: Bi('Moved by fairness, connection and making things lovely.', 'Le mueve la justicia, la conexión y embellecer las cosas.'),
      Facet.strengths: Bi('Tact, fairness, charm and bringing people together.', 'Tacto, justicia, encanto y unir a las personas.'),
      Facet.challenges: Bi('Indecision, people-pleasing and avoiding needed conflict.', 'Indecisión, querer complacer y evitar conflictos necesarios.'),
      Facet.social: Bi('Graceful host and natural mediator.', 'Anfitrión elegante y mediador natural.'),
      Facet.growth: Bi('Growth often comes from knowing its own wants and saying them out loud.', 'El crecimiento suele llegar al conocer lo que quiere y decirlo en voz alta.'),
    },
  ),
  SignInfo(
    name: Bi('Scorpio', 'Escorpio'),
    glyph: '♏',
    element: AstroElement.water,
    modality: Modality.fixed,
    ruler: Body.pluto,
    dates: Bi('Oct 23 – Nov 21', '23 oct – 21 nov'),
    keywords: Bi('depth, intensity, trust, transformation', 'profundidad, intensidad, confianza, transformación'),
    style: Bi('intensely, privately and all the way', 'con intensidad, reserva y hasta el fondo'),
    facets: {
      Facet.personality: Bi('Traditionally deep, perceptive and private, with strong loyalty and resolve.', 'Tradicionalmente profundo, perspicaz y reservado, con gran lealtad y determinación.'),
      Facet.emotions: Bi('Feels intensely but shows little at first; trust is earned slowly.', 'Siente con intensidad pero al principio muestra poco; la confianza se gana despacio.'),
      Facet.communication: Bi('Reads between the lines; prefers honest, meaningful talk to small talk.', 'Lee entre líneas; prefiere conversaciones sinceras y profundas a la charla trivial.'),
      Facet.relationships: Bi('All-in when committed; values loyalty, honesty and emotional closeness.', 'Se entrega por completo; valora la lealtad, la sinceridad y la cercanía emocional.'),
      Facet.creativity: Bi('Drawn to mysteries, psychology and art that goes beneath the surface.', 'Atraído por los misterios, la psicología y el arte que va bajo la superficie.'),
      Facet.motivation: Bi('Moved by truth, depth and real transformation.', 'Le mueve la verdad, la profundidad y la transformación real.'),
      Facet.strengths: Bi('Resilience, perception, loyalty and emotional courage.', 'Resiliencia, percepción, lealtad y valentía emocional.'),
      Facet.challenges: Bi('Suspicion, holding grudges and all-or-nothing thinking.', 'Desconfianza, guardar rencor y pensar en todo o nada.'),
      Facet.social: Bi('Selective about people; magnetic once comfortable.', 'Selectivo con la gente; magnético cuando se siente cómodo.'),
      Facet.growth: Bi('Growth often comes from letting go and trusting gradually.', 'El crecimiento suele llegar al soltar y confiar poco a poco.'),
    },
  ),
  SignInfo(
    name: Bi('Sagittarius', 'Sagitario'),
    glyph: '♐',
    element: AstroElement.fire,
    modality: Modality.mutable,
    ruler: Body.jupiter,
    dates: Bi('Nov 22 – Dec 21', '22 nov – 21 dic'),
    keywords: Bi('adventure, meaning, optimism, freedom', 'aventura, sentido, optimismo, libertad'),
    style: Bi('freely, optimistically and with big-picture vision', 'con libertad, optimismo y visión amplia'),
    facets: {
      Facet.personality: Bi('Often adventurous, honest and optimistic, always looking for the bigger meaning.', 'Suele ser aventurero, sincero y optimista, siempre buscando el sentido más amplio.'),
      Facet.emotions: Bi('Bounces back quickly and looks for the lesson; may avoid heavy feelings.', 'Se recupera rápido y busca la lección; puede evitar los sentimientos pesados.'),
      Facet.communication: Bi('Frank, funny and philosophical; loves big ideas and good stories.', 'Franco, divertido y filosófico; le encantan las grandes ideas y las buenas historias.'),
      Facet.relationships: Bi('Needs freedom and shared adventures; values honesty above all.', 'Necesita libertad y aventuras compartidas; valora la sinceridad por encima de todo.'),
      Facet.creativity: Bi('Inspired by travel, cultures, belief systems and learning.', 'Se inspira en los viajes, las culturas, las creencias y el aprendizaje.'),
      Facet.motivation: Bi('Moved by freedom, growth and finding meaning.', 'Le mueve la libertad, el crecimiento y encontrar sentido.'),
      Facet.strengths: Bi('Optimism, generosity, honesty and a sense of humour.', 'Optimismo, generosidad, sinceridad y sentido del humor.'),
      Facet.challenges: Bi('Restlessness, overpromising and bluntness.', 'Inquietud, prometer de más y brusquedad.'),
      Facet.social: Bi('Friendly with everyone and great company on any outing.', 'Amable con todos y gran compañía en cualquier salida.'),
      Facet.growth: Bi('Growth often comes from commitment and following through on big plans.', 'El crecimiento suele llegar con compromiso y llevando a cabo los grandes planes.'),
    },
  ),
  SignInfo(
    name: Bi('Capricorn', 'Capricornio'),
    glyph: '♑',
    element: AstroElement.earth,
    modality: Modality.cardinal,
    ruler: Body.saturn,
    dates: Bi('Dec 22 – Jan 19', '22 dic – 19 ene'),
    keywords: Bi('ambition, responsibility, structure, endurance', 'ambición, responsabilidad, estructura, resistencia'),
    style: Bi('responsibly, patiently and with a plan', 'con responsabilidad, paciencia y un plan'),
    facets: {
      Facet.personality: Bi('Traditionally capable, disciplined and dry-humoured, with a long-term view.', 'Tradicionalmente capaz, disciplinado y de humor seco, con visión a largo plazo.'),
      Facet.emotions: Bi('Keeps feelings private and handles them practically; softens with trust.', 'Guarda los sentimientos para sí y los maneja con sentido práctico; se ablanda con confianza.'),
      Facet.communication: Bi('Measured and to the point; respects competence and keeps its word.', 'Mesurado y directo; respeta la competencia y cumple su palabra.'),
      Facet.relationships: Bi('Loyal and committed; shows love by being dependable and building a future.', 'Leal y comprometido; demuestra amor siendo fiable y construyendo futuro.'),
      Facet.creativity: Bi('Builds slowly and seriously; drawn to classic forms and lasting work.', 'Construye despacio y en serio; atraído por las formas clásicas y lo duradero.'),
      Facet.motivation: Bi('Moved by achievement, respect and mastering its craft.', 'Le mueve el logro, el respeto y dominar su oficio.'),
      Facet.strengths: Bi('Discipline, reliability, patience and practical wisdom.', 'Disciplina, fiabilidad, paciencia y sabiduría práctica.'),
      Facet.challenges: Bi('Pessimism, overworking and being hard on itself.', 'Pesimismo, trabajar en exceso y ser duro consigo.'),
      Facet.social: Bi('A steady presence people rely on; warms up over time.', 'Una presencia estable en la que se confía; se abre con el tiempo.'),
      Facet.growth: Bi('Growth often comes from rest, play and letting others help.', 'El crecimiento suele llegar con descanso, juego y dejándose ayudar.'),
    },
  ),
  SignInfo(
    name: Bi('Aquarius', 'Acuario'),
    glyph: '♒',
    element: AstroElement.air,
    modality: Modality.fixed,
    ruler: Body.uranus,
    dates: Bi('Jan 20 – Feb 18', '20 ene – 18 feb'),
    keywords: Bi('originality, community, ideals, independence', 'originalidad, comunidad, ideales, independencia'),
    style: Bi('originally, independently and with the future in mind', 'con originalidad, independencia y pensando en el futuro'),
    facets: {
      Facet.personality: Bi('Often original, idealistic and independent, with a strong sense of fairness.', 'Suele ser original, idealista e independiente, con un fuerte sentido de la justicia.'),
      Facet.emotions: Bi('Thinks about feelings before feeling them; needs space to process.', 'Piensa los sentimientos antes de sentirlos; necesita espacio para procesar.'),
      Facet.communication: Bi('Inventive and open-minded; loves unusual ideas and honest debate.', 'Ingenioso y de mente abierta; le encantan las ideas poco comunes y el debate sincero.'),
      Facet.relationships: Bi('Friendship comes first; values freedom, honesty and being accepted as it is.', 'Primero la amistad; valora la libertad, la sinceridad y ser aceptado tal cual.'),
      Facet.creativity: Bi('Experimental and future-facing: technology, invention and breaking moulds.', 'Experimental y futurista: tecnología, invención y romper moldes.'),
      Facet.motivation: Bi('Moved by ideals, community and changing things for the better.', 'Le mueven los ideales, la comunidad y cambiar las cosas a mejor.'),
      Facet.strengths: Bi('Originality, open-mindedness, loyalty to friends and vision.', 'Originalidad, mente abierta, lealtad a los amigos y visión.'),
      Facet.challenges: Bi('Detachment, stubborn ideas and keeping feelings at arm\'s length.', 'Distancia, ideas testarudas y mantener los sentimientos lejos.'),
      Facet.social: Bi('Part of many groups and communities; friend to all, close to few.', 'Parte de muchos grupos y comunidades; amigo de todos, cercano a pocos.'),
      Facet.growth: Bi('Growth often comes from letting feelings in, not just ideas.', 'El crecimiento suele llegar al dejar entrar los sentimientos, no solo las ideas.'),
    },
  ),
  SignInfo(
    name: Bi('Pisces', 'Piscis'),
    glyph: '♓',
    element: AstroElement.water,
    modality: Modality.mutable,
    ruler: Body.neptune,
    dates: Bi('Feb 19 – Mar 20', '19 feb – 20 mar'),
    keywords: Bi('imagination, compassion, intuition, dreams', 'imaginación, compasión, intuición, sueños'),
    style: Bi('imaginatively, gently and intuitively', 'con imaginación, suavidad e intuición'),
    facets: {
      Facet.personality: Bi('Traditionally gentle, imaginative and compassionate, with a rich inner world.', 'Tradicionalmente suave, imaginativo y compasivo, con un rico mundo interior.'),
      Facet.emotions: Bi('Absorbs the feelings around it; needs quiet time to recharge.', 'Absorbe los sentimientos de su alrededor; necesita tiempo tranquilo para recargarse.'),
      Facet.communication: Bi('Speaks in images and feelings; listens with real empathy.', 'Habla con imágenes y sentimientos; escucha con verdadera empatía.'),
      Facet.relationships: Bi('Romantic and devoted; sees the best in people.', 'Romántico y entregado; ve lo mejor de las personas.'),
      Facet.creativity: Bi('Deeply artistic: music, poetry, film, dreams and fantasy.', 'Muy artístico: música, poesía, cine, sueños y fantasía.'),
      Facet.motivation: Bi('Moved by compassion, beauty and a sense of something larger.', 'Le mueve la compasión, la belleza y la sensación de algo más grande.'),
      Facet.strengths: Bi('Empathy, imagination, kindness and intuition.', 'Empatía, imaginación, bondad e intuición.'),
      Facet.challenges: Bi('Escapism, blurry boundaries and losing itself in others.', 'Evasión, límites difusos y perderse en los demás.'),
      Facet.social: Bi('Gentle and accepting; people confide in it easily.', 'Suave y comprensivo; la gente se le confía con facilidad.'),
      Facet.growth: Bi('Growth often comes from clear boundaries and grounding routines.', 'El crecimiento suele llegar con límites claros y rutinas que le arraiguen.'),
    },
  ),
];

class PlanetInfo {
  const PlanetInfo(this.name, this.glyph, this.meaning, this.short, this.facets);
  final Bi name;
  final String glyph;

  /// What the planet represents, as a full sentence.
  final Bi meaning;

  /// One-phrase summary ("love and values").
  final Bi short;

  /// The areas it speaks to most.
  final List<Facet> facets;
}

const planets = <Body, PlanetInfo>{
  Body.sun: PlanetInfo(Bi('Sun', 'Sol'), '☉', Bi('The Sun represents identity, vitality, purpose and the core self.', 'El Sol representa la identidad, la vitalidad, el propósito y el yo esencial.'), Bi('core self', 'el yo esencial'), [Facet.personality, Facet.motivation, Facet.strengths, Facet.growth]),
  Body.moon: PlanetInfo(Bi('Moon', 'Luna'), '☽', Bi('The Moon represents emotions, comfort, instinct, memory and what makes you feel safe.', 'La Luna representa las emociones, el consuelo, el instinto, la memoria y lo que te hace sentir seguro.'), Bi('emotions and comfort', 'emociones y consuelo'), [Facet.emotions, Facet.relationships, Facet.challenges]),
  Body.mercury: PlanetInfo(Bi('Mercury', 'Mercurio'), '☿', Bi('Mercury represents thinking, communication, learning and how you process information.', 'Mercurio representa el pensamiento, la comunicación, el aprendizaje y cómo procesas la información.'), Bi('mind and words', 'mente y palabras'), [Facet.communication, Facet.social]),
  Body.venus: PlanetInfo(Bi('Venus', 'Venus'), '♀', Bi('Venus represents relationships, affection, attraction, values and aesthetics.', 'Venus representa las relaciones, el afecto, la atracción, los valores y la estética.'), Bi('love and values', 'amor y valores'), [Facet.relationships, Facet.creativity, Facet.social]),
  Body.mars: PlanetInfo(Bi('Mars', 'Marte'), '♂', Bi('Mars represents drive, action, desire, courage and how you handle conflict.', 'Marte representa el impulso, la acción, el deseo, la valentía y cómo manejas los conflictos.'), Bi('drive and action', 'impulso y acción'), [Facet.motivation, Facet.challenges, Facet.strengths]),
  Body.jupiter: PlanetInfo(Bi('Jupiter', 'Júpiter'), '♃', Bi('Jupiter represents growth, luck, generosity, wisdom and where life tends to expand.', 'Júpiter representa el crecimiento, la suerte, la generosidad, la sabiduría y dónde la vida tiende a expandirse.'), Bi('growth and luck', 'crecimiento y suerte'), [Facet.growth, Facet.strengths]),
  Body.saturn: PlanetInfo(Bi('Saturn', 'Saturno'), '♄', Bi('Saturn represents structure, responsibility, limits, time and the lessons that build maturity.', 'Saturno representa la estructura, la responsabilidad, los límites, el tiempo y las lecciones que dan madurez.'), Bi('structure and lessons', 'estructura y lecciones'), [Facet.challenges, Facet.growth]),
  Body.uranus: PlanetInfo(Bi('Uranus', 'Urano'), '♅', Bi('Uranus represents change, originality, freedom and sudden insight.', 'Urano representa el cambio, la originalidad, la libertad y la intuición repentina.'), Bi('change and originality', 'cambio y originalidad'), [Facet.personality, Facet.growth]),
  Body.neptune: PlanetInfo(Bi('Neptune', 'Neptuno'), '♆', Bi('Neptune represents dreams, imagination, spirituality, compassion and the blurring of boundaries.', 'Neptuno representa los sueños, la imaginación, la espiritualidad, la compasión y los límites difusos.'), Bi('dreams and imagination', 'sueños e imaginación'), [Facet.creativity, Facet.emotions]),
  Body.pluto: PlanetInfo(Bi('Pluto', 'Plutón'), '♇', Bi('Pluto represents transformation, power, depth and renewal.', 'Plutón representa la transformación, el poder, la profundidad y la renovación.'), Bi('transformation', 'transformación'), [Facet.growth, Facet.challenges]),
  Body.node: PlanetInfo(Bi('North Node', 'Nodo Norte'), '☊', Bi('The North Node is traditionally read as a direction of growth — qualities worth developing over a lifetime.', 'El Nodo Norte se lee tradicionalmente como una dirección de crecimiento: cualidades que vale la pena desarrollar a lo largo de la vida.'), Bi('direction of growth', 'dirección de crecimiento'), [Facet.growth]),
  Body.chiron: PlanetInfo(Bi('Chiron', 'Quirón'), '⚷', Bi('Chiron is read as a tender spot that, once understood, becomes a source of empathy and helping others.', 'Quirón se lee como un punto sensible que, al comprenderlo, se vuelve fuente de empatía y de ayuda a otros.'), Bi('healing and empathy', 'sanación y empatía'), [Facet.challenges, Facet.growth]),
};

class HouseInfo {
  const HouseInfo(this.area, this.theme, this.titles);

  /// What the house covers.
  final Bi area;

  /// A short noun phrase ("home and family").
  final Bi theme;

  /// Daily theme titles when the Moon passes through.
  final List<Bi> titles;
}

const houses = <HouseInfo>[
  HouseInfo(Bi('self, appearance, first impressions and new beginnings', 'el yo, la apariencia, las primeras impresiones y los comienzos'), Bi('self and fresh starts', 'el yo y los comienzos'), [Bi('A fresh start', 'Un nuevo comienzo'), Bi('Showing up as yourself', 'Mostrarte tal como eres')]),
  HouseInfo(Bi('money, possessions, values and self-worth', 'el dinero, las posesiones, los valores y la autoestima'), Bi('resources and self-worth', 'recursos y autoestima'), [Bi('What you value', 'Lo que valoras'), Bi('Small comforts', 'Pequeños placeres')]),
  HouseInfo(Bi('communication, learning, siblings, neighbours and short trips', 'la comunicación, el aprendizaje, los hermanos, los vecinos y los viajes cortos'), Bi('conversation and learning', 'conversación y aprendizaje'), [Bi('Messages and conversations', 'Mensajes y conversaciones'), Bi('A curious mind', 'Una mente curiosa')]),
  HouseInfo(Bi('home, family, roots and inner foundations', 'el hogar, la familia, las raíces y los cimientos interiores'), Bi('home and inner life', 'hogar y vida interior'), [Bi('Coming home to yourself', 'Volver a ti'), Bi('Rest and roots', 'Descanso y raíces')]),
  HouseInfo(Bi('creativity, play, romance, joy and self-expression', 'la creatividad, el juego, el romance, la alegría y la expresión'), Bi('play and creativity', 'juego y creatividad'), [Bi('Room to play', 'Espacio para jugar'), Bi('Creative spark', 'Chispa creativa')]),
  HouseInfo(Bi('daily routines, work, health habits and being useful', 'las rutinas diarias, el trabajo, los hábitos de salud y ser útil'), Bi('routines and wellbeing', 'rutinas y bienestar'), [Bi('Tending the routines', 'Cuidar las rutinas'), Bi('Small steps that help', 'Pequeños pasos que ayudan')]),
  HouseInfo(Bi('partnerships, close one-to-one connections and agreements', 'las parejas, las relaciones uno a uno y los acuerdos'), Bi('partnership', 'pareja y vínculos'), [Bi('Meeting in the middle', 'Encontrarse a medio camino'), Bi('One-to-one connection', 'Conexión uno a uno')]),
  HouseInfo(Bi('intimacy, shared resources, trust and transformation', 'la intimidad, los recursos compartidos, la confianza y la transformación'), Bi('depth and trust', 'profundidad y confianza'), [Bi('Going deeper', 'Ir más hondo'), Bi('Letting something go', 'Soltar algo')]),
  HouseInfo(Bi('beliefs, travel, study, big ideas and meaning', 'las creencias, los viajes, el estudio, las grandes ideas y el sentido'), Bi('meaning and exploration', 'sentido y exploración'), [Bi('The bigger picture', 'La visión de conjunto'), Bi('Something new to learn', 'Algo nuevo que aprender')]),
  HouseInfo(Bi('goals, reputation, career and public life', 'las metas, la reputación, la carrera y la vida pública'), Bi('goals and direction', 'metas y dirección'), [Bi('Steps toward a goal', 'Pasos hacia una meta'), Bi('Taking responsibility', 'Asumir responsabilidad')]),
  HouseInfo(Bi('friendships, groups, community and hopes for the future', 'las amistades, los grupos, la comunidad y las esperanzas'), Bi('friends and community', 'amistades y comunidad'), [Bi('Recharging your social battery', 'Recargar tu batería social'), Bi('Your people', 'Tu gente')]),
  HouseInfo(Bi('rest, solitude, dreams, the subconscious and quiet healing', 'el descanso, la soledad, los sueños, el subconsciente y la sanación silenciosa'), Bi('rest and reflection', 'descanso y reflexión'), [Bi('Quiet recharge', 'Recarga en calma'), Bi('Listening inward', 'Escuchar hacia dentro')]),
];

class AspectInfo {
  const AspectInfo(this.name, this.glyph, this.meaning);
  final Bi name;
  final String glyph;
  final Bi meaning;
}

/// Indexed by AspectType.index.
const aspectNames = [
  AspectInfo(Bi('Conjunction', 'Conjunción'), '☌', Bi('blend and intensify each other', 'se mezclan e intensifican')),
  AspectInfo(Bi('Sextile', 'Sextil'), '⚹', Bi('offer each other easy opportunities', 'se ofrecen oportunidades fáciles')),
  AspectInfo(Bi('Square', 'Cuadratura'), '□', Bi('create friction that pushes for growth', 'crean una fricción que empuja a crecer')),
  AspectInfo(Bi('Trine', 'Trígono'), '△', Bi('flow together naturally', 'fluyen juntos con naturalidad')),
  AspectInfo(Bi('Opposition', 'Oposición'), '☍', Bi('pull in different directions, asking for balance', 'tiran en direcciones distintas y piden equilibrio')),
];

/// Ordinal house label: "1st", "2nd"… / "1.ª", "2.ª"…
String houseOrdinal(int h, bool es) {
  if (es) return '$h.ª';
  final suffix = (h % 100 >= 11 && h % 100 <= 13)
      ? 'th'
      : switch (h % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$h$suffix';
}

/// "12° 34′ Libra"
String formatPosition(double longitude, bool es, {bool sign = true}) {
  final d = longitude % 30;
  final deg = d.floor();
  final min = ((d - deg) * 60).floor();
  return '$deg° ${min.toString().padLeft(2, '0')}′${sign ? ' ${signs[signOf(longitude)].name.of(es)}' : ''}';
}
