/// Searchable symptom vocabulary for Health check-ins.
///
/// Terms describe what someone notices; nothing here implies a diagnosis.
/// Ids are stored with each logged symptom together with the label shown at
/// the time, so renaming a term never changes what an old entry said.
library;

enum SymptomCategory { general, breathing, head, digestive, skin, muscles, urinary, sensation, other }

String symptomCategoryLabel(SymptomCategory c, bool es) => switch (c) {
  SymptomCategory.general => es ? 'General' : 'General',
  SymptomCategory.breathing => es ? 'Nariz, garganta y respiración' : 'Nose, throat & breathing',
  SymptomCategory.head => es ? 'Cabeza, ojos, oídos y boca' : 'Head, eyes, ears & mouth',
  SymptomCategory.digestive => es ? 'Digestivo' : 'Digestive',
  SymptomCategory.skin => es ? 'Piel' : 'Skin',
  SymptomCategory.muscles => es ? 'Músculos y articulaciones' : 'Muscles & joints',
  SymptomCategory.urinary => es ? 'Urinario' : 'Urinary',
  SymptomCategory.sensation => es ? 'Sensación y coordinación' : 'Sensation & coordination',
  SymptomCategory.other => es ? 'Otros' : 'Other',
};

class SymptomTerm {
  const SymptomTerm(this.id, this.category, this.en, this.es, [this.synonyms = const []]);
  final String id;
  final SymptomCategory category;
  final String en;
  final String es;
  final List<String> synonyms;
  String label(bool es) => es ? this.es : en;
}

const _g = SymptomCategory.general;
const _b = SymptomCategory.breathing;
const _h = SymptomCategory.head;
const _d = SymptomCategory.digestive;
const _s = SymptomCategory.skin;
const _m = SymptomCategory.muscles;
const _u = SymptomCategory.urinary;
const _n = SymptomCategory.sensation;

const symptomCatalog = <SymptomTerm>[
  SymptomTerm('fatigue', _g, 'Fatigue', 'Cansancio', ['tired', 'exhausted', 'low energy', 'worn out']),
  SymptomTerm('feverish', _g, 'Feverishness', 'Sensación de fiebre', ['fever', 'hot', 'temperature']),
  SymptomTerm('chills', _g, 'Chills', 'Escalofríos', ['shivering', 'cold']),
  SymptomTerm('sweating', _g, 'Sweating', 'Sudoración', ['sweats', 'night sweats', 'clammy']),
  SymptomTerm('weakness', _g, 'Weakness', 'Debilidad', ['weak', 'no strength']),
  SymptomTerm('unwell', _g, 'Feeling unwell', 'Malestar general', ['sick', 'ill', 'off', 'under the weather']),
  SymptomTerm('congestion', _b, 'Congestion', 'Congestión', ['stuffy', 'blocked nose', 'stuffed up']),
  SymptomTerm('runny_nose', _b, 'Runny nose', 'Moqueo', ['dripping', 'sniffles']),
  SymptomTerm('sore_throat', _b, 'Sore throat', 'Dolor de garganta', ['scratchy throat', 'throat pain']),
  SymptomTerm('hoarseness', _b, 'Hoarseness', 'Ronquera', ['lost voice', 'raspy']),
  SymptomTerm('cough', _b, 'Cough', 'Tos', ['coughing', 'dry cough', 'wet cough']),
  SymptomTerm('short_breath', _b, 'Shortness of breath', 'Falta de aire', ['breathless', 'winded', 'hard to breathe']),
  SymptomTerm('sneezing', _b, 'Sneezing', 'Estornudos', ['sneeze']),
  SymptomTerm('headache', _h, 'Headache', 'Dolor de cabeza', ['migraine', 'head pain']),
  SymptomTerm('head_pressure', _h, 'Head pressure', 'Presión en la cabeza', ['pressure']),
  SymptomTerm('dizziness', _h, 'Dizziness', 'Mareo', ['lightheaded', 'vertigo', 'spinning', 'woozy']),
  SymptomTerm('light_sensitivity', _h, 'Light sensitivity', 'Sensibilidad a la luz', ['photophobia', 'bright light']),
  SymptomTerm('ringing', _h, 'Ringing in ears', 'Zumbido de oídos', ['tinnitus', 'buzzing']),
  SymptomTerm('ear_fullness', _h, 'Ear fullness', 'Oídos tapados', ['blocked ears', 'plugged ears']),
  SymptomTerm('dry_mouth', _h, 'Dry mouth', 'Boca seca', ['thirsty', 'cotton mouth']),
  SymptomTerm('taste_smell', _h, 'Altered taste or smell', 'Gusto u olfato alterado', ['loss of taste', 'loss of smell', 'metallic taste']),
  SymptomTerm('eye_irritation', _h, 'Eye irritation', 'Irritación ocular', ['itchy eyes', 'red eyes', 'watery eyes']),
  SymptomTerm('nausea', _d, 'Nausea', 'Náuseas', ['queasy', 'sick to stomach']),
  SymptomTerm('vomiting', _d, 'Vomiting', 'Vómitos', ['throwing up', 'threw up']),
  SymptomTerm('reflux', _d, 'Reflux', 'Reflujo', ['heartburn', 'acid', 'indigestion']),
  SymptomTerm('cramping_gi', _d, 'Cramping', 'Retortijones', ['stomach cramps', 'stomach ache']),
  SymptomTerm('bloating', _d, 'Bloating', 'Hinchazón', ['gas', 'bloated']),
  SymptomTerm('appetite', _d, 'Appetite changes', 'Cambios en el apetito', ['no appetite', 'hungry', 'not hungry']),
  SymptomTerm('constipation', _d, 'Constipation', 'Estreñimiento', ['bunged up']),
  SymptomTerm('diarrhea', _d, 'Diarrhea', 'Diarrea', ['diarrhoea', 'loose stool', 'upset stomach']),
  SymptomTerm('itching', _s, 'Itching', 'Picazón', ['itchy', 'itch']),
  SymptomTerm('burning_skin', _s, 'Burning', 'Ardor', ['stinging skin']),
  SymptomTerm('skin_tender', _s, 'Tenderness', 'Sensibilidad', ['sore skin']),
  SymptomTerm('redness', _s, 'Redness', 'Enrojecimiento', ['red', 'flushed']),
  SymptomTerm('dryness', _s, 'Dryness', 'Sequedad', ['dry skin', 'flaky']),
  SymptomTerm('rash', _s, 'Rash', 'Sarpullido', ['hives', 'bumps', 'spots']),
  SymptomTerm('swelling', _s, 'Swelling', 'Hinchazón', ['swollen', 'puffy']),
  SymptomTerm('aching', _m, 'Aching', 'Dolor sordo', ['body aches', 'achy', 'muscle ache']),
  SymptomTerm('stiffness', _m, 'Stiffness', 'Rigidez', ['stiff']),
  SymptomTerm('soreness', _m, 'Soreness', 'Agujetas / dolor', ['sore']),
  SymptomTerm('cramping_muscle', _m, 'Muscle cramping', 'Calambres musculares', ['charley horse', 'spasm']),
  SymptomTerm('muscle_weakness', _m, 'Muscle weakness', 'Debilidad muscular', ['weak muscles']),
  SymptomTerm('restricted', _m, 'Restricted movement', 'Movimiento limitado', ['cant move', 'limited range']),
  SymptomTerm('joint_pain', _m, 'Joint pain', 'Dolor articular', ['joints']),
  SymptomTerm('urgency', _u, 'Urgency', 'Urgencia', ['need to go']),
  SymptomTerm('frequency', _u, 'Frequency', 'Frecuencia', ['going often', 'peeing a lot']),
  SymptomTerm('urinary_discomfort', _u, 'Discomfort', 'Molestia al orinar', ['burning when peeing', 'stinging']),
  SymptomTerm('urinary_other', _u, 'Other observation', 'Otra observación', []),
  SymptomTerm('tingling', _n, 'Tingling', 'Hormigueo', ['pins and needles']),
  SymptomTerm('numbness', _n, 'Numbness', 'Entumecimiento', ['numb', 'no feeling']),
  SymptomTerm('shakiness', _n, 'Shakiness', 'Temblores', ['shaky', 'tremor', 'trembling']),
  SymptomTerm('unsteadiness', _n, 'Unsteadiness', 'Inestabilidad', ['unsteady', 'off balance', 'wobbly', 'clumsy']),
  SymptomTerm('pain_general', SymptomCategory.other, 'Pain', 'Dolor', ['hurts', 'ache', 'painful']),
];

final Map<String, SymptomTerm> symptomById = {for (final t in symptomCatalog) t.id: t};

/// Terms matching [query] by label or synonym, best matches first.
List<SymptomTerm> searchSymptoms(String query, bool es, {Iterable<SymptomTerm> custom = const []}) {
  final q = query.trim().toLowerCase();
  final all = [...custom, ...symptomCatalog];
  if (q.isEmpty) return all;
  int score(SymptomTerm t) {
    final l = t.label(es).toLowerCase();
    if (l == q) return 0;
    if (l.startsWith(q)) return 1;
    if (l.contains(q)) return 2;
    if (t.synonyms.any((s) => s.startsWith(q))) return 3;
    if (t.synonyms.any((s) => s.contains(q)) || (es ? t.en : t.es).toLowerCase().contains(q)) return 4;
    return 99;
  }

  final hits = [for (final t in all) if (score(t) < 99) t]..sort((a, b) => score(a).compareTo(score(b)));
  return hits;
}
