/// The built-in decoration asset library, as compact text: emoji drawn
/// with the system's colour emoji font and line-art objects drawn from the
/// app's own icon font (tinted to match a look). Procedural pieces (frames,
/// washi, shapes, garland and light styles…) are added in code.
library;

/// id|name|emoji|default behaviour
const decorAssetCategoryRows = <String>[
  'hanging|Hanging decorations|🎐|sway',
  'garlands|Garlands & bunting|🎉|sway',
  'lights|Fairy lights & glow|💡|twinkle',
  'shelves|Shelves & storage|🗄️|none',
  'furniture|Miniature furniture|🪑|none',
  'plants|Houseplants|🪴|sway',
  'flowers|Flowers|🌸|bloom',
  'trees|Trees|🌳|sway',
  'vines|Vines & foliage|🍃|sway',
  'windows|Windows & doors|🪟|none',
  'curtains|Curtains & drapes|🎭|sway',
  'rugs|Rugs & textiles|🧶|none',
  'lamps|Lamps|🛋️|toggle',
  'candles|Candles|🕯️|flicker',
  'lanterns|Lanterns|🏮|sway',
  'frames|Picture frames|🖼️|none',
  'posters|Posters & signs|📜|none',
  'books|Books|📚|open',
  'stationery|Stationery|✏️|none',
  'instruments|Musical instruments|🎻|play',
  'plush|Plush toys|🧸|bounce',
  'animals|Animals|🐈|walk',
  'insects|Insects|🦋|flutter',
  'aquatic|Aquatic creatures|🐠|swim',
  'stars|Stars|⭐|twinkle',
  'planets|Planets & moons|🪐|orbit',
  'clouds|Clouds|☁️|drift',
  'weather|Weather effects|🌧️|fall',
  'water|Water features|⛲|ripple',
  'crystals|Crystals|🔮|shimmer',
  'gems|Gemstones & jewels|💍|shimmer',
  'ribbons|Ribbons|🎗️|sway',
  'bows|Bows & knots|🎀|none',
  'chains|Chains & metalwork|⛓️|sway',
  'lace|Lace & doilies|🤍|none',
  'paper|Paper decorations|📃|flutter',
  'washi|Washi & tape|🎞️|none',
  'stickers|Stickers & badges|🏷️|none',
  'clocks|Clocks|🕰️|tick',
  'tech|Technology objects|💻|blink',
  'holograms|Holograms|🌐|shimmer',
  'floating|Floating objects|🎈|float',
  'food|Food|🍰|none',
  'drinks|Drinks|☕|steam',
  'buildings|Miniature buildings|🏠|none',
  'vehicles|Trains & vehicles|🚂|move',
  'fantasy|Fantasy creatures|🐉|float',
  'sculpture|Abstract sculptures|🗿|spin',
  'dividers|Dividers & borders|➖|none',
  'profile|Profile ornaments|👑|none',
  'nav|Navigation ornaments|🧭|none',
  'sports|Sports & games|⚽|bounce',
  'nature|Rocks, shells & nature finds|🪨|none',
  'celebration|Celebration & gifts|🎁|bounce',
  'symbols|Hearts & symbols|💖|pulse',
  'people|Little people|🧑‍🎨|wave',
  'corners|Corner pieces|📐|none',
];

/// Category → `glyph name|glyph name|…`.
const decorAssetEmoji = <String, String>{
  'hanging':
      '🎐 wind chime|🏮 red lantern|🪅 piñata|🎏 carp streamer|🪩 mirror ball|🔔 bell|🎊 confetti ball|🧿 charm|🪬 hamsa|🎀 hanging bow|🪽 wing charm|🕸️ cobweb',
  'garlands':
      '🎉 party popper|🎈 balloon|🎋 tanabata tree|🎍 pine decoration|🏳️ pennant|🚩 flag|🎌 crossed flags|🏁 chequered flag|🪁 kite',
  'lights':
      '💡 light bulb|🔦 torch|🕯️ candle|🪔 oil lamp|✨ sparkles|🌟 glowing star|💫 dizzy star|⚡ spark',
  'shelves':
      '🗄️ cabinet|🗃️ card box|📦 box|🧰 toolbox|🧺 basket|🗳️ ballot box|🪣 bucket|🛍️ shopping bags|👜 handbag|🎁 gift box',
  'furniture':
      '🪑 chair|🛋️ sofa|🛏️ bed|🚪 door|🪞 mirror|🪟 window|🚽 toilet|🛁 bathtub|🚿 shower|🪜 ladder|🛗 elevator|🧸 rocking toy|🛒 cart|🪤 mousetrap|🪒 razor|🧴 lotion',
  'plants':
      '🪴 potted plant|🌵 cactus|🌱 seedling|🌿 herb|☘️ shamrock|🍀 four-leaf clover|🪹 empty nest|🪺 nest with eggs',
  'flowers':
      '🌸 cherry blossom|💮 white flower|🏵️ rosette|🌹 rose|🥀 wilted rose|🌺 hibiscus|🌻 sunflower|🌼 blossom|🌷 tulip|🪷 lotus|🪻 hyacinth|💐 bouquet',
  'trees': '🌳 tree|🌲 evergreen|🌴 palm|🎄 fir|🪵 log|🌾 rice stalk',
  'vines':
      '🍃 fluttering leaves|🍂 fallen leaves|🍁 maple leaf|🪸 coral branch|🫛 pea pod|🫚 ginger root',
  'windows': '⛩️ shrine gate|🏛️ columns|🗿 statue',
  'curtains': '🎭 theatre masks|👘 kimono|🥻 sari|🧣 scarf|🎽 sash',
  'rugs':
      '🧶 yarn|🧵 thread|🪡 sewing needle|🧦 socks|🧤 gloves|👒 sun hat|🎩 top hat|👑 crown|🧢 cap|👗 dress',
  'candles': '🔥 flame|🧯 extinguisher',
  'lanterns': '🎑 moon viewing|🎆 fireworks|🎇 sparkler|🧨 firecracker',
  'frames':
      '🖼️ framed picture|🏞️ landscape|🌅 sunrise picture|🌄 mountain sunrise|🗾 map of Japan|🌁 foggy city|🌃 night city|🌇 sunset city|🌉 bridge at night',
  'posters':
      '📜 scroll|📃 page|📄 document|📰 newspaper|🗞️ rolled paper|🪧 placard|📯 post horn|🚸 crossing sign|⛔ no entry|🔰 beginner badge|🎦 cinema sign|🆒 cool sign|🆕 new sign|🆗 ok sign',
  'books':
      '📚 book stack|📖 open book|📕 red book|📗 green book|📘 blue book|📙 orange book|📒 ledger|📓 notebook|📔 decorated notebook|🔖 bookmark|🏷️ tag',
  'stationery':
      '✏️ pencil|✒️ nib|🖊️ pen|🖋️ fountain pen|🖍️ crayon|📝 memo|📎 paperclip|🖇️ linked clips|📌 pushpin|📍 pin|✂️ scissors|📏 ruler|📐 set square|🗒️ notepad|🗓️ calendar pad|📆 tear-off calendar|📇 card index|📋 clipboard|🗂️ dividers|🖌️ paintbrush|🎨 palette',
  'instruments':
      '🎸 guitar|🎹 piano|🥁 drum|🪘 long drum|🎷 saxophone|🎺 trumpet|🎻 violin|🪕 banjo|🪗 accordion|🪈 flute|🪇 maracas|🎤 microphone|🎙️ studio mic|🎧 headphones|📻 radio|🎼 score|🎵 note|🎶 notes',
  'plush':
      '🪆 nesting doll|🪀 yo-yo|🎎 dolls|🦄 unicorn plush|🐻 bear plush|🐼 panda plush|🐨 koala plush|🐰 bunny plush|🐹 hamster plush',
  'animals':
      '🐈 cat|🐈‍⬛ black cat|🐕 dog|🐩 poodle|🐇 rabbit|🐿️ chipmunk|🦔 hedgehog|🦦 otter|🦥 sloth|🦝 raccoon|🦊 fox|🐺 wolf|🦌 deer|🐄 cow|🐖 pig|🐑 sheep|🐐 goat|🐓 rooster|🐥 chick|🦆 duck|🦢 swan|🦉 owl|🦜 parrot|🦩 flamingo|🕊️ dove|🐧 penguin|🐦 bird|🐸 frog|🐢 turtle|🦎 lizard|🐍 snake|🐘 elephant|🦒 giraffe|🦓 zebra|🦁 lion|🐯 tiger|🐆 leopard|🦘 kangaroo|🐒 monkey|🦍 gorilla|🐪 camel|🦙 llama|🦛 hippo|🦏 rhino|🦇 bat|🐁 mouse|🦫 beaver|🦨 skunk|🦡 badger|🐎 horse|🐂 ox|🦬 bison|🐫 two-hump camel|🦚 peacock|🦃 turkey|🦤 dodo|🐦‍⬛ blackbird|🪿 goose|🫎 moose|🫏 donkey',
  'insects':
      '🦋 butterfly|🐝 bee|🐞 ladybird|🐛 caterpillar|🐌 snail|🐜 ant|🦗 cricket|🪲 beetle|🪳 cockroach|🕷️ spider|🦂 scorpion|🦟 mosquito|🪰 fly|🪱 worm',
  'aquatic':
      '🐠 tropical fish|🐟 fish|🐡 blowfish|🦈 shark|🐬 dolphin|🐳 spouting whale|🐋 whale|🐙 octopus|🦑 squid|🦀 crab|🦞 lobster|🦐 shrimp|🐚 shell|🪼 jellyfish|🦭 seal|🦪 oyster',
  'stars':
      '⭐ star|🌠 shooting star|🔯 six-pointed star|✴️ eight-point star|✳️ asterisk star|❇️ sparkle',
  'planets':
      '🪐 ringed planet|🌍 Earth Africa|🌎 Earth Americas|🌏 Earth Asia|🌕 full moon|🌖 waning gibbous|🌗 last quarter|🌘 waning crescent|🌑 new moon|🌒 waxing crescent|🌓 first quarter|🌔 waxing gibbous|🌙 crescent|🌛 first quarter face|🌜 last quarter face|🌚 new moon face|🌝 full moon face|☀️ sun|🌞 sun face|☄️ comet|🌌 milky way',
  'clouds':
      '☁️ cloud|⛅ sun behind cloud|🌤️ small cloud|🌥️ big cloud|🌦️ sun shower|🌫️ fog',
  'weather':
      '🌧️ rain cloud|⛈️ storm cloud|🌩️ lightning cloud|🌨️ snow cloud|❄️ snowflake|☃️ snowman|⛄ snowman without snow|🌬️ wind face|🌪️ tornado|🌈 rainbow|☂️ umbrella|☔ umbrella with rain|⛱️ beach umbrella|💧 droplet|💦 splashes|🌡️ thermometer',
  'water':
      '⛲ fountain|🌊 wave|🛶 canoe|⛵ sailboat|🚤 speedboat|⚓ anchor|🛟 ring buoy|🏝️ island|🏖️ beach|🫧 bubbles',
  'crystals':
      '🔮 crystal ball|💎 gem|🪨 rock|🧊 ice|💠 diamond shape|🔷 blue diamond|🔶 orange diamond|🔹 small blue diamond|🔸 small orange diamond',
  'gems':
      '💍 ring|📿 beads|🪙 coin|🏅 medal|🥇 gold medal|🥈 silver medal|🥉 bronze medal|🎖️ military medal|🏆 trophy|⚜️ fleur-de-lis',
  'ribbons':
      '🎗️ awareness ribbon|🧧 red envelope|🎟️ admission ticket|🎫 ticket',
  'bows': '🪢 knot|👔 necktie|🥋 belt|🩱 swimsuit|👙 bikini|🩰 ballet shoes',
  'chains':
      '⛓️ chain|🔗 link|🧷 safety pin|🔩 nut and bolt|⚙️ gear|🗝️ old key|🔑 key|🔒 lock|🔓 open lock|🧲 magnet|⚖️ scales|🪝 hook',
  'lace': '🤍 white heart|🩶 grey heart|🫶 heart hands|🪭 folding fan',
  'paper':
      '🧻 paper roll|📑 tabs|🗺️ map|✉️ envelope|📨 incoming envelope|📩 envelope arrow|💌 love letter|📮 postbox|📪 mailbox|🎴 flower cards|🀄 mahjong tile|🃏 joker card',
  'washi': '🎞️ film frames|📽️ projector|🩹 bandage|📼 videotape',
  'stickers':
      '💯 hundred points|🆙 up sign|🆓 free sign|🔝 top sign|✅ check mark|❌ cross mark|❓ question|❗ exclamation|💢 anger symbol|💤 zzz|💬 speech bubble|💭 thought bubble|🗯️ shout bubble|♻️ recycle|☮️ peace|☯️ yin yang|♾️ infinity|⚛️ atom|🕉️ om|🔆 bright|🔅 dim',
  'clocks':
      '🕰️ mantel clock|⏰ alarm clock|⏱️ stopwatch|⏲️ timer|⌚ watch|⌛ hourglass|⏳ flowing hourglass|🕛 twelve o\'clock|🕒 three o\'clock|🕕 six o\'clock|🕘 nine o\'clock',
  'tech':
      '💻 laptop|🖥️ desktop|⌨️ keyboard|🖱️ mouse|🖲️ trackball|💽 minidisc|💾 floppy|💿 CD|📀 DVD|🧮 abacus|📱 phone|📲 phone arrow|☎️ telephone|📞 receiver|📟 pager|📠 fax|🔋 battery|🪫 low battery|🔌 plug|📡 satellite dish|🛰️ satellite|🤖 robot|🕹️ joystick|🎮 game controller|📷 camera|📸 flash camera|📹 video camera|🎥 movie camera|📺 television|🔭 telescope|🔬 microscope|🧪 test tube|🧫 petri dish|🧬 DNA',
  'holograms':
      '🌐 globe with meridians|🔘 radio button|🔳 square button|🔲 black square button|🔵 blue circle|🟣 purple circle|🟢 green circle|🔺 red triangle|🔻 down triangle',
  'floating': '🪶 feather|🧞 genie|🪄 wand|🛸 flying saucer',
  'food':
      '🍎 apple|🍐 pear|🍊 tangerine|🍋 lemon|🍌 banana|🍉 watermelon|🍇 grapes|🍓 strawberry|🫐 blueberries|🍈 melon|🍒 cherries|🍑 peach|🥭 mango|🍍 pineapple|🥥 coconut|🥝 kiwi|🍅 tomato|🥑 avocado|🍆 aubergine|🥕 carrot|🌽 corn|🌶️ pepper|🥦 broccoli|🍄 mushroom|🥜 peanuts|🌰 chestnut|🍞 bread|🥐 croissant|🥖 baguette|🥨 pretzel|🥯 bagel|🥞 pancakes|🧇 waffle|🧀 cheese|🍳 fried egg|🍕 pizza|🍔 burger|🍟 fries|🌭 hot dog|🥪 sandwich|🌮 taco|🌯 burrito|🍝 spaghetti|🍜 ramen|🍲 stew|🍛 curry|🍣 sushi|🍱 bento|🥟 dumpling|🍙 rice ball|🍘 rice cracker|🍥 fish cake|🍡 dango|🍦 soft serve|🍧 shaved ice|🍨 ice cream|🍩 doughnut|🍪 cookie|🎂 birthday cake|🍰 shortcake|🧁 cupcake|🥧 pie|🍫 chocolate|🍬 candy|🍭 lollipop|🍮 custard|🍯 honey pot|🥮 mooncake|🍿 popcorn',
  'drinks':
      '☕ hot beverage|🍵 teacup|🫖 teapot|🧋 bubble tea|🥤 cup with straw|🧃 juice box|🥛 milk|🍼 baby bottle|🍶 sake|🍷 wine|🍸 cocktail|🍹 tropical drink|🍺 mug|🍻 clinking mugs|🥂 clinking glasses|🥃 tumbler|🧉 mate|🫗 pouring',
  'buildings':
      '🏠 house|🏡 house with garden|🏘️ houses|🏚️ old house|🏢 office|🏬 department store|🏣 post office|🏤 European post|🏥 hospital|🏦 bank|🏨 hotel|🏪 shop|🏫 school|🏩 love hotel|🏭 factory|🏯 Japanese castle|🏰 castle|💒 chapel|🗼 tower|🗽 statue of liberty|⛪ church|🕌 mosque|🛕 temple|🕍 synagogue|🕋 kaaba|⛺ tent|🎪 circus tent|🎡 Ferris wheel|🎢 roller coaster|🎠 carousel|🛖 hut|🗻 Mount Fuji|🌋 volcano|⛰️ mountain|🏔️ snowy mountain|🏟️ stadium|🏗️ crane',
  'vehicles':
      '🚂 locomotive|🚃 railway car|🚄 bullet train|🚋 tram|🚌 bus|🚎 trolleybus|🚐 minibus|🚑 ambulance|🚒 fire engine|🚓 police car|🚕 taxi|🚗 car|🚙 SUV|🛻 pickup|🚚 truck|🚜 tractor|🏎️ race car|🏍️ motorcycle|🛵 scooter|🚲 bicycle|🛴 kick scooter|🛹 skateboard|🛼 roller skate|🚁 helicopter|✈️ aeroplane|🛩️ small plane|🪂 parachute|🚀 rocket ship|🚠 cable car|🚡 aerial tramway|🛺 rickshaw|🚢 ship|⛴️ ferry',
  'fantasy':
      '🐉 dragon|🐲 dragon face|🧚 fairy|🧜 merperson|🧝 elf|🧞‍♂️ genie man|🧙 mage|🧛 vampire|🧟 zombie|👻 ghost|👽 alien|👾 space monster|👹 ogre|👺 goblin|🦕 sauropod|🦖 T-rex|🐦‍🔥 phoenix',
  'sculpture':
      '🏺 amphora|⚱️ urn|🔴 red orb|🟠 orange orb|🟡 yellow orb|🟤 brown orb|⚪ white orb|⚫ black orb|🟥 red block|🟧 orange block|🟨 yellow block|🟩 green block|🟦 blue block|🟪 purple block|🟫 brown block|⬛ black block|⬜ white block|♦️ diamond suit',
  'dividers':
      '➖ dash|〰️ wavy dash|➰ curly loop|➿ double loop|▫️ small square|▪️ black small square|◽ medium square|◾ dark square',
  'profile':
      '🎓 graduation cap|⛑️ helmet|🪖 military helmet|👓 glasses|🕶️ sunglasses|🥽 goggles|💄 lipstick|💅 nail polish|👛 purse|🎒 backpack|🧳 luggage|🌂 closed umbrella',
  'nav': '🧭 compass|🚏 bus stop|🛤️ railway track|🛣️ motorway|⛳ flag in hole',
  'sports':
      '⚽ football|🏀 basketball|🏈 American football|⚾ baseball|🥎 softball|🎾 tennis|🏐 volleyball|🏉 rugby|🥏 flying disc|🎱 pool ball|🏓 ping pong|🏸 badminton|🏒 hockey|🏑 field hockey|🥍 lacrosse|🏏 cricket|🪃 boomerang|🥅 goal|⛸️ ice skate|🎿 skis|🛷 sled|🥌 curling stone|🎯 bullseye|🎳 bowling|🎲 dice|♟️ chess pawn|🧩 jigsaw|🎰 slot machine',
  'nature': '🫘 beans|🍄‍🟫 brown mushroom',
  'celebration': '🎃 jack-o-lantern',
  'symbols':
      '❤️ red heart|🧡 orange heart|💛 yellow heart|💚 green heart|💙 blue heart|💜 purple heart|🤎 brown heart|🖤 black heart|🩷 pink heart|🩵 light blue heart|💖 sparkling heart|💗 growing heart|💓 beating heart|💞 revolving hearts|💕 two hearts|💘 heart with arrow|💝 heart with ribbon|💟 heart decoration|❣️ heart exclamation|♈ Aries|♉ Taurus|♊ Gemini|♋ Cancer|♌ Leo|♍ Virgo|♎ Libra|♏ Scorpio|♐ Sagittarius|♑ Capricorn|♒ Aquarius|♓ Pisces|⛎ Ophiuchus',
  'people':
      '🧑‍🎨 artist|🧑‍🍳 cook|🧑‍🚀 astronaut|🧑‍🔬 scientist|🧑‍🏫 teacher|🧑‍🎤 singer|🧑‍💻 coder|🧑‍🌾 farmer|🧑‍🚒 firefighter|🧑‍✈️ pilot|🧙‍♀️ witch|🧚‍♂️ fairy man|💃 dancer|🕺 dancing man|🧘 meditating|🏄 surfer|🚴 cyclist|🤹 juggler|🧗 climber',
};

/// Category → icon names (from the app's icon catalog).
const decorAssetIcons = <String, String>{
  'hanging':
      'bell-simple lamp-pendant disco-ball bell-ringing bell-z call-bell pinwheel',
  'garlands': 'flag-banner flag-pennant flag confetti cheers',
  'lights': 'lightbulb flashlight lamp sparkle star-four lightning-a sun-dim',
  'shelves':
      'archive books package dresser cube tote toolbox basket jar jar-label lockers tray suitcase briefcase stack',
  'furniture':
      'armchair bed bathtub couch chair desk door door-open oven shower toilet fan office-chair stool picnic-table table lectern stairs ladder',
  'plants': 'plant potted-plant cactus leaf grains clover flower-tulip acorn',
  'flowers': 'flower flower-lotus',
  'trees': 'tree tree-palm park',
  'vines': 'scribble spiral',
  'windows': 'house house-line house-simple warehouse garage storefront wall',
  'curtains': 'rows columns coat-hanger',
  'rugs':
      'yarn needle t-shirt dress pants sneaker sock hoodie high-heel boot rug towel shirt-folded beanie baseball-cap cowboy-hat belt',
  'lamps': 'campfire fire',
  'candles': 'fire-simple flame',
  'frames': 'image image-square images panorama aperture',
  'posters':
      'newspaper article scroll signpost megaphone presentation chalkboard film-slate traffic-sign',
  'books': 'book book-open notebook bookmark bookmarks student exam',
  'stationery':
      'pencil pen pen-nib paperclip push-pin scissors ruler eraser highlighter clipboard note note-pencil notepad pencil-line pencil-ruler paint-brush paint-roller paint-bucket swatches eyedropper stamp compass-tool',
  'instruments':
      'guitar piano-keys metronome microphone headphones music-note music-notes speaker-high radio vinyl-record waveform equalizer',
  'plush': 'smiley baby lego lego-smiley',
  'animals': 'cat dog rabbit bird horse cow paw-print butterfly fish',
  'insects': 'bug bug-beetle bug-droid',
  'aquatic': 'fish-simple waves drop shrimp',
  'stars': 'star star-half asterisk pentagram meteor',
  'planets':
      'planet moon moon-stars sun sun-horizon globe globe-simple globe-stand',
  'clouds': 'cloud cloud-sun cloud-moon cloud-fog',
  'weather':
      'cloud-rain cloud-snow lightning snowflake rainbow umbrella thermometer wind tornado',
  'water': 'drop-half boat anchor lifebuoy sailboat drop-simple island',
  'crystals': 'diamond sketch-logo sphere',
  'gems': 'crown crown-simple medal trophy coin coins seal seal-check',
  'ribbons': 'ticket tag tag-simple tag-chevron certificate',
  'chains':
      'link link-simple key lock lock-open gear gear-six magnet scales nut screwdriver wrench hammer pipe-wrench link-break keyhole',
  'lace': 'circles-four circle-notch',
  'paper':
      'envelope paper-plane map-trifold folder note-blank file receipt invoice file-text',
  'washi': 'film-strip film-reel film-script',
  'stickers':
      'smiley-wink sticker heart thumbs-up hand-peace hand-waving check-circle question chat-circle peace scan-smiley smiley-angry smiley-meh smiley-sad smiley-x-eyes mask-happy mask-sad',
  'clocks': 'clock alarm timer hourglass watch clock-user',
  'tech':
      'laptop desktop monitor keyboard mouse cpu circuitry hard-drive hard-drives memory floppy-disk joystick phone battery-full plug robot camera television wifi-high bluetooth broadcast sim-card usb printer headset calculator webcam drone head-circuit speaker-hifi cell-tower vibrate',
  'holograms':
      'atom cube-focus scan fingerprint eye hexagon octagon triangle polygon intersect graph chart-line gauge compass target crosshair three-d bounding-box perspective gradient matrix-logo',
  'floating': 'feather balloon airplane rocket parachute',
  'food':
      'pizza hamburger cookie cake bread egg carrot orange-slice pepper avocado ice-cream popcorn bowl-food bowl-steam fork-knife cooking-pot cheese cherries onigiri popsicle egg-crack',
  'drinks':
      'coffee coffee-bean beer-bottle beer-stein brandy champagne martini wine pint-glass tea-bag',
  'buildings':
      'buildings building church factory lighthouse mosque synagogue tent barn bank city farm windmill solar-roof tipi',
  'vehicles':
      'train train-simple tram bus car car-simple truck bicycle motorcycle scooter jeep van taxi tractor bulldozer crane fire-truck police-car ambulance moped cable-car subway',
  'fantasy': 'ghost alien skull magic-wand sword shield shield-star',
  'sculpture': 'shapes circle square pentagon infinity cylinder star-of-david',
  'dividers':
      'minus dots-three dots-nine line-segment wave-sine wave-square notches tilde',
  'profile': 'crown-cross user-circle eyeglasses goggles visor sunglasses',
  'nav': 'map-pin map-pin-line path compass-rose road-horizon footprints gps',
  'sports':
      'soccer-ball basketball baseball football tennis-ball volleyball golf dice-five puzzle-piece club spade racquet hockey boxing-glove barbell bowling-ball ping-pong beach-ball poker-chip cards',
  'nature': 'mountains',
  'celebration': 'gift',
  'symbols': 'heart-half heart-break yin-yang heartbeat',
  'people': 'person user users users-three hand-heart',
};
