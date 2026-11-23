import 'package:prism_plurality/features/astro/content/zodiac.dart';

enum ArticleCategory {
  moon('🌙', Bi('Moon Events', 'Eventos lunares')),
  solar('☀️', Bi('Solar Events', 'Eventos solares')),
  planets('🪐', Bi('Planetary Transits', 'Tránsitos planetarios')),
  zodiac('♈', Bi('Zodiac', 'Zodiaco')),
  tarot('🔮', Bi('Tarot', 'Tarot')),
  basics('💫', Bi('Astrology Basics', 'Astrología básica')),
  reflection('🌱', Bi('Self-reflection', 'Autorreflexión')),
  education('📚', Bi('Astrology Education', 'Educación astrológica'));

  const ArticleCategory(this.emoji, this.label);
  final String emoji;
  final Bi label;
}

class AstroArticle {
  const AstroArticle(this.id, this.category, this.title, this.paragraphs);
  final String id;
  final ArticleCategory category;
  final Bi title;
  final List<Bi> paragraphs;
}

/// Shown at the end of every article.
const scienceNote = Bi(
  'A note on evidence: astrology is a centuries-old symbolic tradition. Controlled studies have not found that planetary positions predict personality or events. Prism offers it as a language for reflection — keep what helps and leave what doesn\'t.',
  'Sobre la evidencia: la astrología es una tradición simbólica de siglos. Los estudios controlados no han encontrado que las posiciones planetarias predigan la personalidad ni los acontecimientos. Prism la ofrece como un lenguaje para reflexionar: quédate con lo que te ayude y deja lo que no.',
);

const articles = <AstroArticle>[
  AstroArticle('mercury', ArticleCategory.basics, Bi('What does Mercury represent in astrology?', '¿Qué representa Mercurio en astrología?'), [
    Bi('Mercury is the planet of the mind: thinking, speaking, writing, learning and moving information around. Astrologers look at its sign to describe someone\'s communication style.', 'Mercurio es el planeta de la mente: pensar, hablar, escribir, aprender y mover información. Los astrólogos miran su signo para describir el estilo de comunicación.'),
    Bi('A Mercury in a fire sign is traditionally quick and direct; in earth, practical and careful; in air, curious and talkative; in water, intuitive and feeling-led.', 'Un Mercurio en un signo de fuego es tradicionalmente rápido y directo; en tierra, práctico y cuidadoso; en aire, curioso y hablador; en agua, intuitivo y guiado por el sentir.'),
    Bi('Three or four times a year Mercury appears to move backwards from Earth\'s point of view — "Mercury retrograde". It\'s an optical effect of orbits, traditionally read as a time to review, revise and double-check.', 'Tres o cuatro veces al año Mercurio parece moverse hacia atrás visto desde la Tierra: "Mercurio retrógrado". Es un efecto óptico de las órbitas, tradicionalmente leído como un momento para repasar y revisar.'),
  ]),
  AstroArticle('fullmoon', ArticleCategory.moon, Bi('What happens during a Full Moon?', '¿Qué pasa durante una Luna llena?'), [
    Bi('Astronomically, a Full Moon happens when the Sun and Moon are on opposite sides of Earth, so the whole face we see is lit. It happens about every 29.5 days.', 'Astronómicamente, la Luna llena ocurre cuando el Sol y la Luna están en lados opuestos de la Tierra, así que vemos toda su cara iluminada. Sucede cada 29,5 días aproximadamente.'),
    Bi('In astrology the Full Moon is a culmination: something reaches its peak, feelings run high and it\'s a traditional time to celebrate, release or let go.', 'En astrología la Luna llena es una culminación: algo llega a su punto máximo, las emociones se intensifican y es un momento tradicional para celebrar, liberar o soltar.'),
    Bi('Each Full Moon falls in a sign opposite the Sun\'s, so it\'s read as a balance between two themes — for example, a Full Moon in Aries balances self and partnership.', 'Cada Luna llena cae en el signo opuesto al del Sol, por eso se lee como un equilibrio entre dos temas: por ejemplo, una Luna llena en Aries equilibra el yo y la pareja.'),
    Bi('A reflective practice: notice what you\'ve completed since the last New Moon, and what you\'re ready to put down.', 'Una práctica para reflexionar: fíjate en lo que has completado desde la última Luna nueva y en lo que estás listo para dejar.'),
  ]),
  AstroArticle('rising', ArticleCategory.zodiac, Bi('Understanding your Rising Sign', 'Entender tu signo ascendente'), [
    Bi('Your Rising sign (Ascendant) is the sign that was coming up over the eastern horizon at the moment you were born. Because the whole zodiac rises over 24 hours, it changes about every two hours.', 'Tu ascendente es el signo que salía por el horizonte este en el momento de tu nacimiento. Como todo el zodiaco sale en 24 horas, cambia más o menos cada dos horas.'),
    Bi('That\'s why it needs an exact birth time and birthplace. Prism never guesses it — without those, it simply stays locked.', 'Por eso necesita la hora y el lugar exactos de nacimiento. Prism nunca lo adivina: sin esos datos, se queda bloqueado.'),
    Bi('Astrologers read the Rising sign as your outward style: first impressions, how you approach new situations and the "front door" of your chart. It also sets where all twelve houses begin.', 'Los astrólogos leen el ascendente como tu estilo exterior: las primeras impresiones, cómo te acercas a lo nuevo y la "puerta de entrada" de tu carta. También marca dónde empiezan las doce casas.'),
  ]),
  AstroArticle('houses', ArticleCategory.education, Bi('What are natal houses?', '¿Qué son las casas natales?'), [
    Bi('The houses divide the sky around your birthplace into twelve sections, starting from the Rising sign. Each section is linked with an area of life.', 'Las casas dividen el cielo alrededor de tu lugar de nacimiento en doce secciones, empezando por el ascendente. Cada sección se relaciona con un área de la vida.'),
    Bi('1st: self · 2nd: resources · 3rd: communication · 4th: home · 5th: creativity · 6th: routines · 7th: partnership · 8th: depth and trust · 9th: meaning · 10th: goals · 11th: friends · 12th: rest and the inner world.', '1.ª: el yo · 2.ª: recursos · 3.ª: comunicación · 4.ª: hogar · 5.ª: creatividad · 6.ª: rutinas · 7.ª: pareja · 8.ª: profundidad y confianza · 9.ª: sentido · 10.ª: metas · 11.ª: amistades · 12.ª: descanso y mundo interior.'),
    Bi('There are several ways to draw the houses. Prism uses Placidus by default (the most common in modern Western astrology) and offers Whole Sign and Equal houses. Near the poles Placidus can\'t be calculated, so Prism switches to equal division automatically.', 'Hay varias formas de trazar las casas. Prism usa Placidus por defecto (el más común en la astrología occidental moderna) y ofrece casas de signo completo e iguales. Cerca de los polos Placidus no se puede calcular, así que Prism cambia a división igual automáticamente.'),
  ]),
  AstroArticle('venus', ArticleCategory.planets, Bi('How Venus is interpreted in relationships', 'Cómo se interpreta Venus en las relaciones'), [
    Bi('Venus represents affection, attraction, values and what you find beautiful. In relationship astrology it describes how someone gives and receives care.', 'Venus representa el afecto, la atracción, los valores y lo que te parece bello. En la astrología de relaciones describe cómo alguien da y recibe cariño.'),
    Bi('Venus in earth signs often shows love through practical, reliable gestures; in water, through emotional closeness; in fire, through enthusiasm and play; in air, through conversation and shared ideas.', 'Venus en signos de tierra suele mostrar amor con gestos prácticos y fiables; en agua, con cercanía emocional; en fuego, con entusiasmo y juego; en aire, con conversación e ideas compartidas.'),
    Bi('When comparing charts, astrologers look at how one person\'s Venus meets the other\'s Sun, Moon and Mars. Prism shows this in Compatibility — as words, never a percentage.', 'Al comparar cartas, los astrólogos miran cómo la Venus de una persona se encuentra con el Sol, la Luna y Marte de la otra. Prism lo muestra en Compatibilidad, con palabras, nunca con porcentajes.'),
  ]),
  AstroArticle('newmoon', ArticleCategory.moon, Bi('New Moons and setting intentions', 'Lunas nuevas e intenciones'), [
    Bi('At the New Moon, the Moon sits between Earth and Sun and its lit side faces away from us. It\'s the start of the lunar cycle.', 'En la Luna nueva, la Luna está entre la Tierra y el Sol y su lado iluminado mira hacia fuera. Es el comienzo del ciclo lunar.'),
    Bi('Traditionally it\'s a time for beginnings: naming what you\'d like to grow over the next month. Some people write a short list of intentions and revisit it at the Full Moon.', 'Tradicionalmente es un momento para empezar: nombrar lo que te gustaría hacer crecer durante el mes. Algunas personas escriben una lista breve de intenciones y la revisan en la Luna llena.'),
    Bi('When a New Moon happens close to the Moon\'s nodes, the Moon can pass in front of the Sun: a solar eclipse. Astrologers read eclipses as stronger turning points.', 'Cuando una Luna nueva ocurre cerca de los nodos lunares, la Luna puede pasar por delante del Sol: un eclipse solar. Los astrólogos leen los eclipses como puntos de inflexión más fuertes.'),
  ]),
  AstroArticle('solar', ArticleCategory.solar, Bi('The Sun\'s yearly journey', 'El viaje anual del Sol'), [
    Bi('From Earth, the Sun appears to travel through all twelve zodiac signs once a year. The "Sun sign" is simply the sign the Sun was in on your birthday.', 'Desde la Tierra, el Sol parece recorrer los doce signos una vez al año. El "signo solar" es simplemente el signo en el que estaba el Sol el día de tu cumpleaños.'),
    Bi('Sign changes don\'t happen on the same date every year — they can shift by a day. If you were born near a change ("on the cusp"), Prism uses your birth year and time to find the right sign instead of guessing.', 'Los cambios de signo no ocurren el mismo día cada año: pueden variar un día. Si naciste cerca de un cambio ("en la cúspide"), Prism usa tu año y hora de nacimiento para encontrar el signo correcto en lugar de adivinar.'),
    Bi('The Sun entering Aries (around March 20) marks the start of the astrological year, at the March equinox.', 'La entrada del Sol en Aries (hacia el 20 de marzo) marca el inicio del año astrológico, en el equinoccio de marzo.'),
  ]),
  AstroArticle('aspects', ArticleCategory.education, Bi('Aspects: how planets talk to each other', 'Aspectos: cómo dialogan los planetas'), [
    Bi('An aspect is an angle between two points in a chart. The major ones are the conjunction (0°), sextile (60°), square (90°), trine (120°) and opposition (180°).', 'Un aspecto es un ángulo entre dos puntos de una carta. Los principales son la conjunción (0°), el sextil (60°), la cuadratura (90°), el trígono (120°) y la oposición (180°).'),
    Bi('Trines and sextiles are traditionally read as easy and supportive, squares and oppositions as tension that pushes for growth, and conjunctions as a blending of energies.', 'Los trígonos y sextiles se leen tradicionalmente como fáciles y de apoyo; las cuadraturas y oposiciones, como tensión que empuja a crecer; y las conjunciones, como una mezcla de energías.'),
    Bi('The "orb" is how far from exact an angle is. Tighter orbs are read as stronger. Prism lists each aspect with its orb.', 'El "orbe" es cuánto se aleja un ángulo del exacto. Los orbes más estrechos se leen como más fuertes. Prism muestra cada aspecto con su orbe.'),
  ]),
  AstroArticle('tarot', ArticleCategory.tarot, Bi('Tarot as a reflection tool', 'El tarot como herramienta de reflexión'), [
    Bi('A tarot deck has 78 cards: 22 Major Arcana (big life themes like The Fool or The Star) and 56 Minor Arcana in four suits — Wands, Cups, Swords and Pentacles.', 'Una baraja de tarot tiene 78 cartas: 22 Arcanos Mayores (grandes temas como El Loco o La Estrella) y 56 Arcanos Menores en cuatro palos: Bastos, Copas, Espadas y Oros.'),
    Bi('Many people use tarot not to predict the future but as prompts: a card offers an image and a theme, and you notice what it brings up for you.', 'Mucha gente usa el tarot no para predecir el futuro sino como estímulo: una carta ofrece una imagen y un tema, y tú observas lo que te despierta.'),
    Bi('Prism\'s daily card is the same all day and different for each alter. Readings you save stay with the alter who drew them.', 'La carta del día de Prism es la misma todo el día y distinta para cada alter. Las tiradas que guardas se quedan con el alter que las hizo.'),
  ]),
  AstroArticle('journal', ArticleCategory.reflection, Bi('Using astrology for self-reflection', 'Usar la astrología para reflexionar'), [
    Bi('Astrology works best as a mirror, not a map. A reading suggests a theme; you decide whether it fits.', 'La astrología funciona mejor como espejo que como mapa. Una lectura sugiere un tema; tú decides si encaja.'),
    Bi('Prism\'s Astrology Journal lets each alter compare the day\'s reading with how the day actually felt. Over time you can see patterns — and also how often the sky and the day had nothing to do with each other.', 'El Diario astrológico de Prism permite a cada alter comparar la lectura del día con cómo se sintió realmente. Con el tiempo puedes ver patrones, y también lo a menudo que el cielo y el día no tuvieron nada que ver.'),
    Bi('That honesty is the point: noticing yourself is the real practice. The stars are just a prompt.', 'Esa sinceridad es la clave: observarte es la verdadera práctica. Las estrellas son solo un estímulo.'),
  ]),
];
