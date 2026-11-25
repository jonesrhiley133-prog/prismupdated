/// Prism's offline line library: what Prism says, in each voice.
///
/// Placeholders: {name} (who's fronting or the companion), {game}, {score}.
library;

enum VoiceStyle {
  natural('Natural', 'Clear and friendly, like a thoughtful friend.'),
  cozy('Cozy', 'Warm blankets and tea energy.'),
  sarcastic('Sarcastic', 'Affectionately snarky. Never mean.'),
  deadpan('Deadpan', 'Flat delivery. Secretly supportive.'),
  chaotic('Chaotic', 'Gremlin energy, lots of capital letters.'),
  grumpy('Grumpy', 'Grumbles, then helps anyway.'),
  cheerful('Cheerful', 'Sunny, upbeat and encouraging.'),
  serious('Serious', 'Calm, direct and steady.'),
  professional('Professional', 'Polished and to the point.'),
  poetic('Poetic', 'Gentle images and soft rhythm.'),
  gamer('Gamer', 'GG, XP and achievement unlocked.'),
  internet('Casual Internet', 'lowercase, vibes, no caps.'),
  elegant('Elegant', 'Graceful and a little formal.');

  const VoiceStyle(this.label, this.blurb);
  final String label;
  final String blurb;

  /// Styles that are always appropriate in sensitive moments.
  bool get gentle => const {
    VoiceStyle.natural,
    VoiceStyle.cozy,
    VoiceStyle.serious,
    VoiceStyle.professional,
    VoiceStyle.poetic,
    VoiceStyle.elegant,
  }.contains(this);
}

enum VoiceContext {
  greeting('Greeting', 'Opening Prism or Home'),
  encourage('Encouragement', 'Gentle nudges and support'),
  celebrate('Celebration', 'Milestones and good news'),
  gameFinish('Game finished', 'After any game'),
  gameWin('Game won', 'Someone came out on top'),
  gameTie('Game tied', 'Everyone matched'),
  insightGood('Insights: good day', 'Mood was high'),
  insightSteady('Insights: steady day', 'Mood was okay'),
  insightHard(
    'Insights: hard day',
    'Mood was low (sensitive)',
    sensitive: true,
  ),
  insightEmpty('Insights: nothing logged', 'No check-ins yet'),
  astroIntro('Astro', 'Introducing today\'s sky'),
  companionHello('Companion hello', 'Visiting a companion'),
  emptyState('Empty page', 'Nothing here yet'),
  farewell('Goodbye', 'Signing off or leaving');

  const VoiceContext(this.label, this.hint, {this.sensitive = false});
  final String label;
  final String hint;

  /// Sensitive contexts never use teasing or chaotic styles.
  final bool sensitive;
}

typedef _L = Map<VoiceStyle, List<String>>;

const voiceLibrary = <VoiceContext, _L>{
  VoiceContext.greeting: {
    VoiceStyle.natural: [
      'Hi {name}. Good to see you.',
      'Welcome back, {name}.',
      'Hey {name} — what are we doing today?',
    ],
    VoiceStyle.cozy: [
      'Welcome home, {name}. Kettle\'s on.',
      'Hi {name} — come get comfy.',
      'There you are, {name}. Blanket\'s warm.',
    ],
    VoiceStyle.sarcastic: [
      'Oh look, it\'s {name}. Truly the highlight of my day. (It is.)',
      '{name}! I definitely wasn\'t waiting by the window.',
      'Back so soon, {name}? I\'m flattered.',
    ],
    VoiceStyle.deadpan: [
      'Hello, {name}. I am thrilled. This is my thrilled voice.',
      '{name} has arrived. Noted.',
      'Welcome back. Everything is exactly where you left it.',
    ],
    VoiceStyle.chaotic: [
      '{name}!!! YOU\'RE HERE!!! okay okay act normal',
      'AAAA HI {name} i rearranged nothing (lie)',
      'the legend {name} returns!!! confetti!!!',
    ],
    VoiceStyle.grumpy: [
      'Oh. It\'s you, {name}. ...Fine. Hi.',
      'Hmph. Welcome back, {name}. I guess.',
      'You again, {name}. Sit down, I saved you a spot.',
    ],
    VoiceStyle.cheerful: [
      'Hi {name}! So happy you\'re here!',
      'Good to see you, {name}! Let\'s have a lovely day!',
      'Yay, {name} is back! ☀️',
    ],
    VoiceStyle.serious: [
      'Welcome back, {name}.',
      'Hello, {name}. Everything is ready.',
      'Good to have you here, {name}.',
    ],
    VoiceStyle.professional: [
      'Welcome back, {name}. Here\'s your overview.',
      'Good to see you, {name}. Everything is up to date.',
      'Hello, {name}. Ready when you are.',
    ],
    VoiceStyle.poetic: [
      'Welcome back, {name} — the day unfolds like a letter.',
      'Hello, {name}. The light found its way to you.',
      '{name}, the quiet was waiting for your footsteps.',
    ],
    VoiceStyle.gamer: [
      'Player {name} has joined the game.',
      'Welcome back, {name}. Save file loaded.',
      '{name} respawned. Daily quests available.',
    ],
    VoiceStyle.internet: [
      'hiii {name} :)',
      'oh hey {name}, vibes are good today',
      '{name} is here. we love to see it',
    ],
    VoiceStyle.elegant: [
      'Good to see you, {name}. Do come in.',
      'Welcome back, {name}. Everything is as you left it.',
      'A pleasure, as always, {name}.',
    ],
  },
  VoiceContext.encourage: {
    VoiceStyle.natural: [
      'You\'re doing better than you think.',
      'One small step counts.',
      'Take it at your own pace.',
    ],
    VoiceStyle.cozy: [
      'Slow and gentle is still moving forward.',
      'You\'ve got this — and a snack, hopefully.',
      'Be soft with yourself today.',
    ],
    VoiceStyle.sarcastic: [
      'Look at you, being capable. Disgusting. Keep going.',
      'Wow, progress. Who allowed that?',
      'You\'re weirdly good at this. Carry on.',
    ],
    VoiceStyle.deadpan: [
      'You are doing a thing. The thing is going fine.',
      'Progress detected. Emotion: proud. Probably.',
      'Keep going. That was the whole message.',
    ],
    VoiceStyle.chaotic: [
      'GO GO GO you\'re UNSTOPPABLE (please hydrate)',
      'tiny step?? HUGE WIN. i\'m screaming',
      'you\'re doing AMAZING sweetie!!!',
    ],
    VoiceStyle.grumpy: [
      'Ugh, fine, you\'re doing well. Don\'t let it go to your head.',
      'Keep at it. I\'m not cheering. (I\'m cheering.)',
      'Stop doubting yourself. It\'s annoying. You\'re good.',
    ],
    VoiceStyle.cheerful: [
      'You\'re doing wonderfully!',
      'Every little bit counts — go you!',
      'Keep shining! 🌟',
    ],
    VoiceStyle.serious: [
      'Steady progress matters.',
      'Keep going. You are capable.',
      'Small, consistent steps build real change.',
    ],
    VoiceStyle.professional: [
      'Good progress. Keep the momentum.',
      'You\'re on track.',
      'Consistent effort pays off.',
    ],
    VoiceStyle.poetic: [
      'Even the river moves one stone at a time.',
      'Growth is quiet; trust it.',
      'You are a lantern still being lit.',
    ],
    VoiceStyle.gamer: [
      '+10 XP. Keep grinding.',
      'Combo building — don\'t drop it now.',
      'Side quest progress: excellent.',
    ],
    VoiceStyle.internet: [
      'ur doing great tbh',
      'small steps still count fr',
      'proud of u ngl',
    ],
    VoiceStyle.elegant: [
      'You\'re managing beautifully.',
      'One graceful step, then another.',
      'Quietly impressive, as ever.',
    ],
  },
  VoiceContext.celebrate: {
    VoiceStyle.natural: [
      'That\'s worth celebrating!',
      'Nice — well done!',
      'You made it happen.',
    ],
    VoiceStyle.cozy: [
      'A little celebration is in order — cake, maybe?',
      'Look at that. Warm fuzzy feelings all round.',
      'So proud of you. Cocoa to celebrate?',
    ],
    VoiceStyle.sarcastic: [
      'Oh no, an accomplishment. How will we cope.',
      'Fine, that was impressive. Mark the calendar.',
      'Show-off. (Congrats.)',
    ],
    VoiceStyle.deadpan: [
      'Achievement acquired. Party mode: on. 🎉',
      'This is me celebrating. Very loudly. Inside.',
      'Well done. Confetti has been mentally thrown.',
    ],
    VoiceStyle.chaotic: [
      'WE DID IT!!! THROW EVERYTHING IN THE AIR',
      'AAAAAA LET\'S GOOOO 🎉🎉🎉',
      'party in the group chat (it\'s just me) (i\'m so happy)',
    ],
    VoiceStyle.grumpy: [
      'Hmph. Well done. Don\'t make it weird.',
      'Okay, that was good. Happy now? ...I am.',
      'Congratulations, I suppose. Genuinely.',
    ],
    VoiceStyle.cheerful: [
      'Hooray! That\'s amazing! 🎉',
      'Wonderful! Celebrate yourself today!',
      'Yay! You did it!',
    ],
    VoiceStyle.serious: [
      'Well done. That took real effort.',
      'A meaningful milestone.',
      'Congratulations. You earned this.',
    ],
    VoiceStyle.professional: [
      'Milestone reached. Excellent work.',
      'Congratulations on the achievement.',
      'Great result.',
    ],
    VoiceStyle.poetic: [
      'A small star rises in your sky.',
      'Today wears a ribbon of gold.',
      'The moment blooms — keep it close.',
    ],
    VoiceStyle.gamer: [
      'Achievement unlocked! 🏆',
      'Level up! New perks available.',
      'GG — that was a clutch play.',
    ],
    VoiceStyle.internet: [
      'omg congrats!!',
      'we won. we actually won.',
      'this is so slay',
    ],
    VoiceStyle.elegant: [
      'Splendid. Truly well done.',
      'A lovely accomplishment.',
      'Bravo — beautifully done.',
    ],
  },
  VoiceContext.gameFinish: {
    VoiceStyle.natural: ['Nicely done!', 'Good game!', 'That was fun.'],
    VoiceStyle.cozy: [
      'Good game — time for a snack?',
      'That was lovely. Again sometime?',
      'Cozy game, happy hearts.',
    ],
    VoiceStyle.sarcastic: [
      'Wow, you finished. Riveting stuff.',
      'Game over. You survived. Barely.',
      'Not bad. For a human.',
    ],
    VoiceStyle.deadpan: [
      'Game complete. Fun was had. Allegedly.',
      'The game has ended. As games do.',
      'Finished. I clapped. You didn\'t see it.',
    ],
    VoiceStyle.chaotic: [
      'GAME OVER!!! (in a good way) (again?)',
      'that was UNHINGED i loved it',
      'WOOO GG GG GG',
    ],
    VoiceStyle.grumpy: [
      'Done? Good. ...One more?',
      'Fine game. I\'ve seen worse.',
      'Hmph. That was actually fun.',
    ],
    VoiceStyle.cheerful: [
      'Great game! 🎉',
      'That was so fun!',
      'Well played, everyone!',
    ],
    VoiceStyle.serious: [
      'Game complete.',
      'Well played.',
      'That round is finished.',
    ],
    VoiceStyle.professional: [
      'Round complete. Results below.',
      'Game finished. Well played.',
      'Here are your results.',
    ],
    VoiceStyle.poetic: [
      'The last move settles like snow.',
      'A game ends, a memory begins.',
      'Well played — the board rests.',
    ],
    VoiceStyle.gamer: [
      'GG! 🎮',
      'Match over — GG WP.',
      'Run complete. Loot below.',
    ],
    VoiceStyle.internet: ['gg', 'that was fun ngl', 'ok that slapped'],
    VoiceStyle.elegant: [
      'A splendid game.',
      'Beautifully played.',
      'Well done — a fine match.',
    ],
  },
  VoiceContext.gameWin: {
    VoiceStyle.natural: [
      '{name} takes it!',
      'Nice one, {name}!',
      '{name} wins this round.',
    ],
    VoiceStyle.cozy: [
      '{name} wins — a gold star and a hug.',
      'Well done, {name}! Treats all round anyway.',
    ],
    VoiceStyle.sarcastic: [
      '{name} wins. Try to be humble about it. (Impossible.)',
      'Oh great, now {name} will be unbearable.',
    ],
    VoiceStyle.deadpan: [
      '{name} won. Nobody is surprised. Except everyone.',
      'Winner: {name}. Celebration: pending.',
    ],
    VoiceStyle.chaotic: [
      '{name} WINS!!! CHAMPION OF THE UNIVERSE!!!',
      'ALL HAIL {name} 👑👑👑',
    ],
    VoiceStyle.grumpy: [
      '{name} won. Fine. Rematch.',
      'Hmph. {name} wins. Lucky.',
    ],
    VoiceStyle.cheerful: [
      'Congratulations, {name}! 🏆',
      'Woohoo, {name} wins!',
    ],
    VoiceStyle.serious: ['{name} wins.', 'Victory to {name}.'],
    VoiceStyle.professional: ['Top score: {name}.', '{name} finished first.'],
    VoiceStyle.poetic: [
      'The laurel settles on {name}.',
      '{name} catches the falling star.',
    ],
    VoiceStyle.gamer: ['{name} — VICTORY ROYALE.', 'MVP: {name}. 🏆'],
    VoiceStyle.internet: ['{name} won lol', '{name} said bye 👋 and won'],
    VoiceStyle.elegant: [
      'Victory belongs to {name}.',
      'Well played, {name}. A fine win.',
    ],
  },
  VoiceContext.gameTie: {
    VoiceStyle.natural: ['It\'s a tie!', 'Evenly matched!'],
    VoiceStyle.cozy: [
      'A tie — everybody wins a cuddle.',
      'Perfectly matched, like socks.',
    ],
    VoiceStyle.sarcastic: [
      'A tie. How diplomatic of you all.',
      'Nobody won. Great teamwork.',
    ],
    VoiceStyle.deadpan: ['Tie. Balance restored.', 'Equal scores. Thrilling.'],
    VoiceStyle.chaotic: [
      'A TIE?!?! THE CHAOS!!!',
      'tie!!! SUDDEN DEATH?? (no)',
    ],
    VoiceStyle.grumpy: [
      'A tie. Nobody gets to gloat. Good.',
      'Hmph. Tie. Again.',
    ],
    VoiceStyle.cheerful: [
      'A tie — you\'re all winners!',
      'So close — it\'s a tie!',
    ],
    VoiceStyle.serious: ['The scores are equal.', 'A draw.'],
    VoiceStyle.professional: ['Result: tie.', 'Scores level.'],
    VoiceStyle.poetic: [
      'Two tides meet in the middle.',
      'Balanced like a quiet scale.',
    ],
    VoiceStyle.gamer: ['DRAW. Rematch?', 'Tie game — overtime?'],
    VoiceStyle.internet: ['tie?? love that for us', 'its a draw lmao'],
    VoiceStyle.elegant: ['A gracious draw.', 'Perfectly matched.'],
  },
  VoiceContext.insightGood: {
    VoiceStyle.natural: [
      'Today looked good. Worth noticing what helped.',
      'A brighter day — nice.',
    ],
    VoiceStyle.cozy: [
      'A warm, bright day. Hold onto it.',
      'Today felt good — tuck that feeling away.',
    ],
    VoiceStyle.sarcastic: [
      'A good day? Suspicious. Enjoy it anyway.',
      'Things went well. I\'m as shocked as you.',
    ],
    VoiceStyle.deadpan: [
      'Mood: high. Recommendation: more of that.',
      'Good day logged. Very good. Yes.',
    ],
    VoiceStyle.chaotic: [
      'GOOD DAY ALERT!!! bottle it!!!',
      'the vibes were IMMACULATE today',
    ],
    VoiceStyle.grumpy: [
      'Fine, today was good. Note what worked.',
      'Hmph. Good day. Don\'t jinx it.',
    ],
    VoiceStyle.cheerful: [
      'What a lovely day! ☀️',
      'Today was bright — wonderful!',
    ],
    VoiceStyle.serious: [
      'Mood was high today. Note what supported it.',
      'A strong day.',
    ],
    VoiceStyle.professional: [
      'Positive day overall.',
      'Mood above average today.',
    ],
    VoiceStyle.poetic: [
      'Today held the sun in both hands.',
      'A day with its windows open.',
    ],
    VoiceStyle.gamer: ['Buff active: good mood. Nice run.', 'High score day!'],
    VoiceStyle.internet: ['today was a good one fr', 'good vibes only today'],
    VoiceStyle.elegant: [
      'A lovely day, by all accounts.',
      'Today was rather wonderful.',
    ],
  },
  VoiceContext.insightSteady: {
    VoiceStyle.natural: [
      'A steady day. That counts.',
      'Middle-of-the-road today — that\'s okay.',
    ],
    VoiceStyle.cozy: [
      'A calm, ordinary day. Those are good too.',
      'Steady as a teapot.',
    ],
    VoiceStyle.sarcastic: [
      'A perfectly fine day. Riveting.',
      'Medium day. Very medium. Mediumest.',
    ],
    VoiceStyle.deadpan: ['Mood: okay. Day: occurred.', 'Steady. Like a table.'],
    VoiceStyle.chaotic: [
      'a NORMAL day?? wild',
      'mid day. mid vibes. still here!!',
    ],
    VoiceStyle.grumpy: [
      'Fine day. Nothing to complain about. Unfortunately.',
      'Steady. Good. Moving on.',
    ],
    VoiceStyle.cheerful: [
      'A nice steady day!',
      'Calm and okay — that\'s great!',
    ],
    VoiceStyle.serious: ['A steady day.', 'Mood was stable.'],
    VoiceStyle.professional: ['Mood stable today.', 'An average day.'],
    VoiceStyle.poetic: [
      'A day like still water.',
      'Grey skies, gentle and even.',
    ],
    VoiceStyle.gamer: ['Neutral stats today. Holding position.', 'Steady HP.'],
    VoiceStyle.internet: ['mid day but thats ok', 'chill day ngl'],
    VoiceStyle.elegant: ['A quietly steady day.', 'Even and composed.'],
  },
  VoiceContext.insightHard: {
    VoiceStyle.natural: [
      'Today was hard. Be gentle with yourself.',
      'A heavy day. You don\'t have to fix it right now.',
    ],
    VoiceStyle.cozy: [
      'A hard day. Wrap up warm and rest if you can.',
      'Today was heavy. Something soft and warm might help.',
    ],
    VoiceStyle.serious: [
      'Today was difficult. Rest and support matter.',
      'A hard day. Take care of the basics.',
    ],
    VoiceStyle.professional: [
      'Mood was low today. Consider rest or reaching out.',
      'A difficult day. Small comforts can help.',
    ],
    VoiceStyle.poetic: [
      'Some days are winter. Spring still knows your name.',
      'A heavy sky today. Let it pass slowly.',
    ],
    VoiceStyle.elegant: [
      'A difficult day. Please be kind to yourself.',
      'Today asked a lot of you. Rest is allowed.',
    ],
  },
  VoiceContext.insightEmpty: {
    VoiceStyle.natural: [
      'Nothing logged yet today. Want to check in?',
      'No check-ins yet — whenever you\'re ready.',
    ],
    VoiceStyle.cozy: [
      'No check-ins yet. No rush — pour a drink first.',
      'Quiet so far. Check in when it feels right.',
    ],
    VoiceStyle.sarcastic: [
      'Nothing logged. Mysterious. Intriguing.',
      'An empty page. Very minimalist.',
    ],
    VoiceStyle.deadpan: [
      'Data: none. Mood: unknown. Suspense: high.',
      'Nothing here yet.',
    ],
    VoiceStyle.chaotic: [
      'the void stares back. log something!!!',
      'NO DATA?? feed me check-ins',
    ],
    VoiceStyle.grumpy: [
      'Nothing logged. I\'m not nagging. (Log something.)',
      'Empty. Hmph.',
    ],
    VoiceStyle.cheerful: [
      'No check-ins yet — want to add one?',
      'A fresh, empty day!',
    ],
    VoiceStyle.serious: ['No check-ins recorded.', 'Nothing logged yet.'],
    VoiceStyle.professional: ['No entries for this day.', 'No data yet.'],
    VoiceStyle.poetic: [
      'A blank page, waiting for ink.',
      'The day is still unwritten.',
    ],
    VoiceStyle.gamer: ['No data. Start a check-in quest?', 'Quest log empty.'],
    VoiceStyle.internet: [
      'nothing here yet lol',
      'no check-ins yet, no pressure',
    ],
    VoiceStyle.elegant: ['Nothing recorded as yet.', 'A quiet day, so far.'],
  },
  VoiceContext.astroIntro: {
    VoiceStyle.natural: [
      'Here\'s what the sky suggests today — take what fits.',
      'Today\'s sky, for reflection.',
    ],
    VoiceStyle.cozy: [
      'Grab a blanket — the stars have notes for you.',
      'A cosy look at today\'s sky.',
    ],
    VoiceStyle.sarcastic: [
      'The planets have opinions again. Shocking.',
      'Mercury says hi. Probably retrograde about it.',
    ],
    VoiceStyle.deadpan: [
      'The sky is doing things. Here they are.',
      'Planets: moving. Details below.',
    ],
    VoiceStyle.chaotic: [
      'THE STARS HAVE SPOKEN (they said stuff)',
      'cosmic gossip incoming!!!',
    ],
    VoiceStyle.grumpy: [
      'Fine. Here\'s your horoscope. Don\'t blame me.',
      'The stars want a word. Ugh.',
    ],
    VoiceStyle.cheerful: [
      'Let\'s see what the stars have in store! ✨',
      'Today\'s sky is full of possibility!',
    ],
    VoiceStyle.serious: [
      'Today\'s astrological themes, for reflection.',
      'An overview of today\'s sky.',
    ],
    VoiceStyle.professional: [
      'Daily astrology summary.',
      'Today\'s transits at a glance.',
    ],
    VoiceStyle.poetic: [
      'The sky turns its pages for you.',
      'Stars write in slow handwriting tonight.',
    ],
    VoiceStyle.gamer: [
      'Daily buffs from the cosmos:',
      'Celestial patch notes:',
    ],
    VoiceStyle.internet: ['the planets said this today:', 'astro check ✨'],
    VoiceStyle.elegant: [
      'Today\'s sky, for your consideration.',
      'What the heavens suggest today.',
    ],
  },
  VoiceContext.companionHello: {
    VoiceStyle.natural: [
      '{name} is happy to see you.',
      '{name} perks up when you arrive.',
    ],
    VoiceStyle.cozy: [
      '{name} scoots over to make room for you.',
      '{name} was keeping your spot warm.',
    ],
    VoiceStyle.sarcastic: [
      '{name} pretends not to care. They care a lot.',
      '{name}: "Oh, it\'s you. Hi. (yay)"',
    ],
    VoiceStyle.deadpan: [
      '{name} acknowledges your presence. Fondly.',
      '{name} is here. You are here. Good.',
    ],
    VoiceStyle.chaotic: [
      '{name} IS SO EXCITED THEY KNOCKED SOMETHING OVER',
      '{name} zooms around in circles!!!',
    ],
    VoiceStyle.grumpy: [
      '{name} grumbles, then sits on your foot.',
      '{name} huffs. That means hello.',
    ],
    VoiceStyle.cheerful: [
      '{name} bounces over to say hi!',
      '{name} is overjoyed to see you!',
    ],
    VoiceStyle.serious: [
      '{name} greets you calmly.',
      '{name} is glad you\'re here.',
    ],
    VoiceStyle.professional: [
      '{name} is ready to spend time with you.',
      '{name} says hello.',
    ],
    VoiceStyle.poetic: [
      '{name} lifts their head like a flower to the sun.',
      '{name} hums a small welcome.',
    ],
    VoiceStyle.gamer: [
      '{name} joined your party.',
      'Companion {name} ready. Bond +1.',
    ],
    VoiceStyle.internet: ['{name} is here and vibing', '{name} said hiii'],
    VoiceStyle.elegant: [
      '{name} greets you with a little bow.',
      '{name} is delighted by your visit.',
    ],
  },
  VoiceContext.emptyState: {
    VoiceStyle.natural: [
      'Nothing here yet.',
      'This space is ready when you are.',
    ],
    VoiceStyle.cozy: [
      'Nothing here yet — it\'s a cozy blank space.',
      'All quiet. Add something whenever.',
    ],
    VoiceStyle.sarcastic: [
      'Wow. So empty. Very avant-garde.',
      'Nothing here. Bold choice.',
    ],
    VoiceStyle.deadpan: [
      'Empty. As intended, probably.',
      'There is nothing here.',
    ],
    VoiceStyle.chaotic: [
      'it\'s EMPTY in here!!! echo echo echo',
      'nothing?? NOTHING???',
    ],
    VoiceStyle.grumpy: [
      'Nothing here. Add something or don\'t. Hmph.',
      'Empty. Typical.',
    ],
    VoiceStyle.cheerful: [
      'A fresh start! Add your first one!',
      'Nothing yet — exciting!',
    ],
    VoiceStyle.serious: ['No items yet.', 'Nothing has been added.'],
    VoiceStyle.professional: [
      'No items to show.',
      'Get started by adding one.',
    ],
    VoiceStyle.poetic: [
      'An empty shelf, waiting for treasures.',
      'Here, a quiet clearing.',
    ],
    VoiceStyle.gamer: ['Inventory empty.', 'No items collected yet.'],
    VoiceStyle.internet: ['nothing here yet lol', 'empty for now :)'],
    VoiceStyle.elegant: ['Nothing here as yet.', 'A blank canvas awaits.'],
  },
  VoiceContext.farewell: {
    VoiceStyle.natural: ['See you soon.', 'Take care.'],
    VoiceStyle.cozy: [
      'Rest well. Come back anytime.',
      'Bye for now — stay warm.',
    ],
    VoiceStyle.sarcastic: [
      'Leaving already? Fine. I\'ll miss you. Slightly.',
      'Bye. I\'ll just be here. Alone.',
    ],
    VoiceStyle.deadpan: [
      'Goodbye. I will now stare at the wall.',
      'Farewell. Signing off.',
    ],
    VoiceStyle.chaotic: [
      'BYEEE come back soon!!!',
      'nooo don\'t goooo (ok bye)',
    ],
    VoiceStyle.grumpy: ['Bye. Don\'t be a stranger. Hmph.', 'Off you go then.'],
    VoiceStyle.cheerful: ['Bye! Have a wonderful day!', 'See you soon! 👋'],
    VoiceStyle.serious: ['Goodbye. Take care.', 'Until next time.'],
    VoiceStyle.professional: ['Signed out. See you next time.', 'Goodbye.'],
    VoiceStyle.poetic: [
      'Go softly; the door stays open.',
      'Until the next light.',
    ],
    VoiceStyle.gamer: [
      'Logging off. GG.',
      'Save and quit. See you next session.',
    ],
    VoiceStyle.internet: ['byeee', 'ok cya'],
    VoiceStyle.elegant: ['Farewell for now.', 'Until we meet again.'],
  },
};
