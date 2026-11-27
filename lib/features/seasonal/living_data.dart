/// The raw text behind every permanent living genre: 80 genres in eight
/// families, 25 named looks each. Same block format as seasonal collections
/// (see `seasonal_data.dart`), plus:
///
///   @id|Name|emoji|living|family
///   mood:   palettes the looks rotate through (sets light / dark / soft)
///   styles: style words the looks combine (each look picks four)
///   looks:  the 25 look names
///
/// `colors:` redraws every look in the genre's own colours.
library;

const livingFamilies = <(String, String, String)>[
  ('space', 'Space & Celestial', '🪐'),
  ('future', 'Futuristic & Technology', '🤖'),
  ('cozy', 'Cottagecore & Cozy', '🏡'),
  ('academic', 'School & Academic', '📚'),
  ('nature', 'Environmental', '🌿'),
  ('artistic', 'Artistic & Fashion', '🎨'),
  ('cute', 'Cute & Whimsical', '🧸'),
  ('lifestyle', 'Lifestyle & Entertainment', '🎧'),
];

const livingSource = '''
@space_station|Space Station|🛰️|living|space
blurb: Panels, portholes and orbiting satellites aboard a quiet station high above the planet.
garland: 🛰️,🔩,💡,🛸,⭐,🪐,📡,🔭
corner: 🛰️,📡,🔭,🚀,🧑‍🚀,⚙️
hangers: 🛰️,🪐,⭐,🌍,🌙,☄️
furniture: 🧑‍🚀,🚀,🖥️,🔭,🧪,🪴
icons: 🛰️,🚀,🧑‍🚀,🌍,📡
acc: 🧑‍🚀,🪐,🛰️,⭐
amb: pad,night,wind
defaults: chain,bulbs,double,stars,window
colors: 0B1D3A,5FA8D3,E0E6ED,F2A541,8C9BAB
mood: midnight,minimal,neon,elegant,frost,classic
styles: chain,bulbs,double,starry,windowed,neonlights,hairline,sparkly,dotted,starlights,beads,clustered
looks: Orbital Dawn,Docking Bay,Command Deck,Zero-G Lounge,Hydroponics Bay,Observation Ring,Crew Quarters,Airlock Blue,Solar Array,Night Shift,Reactor Glow,Cargo Hold,Mission Control,Earthrise Window,Med Bay,Spacewalk,Comms Array,Galley Deck,Training Module,Satellite Repair,Lunar Shuttle Port,Recreation Deck,Silent Orbit,Research Pod,Low Power Mode

@deep_space|Deep Space|🌌|living|space
blurb: Endless dark sky, distant stars and slow drifting comets.
garland: ✨,⭐,☄️,🌌,💫,🌠,🌑,🪐
corner: 🌌,☄️,🌠,💫,🌑,⭐
hangers: ⭐,☄️,💫,🌠,🌑,✨
furniture: 🔭,🛸,🪐,🌑,☄️,🌠
icons: 🌌,☄️,⭐,🪐,🌠
acc: ⭐,🌌,☄️,💫
amb: pad,night,harp
defaults: beads,stars,hairline,stars,sunburst
colors: 05060F,1B1F4B,6C4AB6,B9A7FF,F5F3FF
mood: midnight,neon,gothic,indigo,celestial
styles: beads,starlights,hairline,starry,sunburst,sparkly,glittery,dotted,bokehy,nolights,clustered
looks: The Void,Starfield,Comet Trail,Event Horizon,Dark Matter,Pulsar Pulse,Quasar Light,Interstellar Drift,Cosmic Dust,Black Star,Rogue Planet,Silent Expanse,Distant Suns,Meteor Shower,Starlit Abyss,Gravity Well,Supernova Remnant,Light Years,Celestial Silence,Wandering Comet,Zodiac Light,Ion Trail,Frontier Stars,Outer Rim,Last Light

@observatory|Galactic Observatory|🔭|living|space
blurb: Brass telescopes, star charts and a dome open to the night.
garland: 🔭,⭐,🌙,🗺️,🧭,✨,🪐,📜
corner: 🔭,🗺️,🧭,📜,🕰️,🌙
hangers: 🌙,⭐,🪐,☄️,🌟,🌍
furniture: 🔭,📚,🕰️,🧭,🪑,🕯️
icons: 🔭,🌙,🗺️,🧭,⭐
acc: 🔭,🌙,🎩,⭐
amb: night,wind,pad
defaults: chain,lanterns,ornate,stars,scroll
colors: 101A33,C9A44C,3E5C8C,E8DCC0,6B4E2E
mood: midnight,elegant,vintage,amber,indigo,classic
styles: chain,lanterns,ornate,starry,scroll,double,candles,sparkly,wreathed,starlights,dotted,ribboned
looks: Brass Telescope,Star Chart Room,Copper Dome,Meridian Line,Astrolabe Study,Lantern Gallery,Night Watch,Planet Orrery,Map Table,Comet Log,Clockwork Sky,Lens Workshop,Observer's Balcony,Ink Constellations,Equinox Night,Gilded Dome,Dark Sky Reserve,Royal Observatory,Twilight Survey,Old Atlas,Moon Phase Wall,Polar Star,Sky Survey,Velvet Night,Midnight Ledger

@celestial_library|Celestial Library|📚|living|space
blurb: Tall shelves under a starry ceiling, books that seem to glow.
garland: 📚,✨,🌙,⭐,📜,🕯️,🪶,🔮
corner: 📚,🕯️,📜,🪶,🔮,🌙
hangers: 🌙,⭐,✨,🕯️,🔮,🌟
furniture: 📚,🕯️,🪑,🔮,📖,🕰️
icons: 📚,🌙,📖,🔮,⭐
acc: 📖,🌙,🪶,🔮
amb: night,fire,harp
defaults: swag,candles,ornate,sparkles,scroll
colors: 1C1633,7B5EA7,D9B65C,F2E8D5,2E4A7A
mood: midnight,gothic,elegant,celestial,amber,vintage
styles: swag,candles,ornate,sparkly,scroll,starlights,lace,starry,wreathed,double,glowing,ribboned
looks: Starlit Stacks,Moonbound Tomes,Astral Archive,Candle Reading Nook,Constellation Shelf,Silver Ink,Dreaming Pages,Night Scholar,Spiral Stair,Glowing Index,Lunar Annex,Velvet Reading Room,Comet Chapter,Golden Spines,Quiet Cosmos,Scroll Vault,Midnight Margins,Oracle Corner,Nebula Bindings,Owl Gallery,Twinkle Catalog,Rare Star Room,Stardust Footnotes,The Last Chapter,Wishing Shelf

@nebula|Nebula|🌫️|living|space
blurb: Swirling clouds of colour, glowing gas and newborn stars.
garland: 🌌,✨,💫,🌟,🫧,💜,🩵,🌠
corner: 🌌,💫,✨,🫧,🌟,💜
hangers: 💫,✨,🌟,🫧,⭐,🌠
furniture: 🔮,🪐,💎,🫧,✨,🌌
icons: 🌌,💫,✨,🌟,🫧
acc: 💫,🌌,💎,✨
amb: pad,harp,musicbox
defaults: beads,stars,hairline,bokeh,sunburst
colors: 140A2E,C04CFD,4CC9F0,FF6FB5,F7F1FF
mood: neon,celestial,midnight,dreamy,lilac,gothic
styles: beads,starlights,bokehy,sunburst,glittery,sparkly,hairline,neonlights,bubbly,dotted,tinsel
looks: Pillars of Light,Rose Nebula,Cat's Eye,Orion Haze,Violet Bloom,Cyan Drift,Star Nursery,Pink Plume,Gas Giant Glow,Aurora Cloud,Ionized Veil,Prism Cloud,Helix Swirl,Crab Glow,Lagoon Light,Horsehead Shadow,Butterfly Wings,Dust Lane,Ember Cloud,Ghost Veil,Tarantula Glow,Iris Haze,Bubble Nebula,Opal Mist,Crystal Cloud

@constellation|Constellation|✨|living|space
blurb: Stars joined by fine lines, myths and maps across the sky.
garland: ⭐,✨,🌟,💫,🌙,♈,♌,♓
corner: ⭐,🌟,🌙,✨,💫,🔭
hangers: ⭐,🌟,✨,💫,🌙,☄️
furniture: 🔭,🗺️,📜,🕯️,🪐,🌙
icons: ✨,⭐,🌙,🔭,🌟
acc: ⭐,🌙,✨,🌟
amb: night,harp,pad
defaults: beads,stars,dotted,stars,sunburst
colors: 0E1A40,F4D35E,9FB4E8,FFFFFF,3A4C8C
mood: midnight,indigo,minimal,celestial,frost,classic
styles: beads,starlights,dotted,starry,sunburst,hairline,sparkly,chain,double,glowing,clustered
looks: Big Dipper,Orion's Belt,Cassiopeia,Little Bear,Swan in Flight,Lyra's Harp,Pegasus Field,Scorpion Tail,Twin Stars,Lion's Mane,Southern Cross,Hunter's Night,Dragon Coil,Winter Hexagon,Summer Triangle,Star Hopping,Myth Map,Polaris Guide,Seven Sisters,Zodiac Ring,Sky Atlas,Navigator's Night,Star Thread,Hidden Figures,Silver Lines

@lunar_surface|Lunar Surface|🌕|living|space
blurb: Grey dust, craters and the blue Earth hanging in a black sky.
garland: 🌕,🌑,🌒,🌓,🌔,🌖,🌗,🌘
corner: 🌕,🌍,🚀,🪨,🧑‍🚀,🌑
hangers: 🌍,⭐,🌙,🛰️,☄️,🌕
furniture: 🪨,🚩,🧑‍🚀,🚀,🛰️,🌕
icons: 🌕,🌍,🚀,🧑‍🚀,🌑
acc: 🧑‍🚀,🌕,🚩,🌍
amb: pad,wind,night
defaults: beads,none,hairline,stars,window
colors: 1A1A1E,BDBDBD,7A7A80,4F86C6,F5F5F5
mood: midnight,minimal,frost,classic,elegant
styles: beads,nolights,hairline,starry,windowed,dotted,double,sparkly,chain,clustered,calm
looks: Sea of Tranquility,Crater Rim,Earthrise,Moon Base,Footprints,Dust Plain,Lunar Rover,Far Side,Silver Highlands,Moon Phases,Regolith Path,Lunar Dawn,Lava Tubes,Quiet Basin,Low Gravity,Moonlight Lab,Polar Ice,Grey Dunes,Mare Night,Flag Planted,Lander Window,Waxing Crescent,Eclipse,Harvest Moon,Blue Earth

@solar_system|Solar System|🪐|living|space
blurb: The sun and its planets on gentle orbits, ringed and moon-lit.
garland: ☀️,🪐,🌍,🌕,⭐,☄️,🌑,🔴
corner: ☀️,🪐,🌍,☄️,🌕,🔭
hangers: 🪐,🌍,🌕,☀️,☄️,⭐
furniture: 🔭,🪐,🌍,🚀,🛰️,☀️
icons: 🪐,☀️,🌍,🌕,☄️
acc: 🪐,☀️,🌍,🚀
amb: pad,harp,night
defaults: beads,bulbs,dotted,stars,sunburst
colors: 0F1530,F9A825,E65100,4FC3F7,C5A26A
mood: midnight,bold,retro,celestial,classic,neon
styles: beads,bulbs,dotted,starry,sunburst,pompoms,double,sparkly,chain,starlights,clustered
looks: Morning Sun,Mercury Heat,Venus Glow,Blue Marble,Red Planet,Asteroid Belt,Jupiter Storm,Saturn Rings,Ice Giant,Neptune Blue,Kuiper Edge,Orrery Desk,Planet Parade,Solar Flare,Eclipse Path,Moon Collection,Gas Giants,Rocky Worlds,Heliosphere,Planetarium,Orbit Lines,Comet Visit,Planet Lineup,Dwarf Planets,Space Map

@astronaut_bedroom|Astronaut's Bedroom|👩‍🚀|living|space
blurb: A cozy room for a space dreamer: glow stars, rockets and model planets.
garland: 🚀,⭐,🪐,🌙,🛸,🌟,👽,🌍
corner: 🚀,🧸,🪐,🛸,🌙,⭐
hangers: 🪐,🚀,🌙,⭐,🛸,🌍
furniture: 🛏️,🧸,🚀,🔭,📚,🪴
icons: 👩‍🚀,🚀,🪐,🛸,🌙
acc: 🧑‍🚀,🚀,🌙,⭐
amb: musicbox,night,pad
defaults: bunting,stars,dotted,stars,cluster
colors: 1E2A5A,FFD166,EF476F,06D6A0,F1FAEE
mood: midnight,kawaii,bold,pastel,whimsical,sky
styles: bunting,starlights,dotted,starry,clustered,pompoms,scallops,sparkly,beads,hearty,fairy,windowed
looks: Glow Stars,Rocket Bunk,Mission Patch Wall,Model Planets,Moon Lamp,Space Camp,Alien Plush,Cardboard Rocket,Star Projector,Comet Quilt,Dream Launch,Bedtime Countdown,Telescope Window,Mini Galaxy,Sticker Nebula,Space Pajamas,Lunar Nightlight,Toy Shuttle,Ceiling Orbit,Cosmic Blanket,Future Astronaut,Starry Rug,Satellite Mobile,Sleepy Saturn,Launch Pad

@cosmic_ocean|Cosmic Ocean|🌊|living|space
blurb: Where stars meet sea: glowing tides, star-fish and moonlit waves.
garland: 🌊,⭐,🐚,✨,🌙,🪼,🐋,💫
corner: 🌊,🐚,🪼,🌙,⭐,🐋
hangers: 🪼,⭐,🌙,🐚,💫,✨
furniture: 🐚,🪼,🐋,🌊,🪸,🌙
icons: 🌊,🐋,🪼,🌙,⭐
acc: 🐚,🌙,⭐,🪼
amb: waves,pad,harp
defaults: beads,stars,scallop,bubbles,sunburst
colors: 06142E,1FA2C9,7B5CD6,F8F3FF,3EE6C1
mood: midnight,ocean,celestial,dreamy,teal,neon
styles: beads,starlights,scallops,bubbly,sunburst,sparkly,starry,hairline,glowing,ribbons,dotted,bokehy
looks: Starlit Tide,Moon Jellies,Galaxy Reef,Whale Song,Night Lagoon,Bioluminescence,Star Shells,Cosmic Current,Tidal Nebula,Pearl Moon,Deep Sky Sea,Siren Stars,Glow Kelp,Aurora Waves,Celestial Bay,Drifting Comets,Silver Surf,Comet Fish,Abyssal Night,Lunar Tide Pools,Wave Galaxy,Ocean of Stars,Mermaid Orbit,Sea of Dreams,Twilight Shore
@future_lab|Futuristic Laboratory|🧪|living|future
blurb: Clean white benches, glowing vials and quiet robotic helpers.
garland: 🧪,⚗️,🧬,💡,🔬,🤖,🧫,⚡
corner: 🔬,🧬,🤖,⚗️,🧪,💡
hangers: 💡,🧬,⚛️,🧪,⚡,🔋
furniture: 🤖,🔬,🖥️,🧪,🧫,🪴
icons: 🧪,🧬,🔬,🤖,⚛️
acc: 🥽,🧪,🤖,🧬
amb: pad,chimes,stream
defaults: chain,neon,hairline,sparkles,window
colors: F4F8FB,19C3E6,7AE582,2D3142,B8C4D6
mood: minimal,frost,neon,teal,classic,midnight
styles: chain,neonlights,hairline,sparkly,windowed,dotted,bubbly,double,beads,bulbs,clustered
looks: Clean Room,Gene Lab,Particle Bench,Robotics Bay,Cryo Storage,Plasma Test,Bio Dome,Nano Workshop,Quantum Desk,Hologram Lab,Specimen Wall,Light Lab,Data Core,Neural Lab,Night Experiment,Mint Protocol,Fusion Cell,Microscope Station,Synthesis Room,Prototype Bay,Calibration Hall,Signal Lab,Chrome Bench,Greenhouse Lab,Sterile Blue

@cyberpunk|Cyberpunk|🌃|living|future
blurb: Neon rain, glowing signs and a city that never sleeps.
garland: 🌃,⚡,💾,🕶️,📟,🔋,🤖,💿
corner: 🌃,🏙️,🕶️,🤖,📟,⚡
hangers: ⚡,💿,🔋,📟,🕶️,💾
furniture: 🖥️,🛵,🤖,🍜,📺,🕹️
icons: 🌃,🤖,⚡,🕶️,💾
acc: 🕶️,🤖,⚡,🎧
amb: rain,storm,pad
defaults: chain,neon,zigzag,rain,window
colors: 0A0A14,FF2E93,00F0FF,F9F871,7B2CBF
mood: neon,midnight,gothic,bold
styles: chain,neonlights,zigzag,raining,windowed,glittery,hairline,bulbs,double,starry,tassels,bokehy
looks: Neon Alley,Rain Market,Holo Billboards,Chrome District,Night Noodle Bar,Synth Rooftop,Data Haven,Back Street Clinic,Glitch Arcade,Magenta Skyline,Underground Club,Hover Traffic,Wire Jungle,Pink Rain,Blackout City,Signal Tower,Cyan Haze,Megablock,Street Samurai,Sector Seven,Night Courier,Electric Shrine,Mirror Shades,Static Storm,Dawn Over Neon

@solarpunk|Solarpunk|🌞|living|future
blurb: Green rooftops, solar sails and a hopeful, growing future.
garland: 🌿,☀️,🌻,🪴,🔆,🐝,🍃,🌱
corner: 🌿,🌻,🪴,☀️,🐝,🌱
hangers: 🪴,🌱,☀️,🍃,🐝,🦋
furniture: 🪴,🚲,🌻,🧺,🔆,🌳
icons: 🌞,🌿,🌻,🐝,🌱
acc: 🌻,🐝,🌿,☀️
amb: birds,stream,wind
defaults: vine,fairy,vine,leaves,sprig
colors: F5F1DC,4CAF50,F4B400,2E86AB,A1683A
mood: garden,moss,sky,whimsical,classic,golden
styles: vine,fairy,vined,leafy,flutter,bunting,glowing,sunburst,emojis,petalfall,scallops,wreathed
looks: Rooftop Garden,Solar Sails,Vertical Farm,Bee Corridor,Wind Garden,Glass Greenhouse,Bike Commons,Seed Library,Sun Terrace,Rain Catcher,Living Walls,Community Orchard,Green Tram,Market Canopy,Ivy Towers,Moss Plaza,Sunflower Grid,Water Garden,Repair Café,Pollinator Path,Golden Panels,Treehouse Lab,Kite Festival,Riverside Commons,Morning Bloom

@retrofuturism|Retrofuturism|🚀|living|future
blurb: Tomorrow as yesterday imagined it: chrome fins, ray guns and atomic starbursts.
garland: 🚀,⚛️,🛸,⭐,📺,🤖,💫,📻
corner: 🚀,🛸,⚛️,🤖,📺,⭐
hangers: 🛸,⭐,⚛️,🪐,💫,🚀
furniture: 🤖,📺,📻,🚀,🛋️,☎️
icons: 🚀,🛸,⚛️,🤖,📺
acc: 🚀,🤖,🕶️,⚛️
amb: pad,musicbox,chimes
defaults: beads,bulbs,dotted,stars,sunburst
colors: F2E4C8,E94F37,1C9CA6,F6C445,393E41
mood: retro,bold,midnight,classic,sunset,carnival
styles: beads,bulbs,dotted,starry,sunburst,pompoms,double,sparkly,chain,starlights,scallops,confettied
looks: Atomic Kitchen,Ray Gun Gallery,Jet Age Diner,Space Race,Chrome Fins,Robot Butler,Tomorrowland,Saucer Drive-in,Googie Sign,Rocket Garden,Vintage Mission,Bubble Car,TV of Tomorrow,Starburst Lounge,Moonbase 1965,Pulp Cover,Monorail City,Teal Dream,Orbit Motel,Laser Show,Future Fair,Tin Toy Robot,Satellite Clock,Retro Cosmonaut,Space Age Living

@frutiger_aero|Frutiger Aero|🫧|living|future
blurb: Glossy bubbles, clear water, blue skies and fresh green leaves.
garland: 🫧,💧,🐠,🌿,☁️,🐬,🌈,✨
corner: 🫧,🐠,🌿,☁️,💧,🐬
hangers: 🫧,💧,☁️,🐟,🦋,✨
furniture: 🐠,🌿,🖥️,🫧,🐬,🌱
icons: 🫧,💧,🐠,🌿,☁️
acc: 🫧,🐬,🌿,💧
amb: stream,waves,birds
defaults: beads,fairy,hairline,bubbles,cluster
colors: E9F7FF,1E9BE9,7ED957,FFFFFF,0B5394
mood: sky,frost,ocean,garden,minimal,teal
styles: beads,fairy,hairline,bubbly,clustered,sparkly,bokehy,flutter,dotted,glowing,scallops,cloudy
looks: Glossy Sky,Aqua Bubbles,Green Hills,Water Drop,Clear Aquarium,Sunny Desktop,Fresh Leaf,Lens Flare,Dolphin Bay,Crystal Stream,Cloud Glass,Morning Dew,Eco Dream,Floating Orbs,Tropical Glass,Aurora Gloss,Lime Breeze,Clean Energy,Rain Glass,Butterfly Glass,Ocean Breeze,Gel Buttons,Shiny Planet,Wind Turbines,Summer Gloss

@frutiger_metro|Frutiger Metro|🔷|living|future
blurb: Flat tiles, bright blocks and clean typography on cool city light.
garland: 🔷,🔶,🟩,🟦,🟧,🟪,⬜,🟥
corner: 🔷,🟦,🟩,🔶,🟧,⬜
hangers: 🔷,🔶,⬜,🟦,🟩,🟪
furniture: 🖥️,📱,🚇,🗺️,☕,🪴
icons: 🔷,🟦,🟩,🟧,📱
acc: 📱,🔷,🎧,☕
amb: pad,stream,chimes
defaults: flags,none,hairline,none,frame
colors: F2F2F2,0078D7,00B294,FF8C00,E81123
mood: minimal,bold,classic,sky,teal
styles: flags,nolights,hairline,double,ornate,dotted,bunting,calm,clustered,windowed,confettied
looks: Live Tiles,Metro Blue,Teal Grid,Orange Block,Subway Map,Clean Type,Commuter Morning,Tile Wall,Square Garden,Pivot Lines,Panorama Hub,Flat Sky,Red Accent,City Grid,Tablet Start,Minimal Hub,Accent Purple,Lime Tile,Steel Grey,Paper White,Bright Mosaic,People Hub,Slate Night,Calendar Tile,Weather Tile

@y2k_tech|Y2K Technology|💿|living|future
blurb: Translucent plastic, chrome blobs, flip phones and shiny discs.
garland: 💿,📀,📱,💾,✨,🦋,⭐,💽
corner: 💿,📟,📱,🎧,💾,🦋
hangers: 💿,⭐,🦋,✨,📀,💽
furniture: 🖥️,📼,🎧,📱,💿,🕹️
icons: 💿,📱,💾,🎧,🦋
acc: 🎧,💿,🦋,🕶️
amb: pad,musicbox,chimes
defaults: beads,neon,dotted,glitter,cluster
colors: E8E8F2,B6A4FF,7FDBFF,FF8AD8,9AA5B1
mood: frost,lilac,neon,pastel,dreamy,minimal
styles: beads,neonlights,dotted,glittery,clustered,sparkly,bubbly,hearty,tinsel,starry,bokehy,fairy
looks: Chrome Blob,Jelly Phone,Frosted Plastic,Disc Rainbow,Butterfly Clip,Translucent Purple,Millennium Bug,Dial-up Dream,MP3 Shine,Silver Star,Cyber Baby,Ice Blue Chrome,Pixel Sparkle,Pink Gadget,Holo Sticker,Mirror Ball,Pager Pastel,Glossy Lip,Techno Bubble,Clear Case,Glitter Gel,Webcam Glow,Screensaver,Liquid Metal,Year 2000

@holographic|Holographic|🔮|living|future
blurb: Shimmering rainbow surfaces and light that bends as you move.
garland: 🔮,✨,💎,🫧,🌈,💫,🪩,⭐
corner: 💎,🔮,🪩,✨,🌈,🫧
hangers: 💎,✨,🫧,🌈,💫,⭐
furniture: 🪩,💎,🔮,🫧,✨,🌈
icons: 🔮,💎,🌈,🪩,✨
acc: 💎,🪩,✨,🌈
amb: pad,harp,chimes
defaults: tinsel,neon,hairline,glitter,sunburst
colors: F3F0FF,A0E7E5,FBC2EB,B4F8C8,C7B8FF
mood: frost,pastel,dreamy,neon,lilac,minimal
styles: tinsel,neonlights,hairline,glittery,sunburst,sparkly,bokehy,beads,bubbly,starry,ribbons
looks: Rainbow Foil,Opal Sheen,Prism Light,Iridescent Wave,Holo Grid,Pearl Shift,Chrome Rainbow,Liquid Light,Glass Spectrum,Mirage,Aurora Foil,Unicorn Shine,Crystal Prism,Light Leak,Hologram Card,Spectral Mist,Oil Slick,Silver Spectrum,Dream Foil,Glow Gradient,Refraction,Pastel Prism,Mermaid Scale,Lens Shine,Rainbow Mirror

@digital_os|Digital Operating System|🖥️|living|future
blurb: Windows, folders and cursors: a cheerful desktop come to life.
garland: 🖥️,📁,🗂️,💾,🖱️,⌨️,📂,🔔
corner: 📁,🖥️,🗂️,💾,🖱️,📂
hangers: 📁,💾,🔔,📎,🖱️,📂
furniture: 🖥️,⌨️,🖱️,🗑️,📁,🖨️
icons: 🖥️,📁,💾,🖱️,⌨️
acc: 🖱️,💾,📁,⌨️
amb: chimes,pad,musicbox
defaults: flags,none,double,none,window
colors: C0C0C0,000080,008080,FFFFFF,FF0000
mood: minimal,classic,retro,frost,bold,teal
styles: flags,nolights,double,windowed,ornate,hairline,dotted,bunting,calm,clustered,confettied
looks: Classic Desktop,Teal Wallpaper,Start Menu,Folder Stack,Error Dialog,Dial-up Connect,Paint Program,Solitaire Win,Recycle Bin,Task Bar,Minesweeper,Screen Saver,Grey Bevel,Window Cascade,Pixel Cursor,Control Panel,Desktop Pets,Notepad,Defrag Blocks,Loading Bar,File Explorer,Dark Terminal,Icon Grid,Retro Mail,System Tray

@pixel_tech|Pixel Technology|👾|living|future
blurb: Chunky pixels, 8-bit sprites and blinking cursors.
garland: 👾,🕹️,🎮,⭐,💎,🪙,❤️,🍄
corner: 👾,🕹️,🎮,🪙,⭐,💎
hangers: 🪙,⭐,❤️,💎,👾,🍄
furniture: 🕹️,🎮,📺,👾,🪙,🏆
icons: 👾,🎮,🕹️,🪙,⭐
acc: 🎮,👾,🪙,⭐
amb: musicbox,chimes,pad
defaults: flags,bulbs,zigzag,confetti,frame
colors: 1B1B2F,FF4F79,45F0DF,FFE45E,7B61FF
mood: neon,bold,retro,midnight,kawaii,carnival
styles: flags,bulbs,zigzag,confettied,ornate,dotted,starry,sparkly,bunting,neonlights,double,clustered
looks: 8-bit Sunrise,Sprite Sheet,Arcade Pixels,Health Bar,Coin Block,Boss Level,Pixel Forest,Dungeon Map,Blinking Cursor,Retro Hero,Save Point,Power Up,Pixel Rain,Chiptune Night,Level Select,Space Invaders,Pixel Hearts,Low Res Sky,Bonus Stage,High Score,Tile Map,Pixel Castle,Game Over,Continue Screen,New Game Plus
@cottagecore|Traditional Cottagecore|🏡|living|cozy
blurb: Wildflowers, linen, baskets of bread and a garden gate left open.
garland: 🌼,🌿,🍓,🌸,🧺,🍯,🌾,🪻
corner: 🌼,🧺,🍓,🌿,🪻,🍯
hangers: 🌸,🌼,🍓,🌿,🐝,🦋
furniture: 🧺,🫖,🥖,🪴,🍯,🕯️
icons: 🏡,🌼,🧺,🍓,🌿
acc: 👒,🌼,🧺,🍓
amb: birds,stream,wind
defaults: vine,fairy,lace,petals,sprig
colors: FAF3E3,8BAE66,E8A0A9,C6893F,6B4F3A
mood: garden,folk,floral,rustic,pastel,classic
styles: vine,fairy,lace,petalfall,vined,bunting,flutter,wreathed,stitched,scallops,leafy
looks: Garden Gate,Linen Morning,Strawberry Field,Wildflower Meadow,Bread Basket,Honey Jar,Herb Window,Picnic Blanket,Lavender Rows,Daisy Chain,Apple Orchard,Sunlit Kitchen,Sewing Basket,Rose Trellis,Hen House,Butter Churn,Country Lane,Tea Garden,Clover Patch,Jam Making,Laundry Line,Rainy Porch,Pressed Flowers,Bee Garden,Golden Evening

@fairycore|Fairycore|🧚|living|cozy
blurb: Tiny wings, glowing mushrooms and dew-drop lanterns in the moss.
garland: 🧚,🍄,✨,🌸,🦋,🌿,🪷,💫
corner: 🍄,🧚,🌸,🦋,🌿,✨
hangers: ✨,🦋,🌸,💫,🍄,🌙
furniture: 🍄,🪷,🌿,🐌,🪺,🌸
icons: 🧚,🍄,🦋,✨,🌸
acc: 🧚,🦋,🌸,✨
amb: harp,stream,birds
defaults: vine,fairy,vine,fireflies,sprig
colors: F7F0FA,B9A3D9,A8D8B9,F6C1D6,6E8B5E
mood: dreamy,lilac,garden,pastel,moss,midnight
styles: vine,fairy,vined,glowing,flutter,sparkly,lace,petalfall,scallops,wreathed,bokehy
looks: Mushroom Ring,Dewdrop Lanterns,Moss Throne,Petal Wings,Moonlit Glade,Pixie Dust,Fern Hollow,Bluebell Dell,Glow Toadstools,Snail Parade,Thistle Crown,Acorn Cups,Spider Silk,Firefly Dance,Rose Hip Path,Willow Whisper,Clover Bridge,Fairy Market,Dandelion Wish,Twilight Wings,Lily Pond,Hollow Log,Crystal Dew,Wild Strawberry,Sleeping Fae

@forest_cottage|Forest Cottage|🌲|living|cozy
blurb: A little house among pines: woodsmoke, lanterns and soft moss.
garland: 🌲,🍂,🪵,🦊,🍄,🌿,🦉,🌰
corner: 🌲,🦊,🪵,🍄,🦉,🌿
hangers: 🍂,🌰,🦉,🌲,🍄,🪶
furniture: 🪵,🦊,🍄,🪓,🧺,🕯️
icons: 🌲,🦊,🦉,🍄,🪵
acc: 🧣,🦊,🍂,🍄
amb: fire,birds,wind
defaults: swag,lanterns,stitched,leaves,lantern
colors: E8DFC8,2F5233,8A5A2B,C46A2B,4F6D4A
mood: forest,woodland,rustic,cozy,moss,ember
styles: swag,lanterns,stitched,leafy,vined,candles,glowing,wreathed,chain,emojis,scroll,embers
looks: Pine Hollow,Woodsmoke,Fox Den,Lantern Path,Mossy Roof,Owl Watch,Acorn Pantry,Stone Hearth,Fern Floor,Morning Mist,Log Pile,Mushroom Cellar,Deer Trail,Rainy Pines,Woodcutter's Rest,Birch Window,Berry Patch,Cedar Chest,Quiet Clearing,Hearth Glow,Forest Tea,Bramble Gate,Old Oak,Twilight Cabin,First Frost

@mushroom_cottage|Mushroom Cottage|🍄|living|cozy
blurb: A round red-capped home, tiny doors and spotted lamps.
garland: 🍄,🌿,🐌,🌸,🍓,🐞,🌱,🪺
corner: 🍄,🐌,🐞,🌿,🪺,🌸
hangers: 🍄,🐞,🌸,🍓,🦋,🌿
furniture: 🍄,🐌,🪴,🧺,🍵,🪺
icons: 🍄,🐌,🐞,🌿,🍓
acc: 🍄,🐞,🐌,🌸
amb: birds,stream,musicbox
defaults: pompom,fairy,scallop,leaves,cluster
colors: F8EFE0,D7263D,FFFFFF,7A9E3E,6B4226
mood: rustic,garden,kawaii,woodland,pastel,storybook
styles: pompoms,fairy,scallops,leafy,clustered,dotted,vine,flutter,stitched,emojis,bunting,glowing
looks: Red Cap Home,Spotted Lamp,Tiny Door,Snail Mail,Toadstool Tea,Ladybug Garden,Moss Carpet,Morel Market,Porcini Pantry,Chanterelle Glow,Button Mushroom,Round Window,Rain Puddles,Spore Lights,Fairy Ring Porch,Berry Shelf,Root Cellar,Cap Chimney,Woodland Neighbors,Gilled Ceiling,Toad Visitor,Little Bridge,Puffball Hill,Mushroom Bakery,Nightcap Glow

@cozy_bedroom|Cozy Bedroom|🛏️|living|cozy
blurb: Soft blankets, string lights, a mug of something warm and a good book.
garland: 🕯️,⭐,🌙,🧸,📚,☕,🪴,💡
corner: 🛏️,🧸,🕯️,📚,🪴,☕
hangers: ⭐,🌙,💡,✨,🕯️,🌟
furniture: 🛏️,🧸,🪴,📚,☕,🕯️
icons: 🛏️,🧸,🕯️,🌙,☕
acc: 🧦,🧸,☕,🌙
amb: rain,fire,musicbox
defaults: beads,fairy,stitched,bokeh,cluster
colors: F6EDE3,D8A48F,8E7DBE,F2C57C,5B4B49
mood: cozy,pastel,dreamy,lilac,amber,midnight
styles: beads,fairy,stitched,bokehy,clustered,candles,pompoms,starry,lace,hearty,starlights,scallops
looks: String Light Canopy,Rainy Window Seat,Pillow Fort,Night Reading,Warm Mug,Knit Blanket,Plant Shelf,Lazy Sunday,Moon Lamp,Fluffy Rug,Candle Hour,Teddy Pile,Slipper Morning,Desk Corner,Lavender Sheets,Sleepy Cat,Fairy Light Headboard,Book Stack,Snow Outside,Midnight Snack,Sunbeam,Soft Pastels,Velvet Dusk,Cocoa Night,Dream Journal

@grandmothers_house|Grandmother's House|🫖|living|cozy
blurb: Lace doilies, floral china, a ticking clock and cookies in the tin.
garland: 🌹,🫖,🧶,🍪,🕰️,🪡,🌸,🎀
corner: 🫖,🧶,🕰️,🌹,🍪,🪞
hangers: 🌸,🌹,🎀,🧵,🗝️,🪡
furniture: 🪑,🕰️,🫖,🧶,🍪,🪴
icons: 🫖,🧶,🍪,🕰️,🌹
acc: 🧶,🫖,🎀,🍪
amb: fire,chimes,birds
defaults: swag,candles,lace,petals,frame
colors: F5EEE6,C27C8E,7A9C8C,D9B88F,6D4C41
mood: vintage,floral,elegant,rose,cozy,rustic
styles: swag,candles,lace,petalfall,ornate,ribboned,stitched,wreathed,scroll,double,scallops,vined
looks: Lace Doilies,Floral China,Ticking Clock,Cookie Tin,Knitting Chair,Rose Wallpaper,Sunday Roast,Photo Wall,Button Jar,Quilt Room,Piano Parlor,Garden Roses,Recipe Box,Sewing Room,Afternoon Tea,Velvet Couch,Porcelain Shelf,Jam Pantry,Lavender Drawer,Candy Dish,Radio Hour,Bird Feeder,Hall Mirror,Patchwork,Goodnight Kiss

@countryside|Countryside Living|🌾|living|cozy
blurb: Rolling fields, red barns, hay bales and long golden evenings.
garland: 🌾,🌻,🐄,🐓,🚜,🍎,🌽,🐑
corner: 🌾,🐄,🐓,🚜,🌻,🐑
hangers: 🌻,🍎,🌾,🐝,🦋,🐦
furniture: 🚜,🐄,🧺,🌾,🪣,🐑
icons: 🌾,🚜,🐄,🌻,🐓
acc: 👒,🌾,🌻,🐓
amb: birds,wind,stream
defaults: bunting,lanterns,stitched,leaves,cluster
colors: F6EBC9,C0392B,E1B941,6E8B3D,7B5B3A
mood: rustic,harvest,golden,folk,classic,sunset
styles: bunting,lanterns,stitched,leafy,clustered,flags,fairy,flutter,emojis,dotted,swag,sunburst
looks: Red Barn,Hay Bales,Golden Fields,Morning Chores,Sheep Pasture,Farm Stand,Tractor Path,Sunflower Row,Apple Harvest,Dairy Morning,Country Fair,Wheat Wind,Hen Yard,Fence Line,Pumpkin Rows,Windmill,Farmhouse Porch,Creek Crossing,Corn Maze,Evening Milking,Wildflower Verge,Barn Dance,Orchard Ladder,Haystack Sunset,Starry Field

@cozy_cafe|Cozy Café|☕|living|cozy
blurb: Steaming cups, chalkboard menus and pastries under warm lamps.
garland: ☕,🥐,🍰,🫖,🍪,🧁,🥧,🍩
corner: ☕,🥐,🍰,🫖,🧁,🪴
hangers: 💡,☕,🍩,🥐,🧁,⭐
furniture: ☕,🪑,🍰,🪴,🫖,🥐
icons: ☕,🥐,🍰,🫖,🧁
acc: ☕,🥐,🧁,🍪
amb: rain,chimes,fire
defaults: bunting,bulbs,stitched,bokeh,cluster
colors: F3E5D0,6F4E37,D8A47F,A7C4A0,3E2723
mood: cafe,cozy,amber,vintage,pastel,rustic
styles: bunting,bulbs,stitched,bokehy,clustered,scallops,flags,candles,dotted,beads,windowed,fairy
looks: Latte Art,Chalkboard Menu,Window Booth,Rainy Espresso,Croissant Counter,Matcha Corner,Cinnamon Morning,Book Café,Jazz Afternoon,Pour Over Bar,Cake Display,Mocha Night,Plant Café,Sidewalk Table,Biscotti Jar,Chai Lounge,Honey Latte,Barista Bench,Velvet Cup,Pastry Case,Cold Brew,Moka Pot,Neighborhood Spot,Tea Time,Last Order

@bakery|Bakery|🥖|living|cozy
blurb: Warm ovens, flour-dusted counters and trays of fresh bread.
garland: 🥖,🥐,🍞,🥨,🧁,🍰,🍪,🥧
corner: 🥖,🍞,🥐,🧁,🍰,🥧
hangers: 🥨,🥐,🍪,🧁,🍩,🎂
furniture: 🍞,🥖,🧺,🎂,🥧,🧁
icons: 🥖,🥐,🍞,🧁,🥧
acc: 👩‍🍳,🥐,🧁,🥖
amb: fire,chimes,birds
defaults: bunting,bulbs,scallop,none,cluster
colors: FBF1E2,C68B59,F2C6B4,8C5A3C,E9D8A6
mood: harvest,cafe,pastel,rustic,sweet,golden
styles: bunting,bulbs,scallops,clustered,stitched,flags,dotted,calm,pompoms,beads,windowed,lace
looks: Morning Ovens,Flour Counter,Sourdough Shelf,Croissant Tray,Cupcake Window,Pretzel Stand,Pie Cooling,Baguette Basket,Cinnamon Rolls,Birthday Cakes,Macaron Pastel,Rye and Seeds,Donut Case,Bread Board,Honey Buns,Cookie Jar,Rolling Pin,Brioche Gold,Fruit Tarts,Proofing Room,Wedding Cake,Sugar Dust,Night Bakers,Village Bakery,Sweet Shop

@bookshop|Bookshop|📖|living|cozy
blurb: Crooked stacks, ladders, a shop cat and the smell of old paper.
garland: 📚,📖,🔖,🕯️,🪶,📜,🐈,☕
corner: 📚,🐈,🕯️,📖,🪴,🔖
hangers: 🔖,📜,🪶,⭐,🕯️,💡
furniture: 📚,🪑,🐈,☕,🪴,🕰️
icons: 📖,📚,🔖,🐈,🪶
acc: 👓,📖,🔖,🐈
amb: rain,fire,chimes
defaults: chain,lanterns,double,none,scroll
colors: EFE4D2,7B3F2A,2E5E4E,C9A227,3B2F2F
mood: vintage,amber,storybook,cafe,elegant,forest
styles: chain,lanterns,double,scroll,stitched,calm,candles,windowed,dotted,ornate,bulbs,leafy
looks: Crooked Stacks,Rolling Ladder,Shop Cat,Rare Books,Poetry Corner,Map Room,Window Display,Mystery Shelf,Rainy Browse,Children's Nook,Second Hand,Reading Chair,Bookmark Counter,Antique Atlas,Tea and Pages,Green Lamp,Lost Chapter,Signed Copies,Attic Books,Story Hour,Leather Spines,Night Owl Hours,Book Fort,Typewriter Desk,Closing Time
@classroom|Classic Classroom|🏫|living|academic
blurb: Chalkboards, apples on the desk, gold stars and alphabet borders.
garland: 🍎,✏️,📏,⭐,🔤,🖍️,📚,🔔
corner: 🍎,📚,✏️,🖍️,🔔,🌍
hangers: ⭐,🍎,✏️,🔤,🔔,📌
furniture: 🎒,📚,🌍,🍎,🪴,🧮
icons: 🏫,🍎,✏️,📚,🔔
acc: 🎒,✏️,🍎,⭐
amb: chimes,birds,pad
defaults: flags,none,dotted,none,frame
colors: F7F3E8,C0392B,2E7D32,F4C430,1F3A5F
mood: classic,paper,bold,folk,sky,minimal
styles: flags,nolights,dotted,ornate,bunting,stitched,clustered,double,calm,confettied,starry,windowed
looks: Chalkboard Green,Apple for Teacher,Gold Stars,Alphabet Border,Pencil Cup,Reading Rug,Globe Corner,Morning Bell,Science Fair,Spelling Bee,Art Hour,Bulletin Board,Show and Tell,Recess Sun,Lunch Box,Field Trip,Class Pet,Math Day,Library Cart,Report Card,Pop Quiz,Crayon Box,Story Time,First Day,Last Day

@school_notebook|School Notebook|📓|living|academic
blurb: Ruled lines, margin doodles, sticky notes and paper clips.
garland: 📎,📝,✏️,🖊️,📌,🗒️,⭐,💯
corner: 📓,📎,📌,🗒️,✏️,🖍️
hangers: 📌,📎,⭐,✏️,💯,📝
furniture: 📓,🖊️,✏️,🗒️,📐,🖍️
icons: 📓,✏️,📎,📝,📌
acc: ✏️,📎,📝,⭐
amb: chimes,rain,pad
defaults: flags,none,dotted,none,ribbon
colors: FFFFFF,4A6FA5,E26D5C,F6D55C,9BBF6B
mood: paper,minimal,pastel,classic,sky,bold
styles: flags,nolights,dotted,ribboned,stitched,bunting,clustered,hairline,confettied,calm,double,scallops
looks: Ruled Lines,Margin Doodles,Sticky Notes,Paper Clips,Graph Paper,Highlighter Pop,Spiral Bound,Gel Pen Pastel,Composition Book,Doodle Stars,Index Cards,Torn Page,Planner Spread,Washi Strip,Homework Night,Exam Notes,Blue Ink,Red Corrections,Folded Note,Bullet Journal,Pencil Shavings,Sketch Margin,Cornell Notes,Tab Dividers,Final Page

@dark_academia|Dark Academia|🕯️|living|academic
blurb: Candlelit libraries, tweed, ink and old stone halls.
garland: 🕯️,📜,🪶,🗝️,📚,🥀,🍂,☕
corner: 📚,🕯️,🪶,🗝️,🥀,💀
hangers: 🍂,🗝️,🕯️,🪶,📜,🥀
furniture: 📚,🕯️,☕,🪑,🎻,🕰️
icons: 🕯️,📚,🪶,🗝️,🥀
acc: 🎩,🪶,📜,🕯️
amb: rain,fire,night
defaults: swag,candles,ornate,leaves,scroll
colors: 1E1A17,5C3D2E,8B6F47,C9B79C,3E4A3D
mood: gothic,amber,vintage,ember,forest,elegant
styles: swag,candles,ornate,leafy,scroll,double,lace,embers,wreathed,chain,raining,windowed
looks: Candlelit Library,Tweed and Ink,Stone Halls,Latin Notes,Midnight Essay,Rain on Glass,Old Chapel,Raven Study,Wax Seal,Leather Satchel,Autumn Quad,Greek Tragedy,Lecture Hall,Fountain Pen,Secret Society,Dusty Portraits,Clock Tower,Coffee and Keats,Burgundy Velvet,Classics Room,Cloister Walk,Pressed Leaves,Ink Stains,Midnight Bell,Final Thesis

@light_academia|Light Academia|🏛️|living|academic
blurb: Sunlit columns, linen pages, poetry and soft cream tones.
garland: 📖,🌿,🏛️,🪶,🌸,☕,📜,🎻
corner: 🏛️,📖,🌿,🪶,🎻,🌸
hangers: 🌿,🪶,🌸,📜,🕊️,✨
furniture: 📚,☕,🏛️,🪴,🎻,🖼️
icons: 🏛️,📖,🪶,🌿,🎻
acc: 📖,🪶,🌿,☕
amb: birds,harp,stream
defaults: vine,fairy,lace,petals,frame
colors: FBF6EE,D8C3A5,A3B18A,E9D8C4,8D7B68
mood: elegant,minimal,paper,garden,golden,classic
styles: vine,fairy,lace,petalfall,ornate,vined,scroll,hairline,ribboned,calm,double,flutter
looks: Sunlit Columns,Linen Pages,Poetry Garden,Marble Steps,Morning Lecture,Olive Branch,Cream Notebook,Gallery Walk,Sonnet Hour,Library Window,Greek Statues,Ivory Desk,Spring Quad,Tea and Plato,Lyre Song,Rose Archive,Botanical Notes,Study Abroad,Sunday Museum,Watercolor Class,Pastoral Reading,Golden Hour Notes,Whitewashed Hall,Ink and Light,Graduation Morning

@romantic_academia|Romantic Academia|🌹|living|academic
blurb: Love letters, rose petals, sonnets and candlelit music rooms.
garland: 🌹,💌,🪶,🎻,🕯️,📜,🥀,🎀
corner: 🌹,💌,🎻,🕯️,🪶,🥀
hangers: 🌹,💌,🎀,🕯️,🪶,✨
furniture: 🎻,🌹,📚,🕯️,🖼️,🪞
icons: 🌹,💌,🎻,🪶,🕯️
acc: 🌹,🎀,💌,🪶
amb: harp,fire,musicbox
defaults: ribbon,candles,lace,petals,frame
colors: F8EDEB,9D2B48,D4A5A5,C9A227,4A2C2A
mood: rose,elegant,vintage,gothic,blossom,lilac
styles: ribbons,candles,lace,petalfall,ornate,ribboned,hearty,swag,scroll,wreathed,double,bokehy
looks: Love Letters,Rose Petals,Sonnet Room,Candlelit Music,Pressed Rose,Velvet Ribbon,Moonlit Balcony,Wax Seal Heart,Violin Serenade,Poet's Garden,Lace Gloves,Ballroom Notes,Opera Night,Secret Admirer,Portrait Gallery,Ink and Roses,Chamber Music,Rainy Romance,Gilded Mirror,Midnight Waltz,Forget-me-nots,Byron's Desk,Starlit Promise,Locket,Last Dance

@art_classroom|Art Classroom|🎨|living|academic
blurb: Paint splatters, easels, clay pots and drying artwork on a string.
garland: 🎨,🖌️,🖍️,✂️,🖼️,🌈,📎,⭐
corner: 🎨,🖌️,🖼️,🖍️,✂️,🏺
hangers: 🖼️,🎨,🌈,⭐,🖌️,📎
furniture: 🎨,🏺,🖼️,🪴,🖌️,🧶
icons: 🎨,🖌️,🖍️,🖼️,🌈
acc: 🎨,🖌️,🧑‍🎨,🌈
amb: chimes,birds,musicbox
defaults: bunting,none,zigzag,confetti,cluster
colors: FFFBF2,E63946,F4A261,2A9D8F,6A4C93
mood: whimsical,bold,watercolor,paper,carnival,pastel
styles: bunting,nolights,zigzag,confettied,clustered,flags,dotted,pompoms,stitched,emojis,streamers,sparkly
looks: Paint Splatter,Easel Row,Clay Pots,Drying Line,Colour Wheel,Crayon Rainbow,Collage Table,Watercolor Wash,Pottery Wheel,Sketch Day,Gallery Wall,Glitter Glue,Finger Paint,Still Life,Printmaking,Chalk Pastels,Origami Corner,Mosaic Tiles,Paper Mache,Portrait Hour,Studio Window,Art Show,Messy Smocks,Charcoal Study,Mural Wall

@music_classroom|Music Classroom|🎼|living|academic
blurb: Music stands, practice rooms, metronomes and notes on the board.
garland: 🎵,🎶,🎼,🎹,🎻,🥁,🎺,🎷
corner: 🎹,🎻,🥁,🎼,🎺,🎷
hangers: 🎵,🎶,🎼,⭐,🔔,🎵
furniture: 🎹,🥁,🎻,🎸,🪕,🎺
icons: 🎼,🎵,🎹,🎻,🥁
acc: 🎵,🎻,🎹,🎶
amb: musicbox,harp,chimes
defaults: beads,none,dotted,none,frame
colors: FFF8EC,1D3557,E63946,F1C453,457B9D
mood: classic,midnight,bold,elegant,retro,paper
styles: beads,nolights,dotted,ornate,bunting,clustered,double,starry,flags,calm,stitched,sparkly
looks: Music Stands,Practice Room,Metronome,Note Board,Recorder Day,Orchestra Pit,Choir Risers,Piano Lesson,Drum Circle,Treble Clef,Sheet Music,Band Room,Theory Class,Spring Concert,Ukulele Club,Bell Choir,Rhythm Sticks,Solfege Wall,Brass Section,String Quartet,Composer Portraits,Music Library,Tuning Fork,Recital Night,Encore

@science_lab|Science Laboratory|🔬|living|academic
blurb: Beakers, periodic tables, microscopes and a model of the solar system.
garland: 🧪,⚗️,🔬,🧬,⚛️,🧫,🌡️,🧲
corner: 🔬,🧪,⚗️,🧬,🦠,🧲
hangers: ⚛️,🧪,🧬,🌡️,💡,🔋
furniture: 🔬,🧪,🌍,🦴,🧫,🪴
icons: 🔬,🧪,⚛️,🧬,🧲
acc: 🥽,🧪,🔬,🧬
amb: chimes,pad,stream
defaults: chain,bulbs,double,bubbles,frame
colors: F2F7F5,2A9D8F,264653,E9C46A,E76F51
mood: classic,teal,minimal,bold,frost,jade
styles: chain,bulbs,double,bubbly,ornate,dotted,hairline,clustered,sparkly,windowed,neonlights,calm
looks: Beaker Row,Periodic Table,Microscope Bench,Solar Model,Fossil Shelf,Chemistry Day,Volcano Project,Magnet Lab,Plant Biology,Bunsen Burner,Skeleton Corner,Weather Station,Electricity Lab,Rock Collection,Dissection Tray,Bubble Test,DNA Model,Lab Notebook,Safety Goggles,Physics Pendulum,Field Samples,Petri Garden,Space Science,Eureka Moment,Science Fair Ribbon

@university_library|University Library|🏛️|living|academic
blurb: Vaulted reading rooms, green lamps, long oak tables and quiet.
garland: 📚,📖,💡,🕰️,🏛️,📜,🔖,🖋️
corner: 📚,💡,🏛️,🕰️,📜,🖋️
hangers: 💡,🔖,📜,🕰️,🗝️,⭐
furniture: 📚,💡,🪑,🕰️,🌍,🪴
icons: 🏛️,📚,💡,📖,🖋️
acc: 👓,📚,🖋️,🔖
amb: rain,chimes,fire
defaults: chain,lanterns,double,none,scroll
colors: EDE6D6,2F4F3A,8B5E34,D4AF37,3C2F2F
mood: vintage,forest,elegant,amber,classic,storybook
styles: chain,lanterns,double,scroll,ornate,calm,candles,windowed,dotted,hairline,stitched,wreathed
looks: Vaulted Reading Room,Green Lamps,Oak Tables,Silent Floor,Archive Stacks,Card Catalog,Study Carrel,Rotunda,Rare Manuscripts,Finals Week,Map Collection,Periodicals,Spiral Staircase,Night Study,Microfilm,Graduate Lounge,Law Library,Reference Desk,Atrium Light,Quiet Zone,Thesis Shelf,Window Alcove,Book Return,Gallery Level,Lights Out

@study_cafe|Study Café|📝|living|academic
blurb: Laptops, iced coffee, highlighters and lo-fi on low.
garland: ☕,📝,💻,🎧,📚,🧋,🖊️,🥐
corner: ☕,💻,🎧,📚,🪴,🧋
hangers: 💡,🎧,☕,📝,⭐,🧋
furniture: 💻,☕,🪴,📚,🧋,🥐
icons: 📝,☕,💻,🎧,🧋
acc: 🎧,☕,📝,🧋
amb: rain,pad,chimes
defaults: bunting,bulbs,stitched,bokeh,cluster
colors: F4EDE4,6B4F3A,9CB4A8,E8B4B8,2F3E46
mood: cafe,pastel,minimal,amber,teal,cozy
styles: bunting,bulbs,stitched,bokehy,clustered,dotted,raining,candles,flags,calm,windowed,fairy
looks: Lo-fi Desk,Iced Coffee,Highlighter Set,Laptop Corner,Rainy Study,Matcha Notes,Window Seat,Group Project,Pomodoro,Headphones On,Bubble Tea Break,Flashcards,Plant Table,Exam Prep,Late Night Latte,Cozy Booth,Sunlight Study,Mind Map,Notebook Stack,Typing Away,Study Buddy,Quiet Hours,Cinnamon Focus,Deadline Night,Done for Today
@rainforest|Rainforest|🌴|living|nature
blurb: Dripping leaves, hanging vines, toucans and a warm green hush.
garland: 🌿,🍃,🦜,🌺,🐸,🦋,🌴,🐒
corner: 🌴,🦜,🌺,🐸,🌿,🐒
hangers: 🌿,🦋,🦜,🍃,🐍,🌺
furniture: 🌴,🐸,🦥,🌺,🪵,🐆
icons: 🌴,🦜,🐸,🌺,🦋
acc: 🦜,🌺,🐸,🌿
amb: rain,birds,stream
defaults: vine,none,vine,rain,sprig
colors: 0F3D2E,2E8B57,7CC576,F2A541,D7263D
mood: forest,jade,tropical,moss,garden,midnight
styles: vine,nolights,vined,raining,flutter,leafy,emojis,glowing,swag,clustered,wreathed,bubbly
looks: Canopy Mist,Toucan Perch,Waterfall Pool,Orchid Vines,Frog Chorus,Morning Drizzle,Jaguar Trail,Fern Floor,Sloth Branch,Butterfly Clearing,Kapok Tree,Emerald Shade,River Bend,Hummingbird,Monkey Bridge,Night Calls,Bromeliad,Giant Leaves,Steamy Air,Hidden Temple,Parrot Flock,Blue Morpho,Moss Roots,Storm Season,Sunlit Gap

@tropical_island|Tropical Island|🏝️|living|nature
blurb: White sand, palm shade, coconuts and turquoise water.
garland: 🌺,🥥,🌴,🍍,🐚,🌊,☀️,🦩
corner: 🌴,🍍,🐚,🌺,🦩,🥥
hangers: 🌺,🐚,🥥,☀️,🦜,🌸
furniture: 🏖️,🍹,🌴,🐢,🐚,🛶
icons: 🏝️,🌴,🌺,🍍,🐚
acc: 🌺,🕶️,🍹,🐚
amb: waves,birds,wind
defaults: bunting,lanterns,scallop,petals,cluster
colors: FFF4D6,0FB5AE,FF6F59,FFD23F,2B9348
mood: tropical,ocean,sunset,sky,whimsical,bold
styles: bunting,lanterns,scallops,petalfall,clustered,flags,bubbly,emojis,fairy,sunburst,confettied,flutter
looks: White Sand,Palm Shade,Coconut Grove,Turquoise Lagoon,Hammock Day,Pineapple Party,Flamingo Beach,Tiki Torches,Sunset Shack,Shell Collection,Surf Morning,Island Market,Hibiscus Path,Sea Turtle Cove,Banana Leaf,Outrigger,Rainbow Reef,Mango Season,Volcano View,Beach Bonfire,Coral Bay,Lazy Afternoon,Driftwood,Tropical Storm,Starlit Beach

@deep_ocean|Deep Ocean|🐋|living|nature
blurb: Dark blue depths, drifting jellyfish and glowing creatures.
garland: 🐋,🪼,🐙,🦑,🐟,🫧,🦈,🐡
corner: 🐙,🦑,🪼,🐋,🦈,🫧
hangers: 🪼,🫧,🐟,🦑,🐠,✨
furniture: 🐙,⚓,🪸,🐚,🦀,🚢
icons: 🐋,🐙,🪼,🦑,🦈
acc: 🐙,🪼,⚓,🫧
amb: waves,pad,stream
defaults: beads,none,scallop,bubbles,cluster
colors: 03111F,0B4F6C,01BAEF,20BF55,FBFBFF
mood: ocean,midnight,teal,indigo,neon,gothic
styles: beads,nolights,scallops,bubbly,clustered,glowing,bokehy,hairline,dotted,sparkly,chain,starry
looks: Midnight Zone,Jellyfish Drift,Whale Fall,Anglerfish Light,Sunken Ship,Kraken Lair,Glow Squid,Abyssal Plain,Hydrothermal Vent,Sperm Whale Song,Bubble Column,Blue Hole,Sea Snow,Trench Explorer,Octopus Garden,Shark Patrol,Submarine Window,Lantern Fish,Pressure Deep,Ghost Net,Pearl Diver,Ocean Floor,Siphonophore,Silent Depths,Deep Blue

@coral_reef|Coral Reef|🪸|living|nature
blurb: Bright coral, schools of fish, sea turtles and sunlight rays.
garland: 🐠,🐟,🪸,🐢,🐡,🦀,🐚,🫧
corner: 🪸,🐠,🐢,🐚,🦀,🐙
hangers: 🐠,🫧,🐟,🐡,🪼,🐚
furniture: 🪸,🐢,🦀,🐚,🐙,⚓
icons: 🪸,🐠,🐢,🐡,🦀
acc: 🐠,🐚,🤿,🫧
amb: waves,stream,harp
defaults: beads,none,scallop,bubbles,cluster
colors: E8F8F5,FF6B6B,0FA3B1,FFD166,8338EC
mood: ocean,tropical,whimsical,teal,pastel,bold
styles: beads,nolights,scallops,bubbly,clustered,emojis,sparkly,flutter,dotted,bokehy,ribbons,confettied
looks: Brain Coral,Clownfish Home,Turtle Cruise,Sunbeam Shallows,Parrotfish,Sea Fan,Angelfish School,Anemone Garden,Reef Edge,Seahorse Hide,Moray Den,Butterflyfish,Starfish Sand,Kelp Border,Cleaning Station,Lionfish,Blue Tang,Giant Clam,Pink Coral,Reef Night,Manta Pass,Snorkel Day,Coral Nursery,Lagoon Life,Rainbow Reef

@mountains|Mountain Landscape|🏔️|living|nature
blurb: Snowy peaks, pine slopes, alpine lakes and clear thin air.
garland: 🏔️,🌲,🦅,❄️,⛺,🌄,🐐,🪨
corner: 🏔️,🌲,⛺,🦅,🪨,🐐
hangers: ❄️,🦅,🌲,⭐,☁️,🌙
furniture: ⛺,🌲,🪨,🔥,🐐,🎒
icons: 🏔️,🌲,🦅,⛺,🌄
acc: 🎒,🧣,⛺,🏔️
amb: wind,stream,birds
defaults: chain,none,zigzag,snow,cluster
colors: EEF3F7,3D5A80,98C1D9,293241,E0FBFC
mood: frost,forest,sky,midnight,minimal,classic
styles: chain,nolights,zigzag,snowing,clustered,hairline,starry,cloudy,leafy,stitched,windowed,calm
looks: Snowy Peaks,Alpine Lake,Pine Slopes,Summit Sunrise,Base Camp,Glacier Blue,Eagle Ridge,Mountain Hut,Wildflower Meadow,Rocky Pass,Cloud Line,Ski Lodge,Goat Trail,Misty Valley,Fire Lookout,Switchbacks,Starry Camp,Avalanche Quiet,Larch Gold,Moraine,Cable Car,Hot Springs,High Desert Peaks,Granite Wall,Evening Alpenglow

@desert|Desert|🏜️|living|nature
blurb: Rolling dunes, cacti in bloom, warm stone and huge night skies.
garland: 🌵,🏜️,☀️,🦎,🐪,🌙,⭐,🌺
corner: 🌵,🐪,🦎,🏜️,🪨,☀️
hangers: ☀️,🌙,⭐,🦅,🌵,✨
furniture: 🌵,🐪,🪨,🏺,🦂,⛺
icons: 🏜️,🌵,🐪,🦎,☀️
acc: 🤠,🌵,🕶️,🦎
amb: wind,night,pad
defaults: tassels,lanterns,zigzag,embers,sunburst
colors: F6E3C5,D98E4A,B5523B,3FA7A0,5A3E2B
mood: desert,sunset,amber,midnight,harvest,ember
styles: tassels,lanterns,zigzag,embers,sunburst,starry,flags,beads,clustered,nolights,dotted,stitched
looks: Rolling Dunes,Cactus Bloom,Red Canyon,Oasis Palms,Caravan Trail,Sandstone Arch,Night Sky Camp,Mesa Sunset,Salt Flats,Adobe House,Painted Hills,Tumbleweed,Lizard Rock,Desert Rain,Sand Rose,Dune Shadows,Golden Hour,Ghost Town,Saguaro Grove,Moonlit Sand,Hot Springs,Turquoise Market,Wind Carved,Cliff Dwelling,Desert Stars

@savannah|Savannah|🦒|living|nature
blurb: Golden grasses, acacia trees, giraffes and a wide orange sunset.
garland: 🦒,🦓,🐘,🦁,🌳,☀️,🌾,🦩
corner: 🌳,🦒,🐘,🦓,🦁,🌾
hangers: ☀️,🦅,🌾,🦩,🌙,⭐
furniture: 🐘,🦒,🌳,🦓,🪨,🦏
icons: 🦒,🐘,🦁,🦓,🌳
acc: 🦒,🦁,🌾,☀️
amb: wind,birds,night
defaults: tassels,none,zigzag,leaves,sunburst
colors: F8E1B4,E07A1F,9C6B30,5B7F3A,2D2A26
mood: harvest,sunset,desert,golden,ember,rustic
styles: tassels,nolights,zigzag,leafy,sunburst,flags,beads,clustered,stitched,emojis,starry,dotted
looks: Golden Grass,Acacia Shade,Giraffe Walk,Elephant Herd,Lion Pride,Zebra Crossing,Watering Hole,Orange Sunset,Great Migration,Baobab Tree,Termite Mound,Dry Season,Rainy Season,Flamingo Lake,Rhino Path,Cheetah Run,Tall Grass,Dusty Morning,Starlit Plains,Hornbill,Wildebeest,Kopje Rocks,Savannah Storm,Hippo Pool,Last Light

@wetlands|Wetlands|🐸|living|nature
blurb: Reeds, lily pads, herons and soft mist over still water.
garland: 🐸,🪷,🦆,🌾,🐢,🦢,🍃,🐟
corner: 🪷,🐸,🦆,🌾,🦢,🐢
hangers: 🦋,🌾,🐦,🍃,🪷,🦟
furniture: 🪷,🐸,🦆,🛶,🐢,🪵
icons: 🐸,🪷,🦆,🦢,🌾
acc: 🐸,🪷,🦆,🌾
amb: stream,birds,rain
defaults: vine,fairy,vine,fireflies,sprig
colors: E7EFE3,4F7942,8FB996,A7C4D6,5D4E3A
mood: moss,monsoon,garden,jade,forest,teal
styles: vine,fairy,vined,glowing,leafy,raining,flutter,cloudy,emojis,clustered,calm,bubbly
looks: Reed Bed,Lily Pads,Heron Watch,Morning Mist,Frog Pond,Duck Family,Cattail Path,Boardwalk,Turtle Log,Dragonfly Hour,Swan Lake,Marsh Sunset,Mangrove Roots,Peat Bog,Kingfisher,Willow Bank,Rain Puddles,Firefly Marsh,Lotus Bloom,Canoe Trail,Bayou Night,Moss Hollow,Water Lilies,Fog Bank,Spring Chorus

@botanical_garden|Botanical Garden|🌺|living|nature
blurb: Glasshouses, labelled beds, exotic blooms and winding paths.
garland: 🌺,🌸,🌷,🌹,🌻,🌼,🪷,🌿
corner: 🌺,🌹,🌷,🪴,🌿,🌸
hangers: 🌸,🌺,🦋,🐝,🌷,🍃
furniture: 🪴,🌵,🌳,🪻,🌺,🧺
icons: 🌺,🌷,🌹,🪴,🌻
acc: 👒,🌸,🌷,🦋
amb: birds,stream,harp
defaults: vine,fairy,vine,petals,sprig
colors: F5F9F1,3C8D5A,E94F64,F7B32B,8E6BB0
mood: garden,floral,blossom,jade,classic,whimsical
styles: vine,fairy,vined,petalfall,flutter,wreathed,leafy,emojis,lace,scallops,clustered,bunting
looks: Victorian Glasshouse,Rose Garden,Tulip Beds,Cactus House,Orchid Room,Water Garden,Herb Spiral,Japanese Maples,Fern Grotto,Palm House,Wildflower Border,Lily Pond,Peony Walk,Succulent Wall,Wisteria Arch,Lavender Field,Seed Bank,Sunflower Maze,Bonsai Collection,Magnolia Path,Carnivorous Plants,Butterfly House,Hedge Garden,Bluebell Woods,Night Bloom

@bamboo_forest|Bamboo Forest|🎋|living|nature
blurb: Tall green stalks, filtered light, a stone path and a gentle breeze.
garland: 🎋,🍃,🎍,🐼,🪨,🌿,🏮,🍵
corner: 🎋,🐼,🪨,🏮,🍃,🎍
hangers: 🍃,🎐,🏮,🌙,🍂,🐦
furniture: 🎋,🐼,🪨,🍵,🏮,🪴
icons: 🎋,🐼,🍃,🏮,🍵
acc: 🐼,🎋,🍵,🍃
amb: wind,stream,chimes
defaults: vine,lanterns,hairline,leaves,lantern
colors: EEF5E9,4C8C4A,A6C48A,2F3E2F,C9B27C
mood: jade,moss,forest,minimal,garden,midnight
styles: vine,lanterns,hairline,leafy,calm,vined,nolights,glowing,stitched,raining,clustered,windowed
looks: Tall Stalks,Filtered Light,Stone Path,Panda Grove,Wind Rustle,Morning Dew,Tea House,Lantern Walk,Koi Stream,Moss Stones,Rain Drops,Moonlit Grove,Wind Chimes,Bamboo Bridge,Zen Garden,Misty Hill,Shrine Gate,Sparrow Song,Golden Bamboo,Quiet Path,Green Tunnel,Hidden Pond,Calligraphy,Evening Breeze,Temple Bell
@grunge|Grunge|🎸|living|artistic
blurb: Flannel, torn posters, safety pins and fuzzy guitar amps.
garland: 🎸,⛓️,🧷,💿,📼,🩹,🖤,⚡
corner: 🎸,⛓️,🧷,📼,🩹,🥀
hangers: ⛓️,🧷,⚡,🖤,💿,🩹
furniture: 🎸,🔊,📼,🛹,💿,🪴
icons: 🎸,⛓️,🧷,📼,🖤
acc: 🎸,🧷,⛓️,🖤
amb: rain,storm,wind
defaults: chain,neon,stitched,rain,frame
colors: 2B2A28,6B705C,A5494C,C9B79C,1C1C1C
mood: gothic,ember,moss,midnight,vintage,amber
styles: chain,neonlights,stitched,raining,ornate,zigzag,dotted,embers,tassels,nolights,clustered,hairline
looks: Flannel Shirt,Torn Posters,Safety Pins,Fuzzy Amp,Garage Band,Rainy Seattle,Ripped Denim,Coffee Stains,Thrift Store,Mixtape,Bedroom Show,Smudged Liner,Combat Boots,Static Noise,Photocopy Zine,Basement Gig,Broken Strings,Overcast,Skate Park,Faded Band Tee,Cigarette Burn,Grey Day,Scratched CD,Loud Quiet Loud,Last Song

@punk|Punk|🤘|living|artistic
blurb: Spikes, studs, DIY zines, plaid and loud bright colour.
garland: ⚡,🤘,⛓️,💀,🧷,⭐,🔥,💥
corner: 💀,⛓️,🧷,⚡,🤘,💥
hangers: ⚡,⭐,⛓️,💀,🧷,🔥
furniture: 🎸,🔊,🛹,🥁,📢,🎤
icons: 🤘,⚡,💀,⛓️,🧷
acc: 🤘,🧷,⛓️,⚡
amb: storm,rain,wind
defaults: chain,neon,zigzag,confetti,frame
colors: 111111,FF006E,FFBE0B,3A86FF,F5F5F5
mood: neon,bold,gothic,midnight,carnival
styles: chain,neonlights,zigzag,confettied,ornate,stitched,flags,starry,dotted,tassels,embers,bunting
looks: Spikes and Studs,DIY Zine,Plaid Patch,Mohawk Pink,Safety Pin Jacket,Basement Show,Riot Yellow,Cut and Paste,Leather Vest,Neon Graffiti,Stage Dive,Record Sleeve,Anarchy Red,Skate Ramp,Sticker Bomb,Bleach Splatter,Fanzine Press,Electric Blue,Mosh Pit,Chain Wallet,Band Flyer,Tartan Night,Spray Can,Pogo Party,Encore Noise

@gothic|Gothic|🦇|living|artistic
blurb: Velvet, black lace, candelabras, ravens and cathedral windows.
garland: 🦇,🕯️,🥀,🕸️,🖤,🗝️,🌑,💀
corner: 🕯️,🥀,🦇,🕸️,🗝️,🏰
hangers: 🦇,🕸️,🌑,🥀,🗝️,🖤
furniture: 🕯️,🪞,⚰️,🥀,📚,🏰
icons: 🦇,🥀,🕯️,🖤,🕸️
acc: 🦇,🖤,🥀,🗝️
amb: night,wind,harp
defaults: swag,candles,lace,petals,window
colors: 0D0B10,4B1D3F,8E1B2E,BFA5C9,2B2B2B
mood: gothic,midnight,rose,lilac,indigo
styles: swag,candles,lace,petalfall,windowed,ornate,starry,scroll,wreathed,double,ribboned,tassels
looks: Black Velvet,Raven Window,Candelabra,Cathedral Glass,Rose and Thorn,Moonlit Crypt,Lace Veil,Bat Belfry,Midnight Garden,Iron Gates,Blood Moon,Silver Locket,Haunted Organ,Ivy Ruins,Mourning Jewels,Spider Silk,Velvet Chair,Gargoyle Ledge,Dark Romance,Obsidian Mirror,Nightshade,Crimson Drapes,Abbey Ruins,Raven Feather,Eternal Night

@victorian|Victorian|🎩|living|artistic
blurb: Damask wallpaper, brass gaslights, teacups and pressed flowers.
garland: 🎩,🌹,🫖,🕰️,🪶,🎀,🗝️,📜
corner: 🕰️,🫖,🌹,🪞,🎩,🗝️
hangers: 🌹,🎀,🗝️,🪶,🕯️,🌸
furniture: 🪑,🕰️,🫖,🪞,🎹,🖼️
icons: 🎩,🫖,🕰️,🌹,🪞
acc: 🎩,🎀,🌹,🪶
amb: fire,chimes,harp
defaults: swag,lanterns,ornate,petals,frame
colors: F1E6D6,5E2129,2F4F4F,C9A227,7A6B5D
mood: vintage,elegant,rose,amber,gothic,storybook
styles: swag,lanterns,ornate,petalfall,scroll,ribboned,lace,double,candles,wreathed,tassels,fans
looks: Damask Parlour,Gaslight,Tea Service,Pressed Flowers,Brass Clock,Velvet Drapes,Conservatory,Calling Cards,Music Box,Lace Collar,Carriage Ride,Library Study,Portrait Hall,Garden Party,Fainting Couch,Cameo Brooch,Steam Train,Curio Cabinet,Rose Parlour,Christmas Card,Top Hat,Writing Desk,Butterfly Collection,Ballroom,Fog Street

@rococo|Rococo|🪭|living|artistic
blurb: Pastel silk, gilded curls, fans, bows and sugared sweets.
garland: 🎀,🌸,🪭,🍰,💎,🌹,🦢,🕊️
corner: 🪭,🎀,🌸,🍰,🪞,🦢
hangers: 🎀,🌸,💎,🕊️,🌹,✨
furniture: 🪞,🍰,🪑,🫖,🎂,🦢
icons: 🪭,🎀,🍰,🌸,🦢
acc: 🎀,🪭,👑,🌸
amb: harp,musicbox,chimes
defaults: ribbon,candles,lace,petals,fan
colors: FFF4F2,F7C5CC,BFE3DE,D4AF37,C8A2C8
mood: pastel,blossom,dreamy,golden,lilac,elegant
styles: ribbons,candles,lace,petalfall,fans,ribboned,ornate,swag,scallops,hearty,sparkly,wreathed
looks: Pastel Silk,Gilded Curls,Fan Parlour,Sugar Bows,Garden Swing,Porcelain Shepherdess,Mint Salon,Cherub Ceiling,Macaron Tower,Rose Boudoir,Pearl Mirror,Masquerade,Feathered Hat,Lilac Gallery,Golden Clock,Painted Fan,Shell Grotto,Ribbon Dance,Champagne Pink,Petit Palace,Candlelit Salon,Powdered Wig,Pleasure Garden,Sweet Pavilion,Ballroom Blush

@baroque|Baroque|🏰|living|artistic
blurb: Deep reds, heavy gold frames, dramatic drapery and candlelight.
garland: 👑,🕯️,🌹,🍇,🎻,💎,🗝️,🏺
corner: 👑,🏺,🕯️,🍇,🎻,🖼️
hangers: 💎,🕯️,🌹,🗝️,🍇,✨
furniture: 🖼️,🏺,🕯️,🪑,🎻,🍷
icons: 👑,🖼️,🎻,🏺,🕯️
acc: 👑,💎,🌹,🎻
amb: harp,fire,chimes
defaults: swag,candles,ornate,embers,frame
colors: 2A0F0F,8C1C13,C9A227,F2E3C6,1F2A44
mood: gothic,golden,amber,ember,elegant,rose
styles: swag,candles,ornate,embers,scroll,tassels,double,wreathed,tinsel,ribboned,fans,sparkly
looks: Gold Frames,Crimson Drapes,Candle Chapel,Grand Staircase,Chiaroscuro,Marble Saints,Organ Loft,Velvet Throne,Feast Table,Gilded Dome,Opera House,Still Life Grapes,Fountain Court,Mirror Hall,Royal Portrait,Bronze Angels,Tapestry Room,Dark Cathedral,Harpsichord,Treasure Vault,Midnight Mass,Ceiling Fresco,Laurel Crown,Twisted Columns,Final Act

@art_nouveau|Art Nouveau|🪻|living|artistic
blurb: Flowing lines, lilies, peacocks, stained glass and whiplash curves.
garland: 🪻,🌷,🦚,🌿,🪷,🦋,🌸,🍃
corner: 🦚,🪷,🌷,🦋,🪻,🌿
hangers: 🦋,🌸,🍃,🪻,🌷,✨
furniture: 🏺,🪴,🦚,🪷,🖼️,🕯️
icons: 🪻,🦚,🪷,🦋,🌷
acc: 🦚,🪻,🦋,🌷
amb: harp,stream,birds
defaults: vine,lanterns,vine,petals,scroll
colors: F2EAD3,6B8F71,C08552,8E6C88,2D4739
mood: vintage,garden,jade,lilac,elegant,amber
styles: vine,lanterns,vined,petalfall,scroll,flutter,ornate,lace,wreathed,ribboned,fans,leafy
looks: Whiplash Curves,Lily Window,Peacock Feather,Stained Glass,Métro Entrance,Iris Panel,Poster Lady,Dragonfly Lamp,Copper Vines,Opal Glass,Willow Screen,Poppy Frieze,Moss Green Hall,Mucha Halo,Wisteria Gate,Glass Lotus,Swan Neck,Ironwork Garden,Thistle Tile,Amber Lamp,Seaweed Line,Orchid Mirror,Garden Café,Night Iris,Golden Pond

@art_deco|Art Deco|🍸|living|artistic
blurb: Gold geometry, black lacquer, sunbursts, jazz and city glamour.
garland: 🍸,✨,🎷,💎,🌃,🎺,🥂,⭐
corner: 🍸,🥂,🎷,💎,🌃,🎺
hangers: ✨,💎,⭐,🥂,🪩,🎶
furniture: 🎷,🥂,🪞,🎺,📻,🍸
icons: 🍸,🎷,💎,🥂,🌃
acc: 🎩,💎,🍸,🪶
amb: musicbox,chimes,pad
defaults: tassels,bulbs,double,glitter,sunburst
colors: 0D0D0D,D4AF37,1F4E5F,F5F0E6,8C1C3A
mood: gothic,golden,midnight,elegant,teal,bold
styles: tassels,bulbs,double,glittery,sunburst,fans,ornate,starlights,tinsel,zigzag,sparkly,beads
looks: Gold Geometry,Black Lacquer,Sunburst Lobby,Jazz Club,Skyscraper Spire,Ocean Liner,Chevron Hall,Cocktail Bar,Fan Mirror,Silver Screen,Speakeasy,Emerald Ballroom,Marble Foyer,Pearl Strand,Champagne Tower,Radio City,Zigzag Moderne,Peacock Bar,Chrome Deco,Midnight Gala,Train Station,Gatsby Garden,Ivory Piano,Teal Lacquer,Golden Elevator

@streetwear|Streetwear|👟|living|artistic
blurb: Sneaker walls, hoodies, spray paint and city concrete.
garland: 👟,🧢,🎧,🛹,🎨,⚡,🔥,💯
corner: 👟,🧢,🛹,🎧,🎨,📻
hangers: ⚡,🔥,💯,🎧,⭐,🧢
furniture: 🛹,👟,📻,🎧,🧢,🪴
icons: 👟,🧢,🛹,🎧,🎨
acc: 🧢,🎧,👟,🕶️
amb: pad,rain,wind
defaults: flags,neon,zigzag,confetti,frame
colors: 1A1A1A,F4F4F4,FF5F00,3DDC97,6C63FF
mood: bold,minimal,neon,midnight,retro
styles: flags,neonlights,zigzag,confettied,ornate,stitched,dotted,bunting,tassels,sparkly,nolights,clustered
looks: Sneaker Wall,Hoodie Drop,Spray Paint,City Concrete,Skate Deck,Boombox,Bucket Hat,Limited Edition,Graffiti Alley,Neon Orange,Court Lines,Rooftop Session,Tag Wall,Monochrome Fit,Vintage Tee,Varsity Jacket,Cargo Green,Retro Runner,Mixtape Cover,Subway Style,Box Logo,Purple Haze,Sticker Slap,Night Market,Fresh Pair

@scrapbook_collage|Scrapbook Collage|✂️|living|artistic
blurb: Washi tape, torn paper, polaroids, ticket stubs and doodles.
garland: ✂️,📎,📷,🎫,💌,🏷️,🌼,⭐
corner: 📷,🎫,✂️,📎,💌,🏷️
hangers: 🏷️,📎,💌,⭐,🌼,🎀
furniture: 📷,📒,✂️,🖍️,🧷,🗂️
icons: ✂️,📷,🎫,💌,📎
acc: ✂️,📷,🎀,📎
amb: chimes,rain,birds
defaults: flags,none,stitched,confetti,ribbon
colors: FDF6EC,D9725E,7EA8BE,E8C547,8FA87B
mood: paper,vintage,pastel,watercolor,folk,whimsical
styles: flags,nolights,stitched,confettied,ribboned,dotted,bunting,lace,zigzag,clustered,petalfall,scallops
looks: Washi Tape,Torn Paper,Polaroid Wall,Ticket Stubs,Doodle Page,Pressed Flower,Travel Journal,Sticker Sheet,Kraft Paper,Postcards,Film Strip,Lace Scrap,Stamp Collection,Envelope Pocket,Magazine Cut,Label Maker,Paper Doll,Map Scraps,Memory Box,Glitter Paper,Sketchbook,Gold Foil,Receipt Art,Calendar Page,Little Things
@kawaii|Kawaii|🍡|living|cute
blurb: Round faces, pastel sweets, tiny bunnies and sparkly hearts.
garland: 🍡,🐰,🍓,💖,🌸,🧁,🐱,⭐
corner: 🐰,🐱,🍡,🧁,🌸,🍓
hangers: 💖,⭐,🌸,🍬,🎀,☁️
furniture: 🧸,🍰,🐰,🐱,🍓,🧁
icons: 🍡,🐰,🐱,🍓,💖
acc: 🎀,🐰,🍓,💖
amb: musicbox,chimes,birds
defaults: pompom,fairy,scallop,hearts,cluster
colors: FFF5F8,FF8FB1,A0E7E5,FFE57F,C3B1E1
mood: kawaii,pastel,sweet,dreamy,blossom,whimsical
styles: pompoms,fairy,scallops,hearty,clustered,bunting,sparkly,dotted,beads,bubbly,ribboned,emojis
looks: Mochi Friends,Strawberry Milk,Bunny Bakery,Kitty Café,Sparkle Hearts,Dango Picnic,Cloud Nap,Pudding Cup,Star Candy,Panda Snack,Bento Box,Sakura Bunny,Pastel Arcade,Sticker Shop,Bubble Bath,Fluffy Chick,Melon Soda,Pocket Friends,Ribbon Shop,Peach Kitty,Jelly Stars,Rainbow Sprinkles,Honey Bear,Sleepy Seal,Happy Toast

@pastelcore|Pastelcore|🩷|living|cute
blurb: Soft lavender, baby blue, mint and buttercream everything.
garland: 🩷,🩵,💜,🫧,☁️,🌸,🦄,⭐
corner: ☁️,🦄,🌸,🫧,🩷,🩵
hangers: 🫧,☁️,⭐,🩷,🩵,🌸
furniture: 🦄,🧁,🫧,🌸,🪴,🧸
icons: 🩷,🩵,☁️,🦄,🫧
acc: 🎀,🦄,☁️,🩷
amb: musicbox,harp,birds
defaults: beads,fairy,scallop,bubbles,cluster
colors: FDF7FF,F7C6D9,BDE0FE,CDEAC0,E2C2FF
mood: pastel,dreamy,lilac,blossom,frost,sweet
styles: beads,fairy,scallops,bubbly,clustered,pompoms,sparkly,lace,hearty,cloudy,bokehy,ribbons
looks: Lavender Haze,Baby Blue,Mint Cream,Buttercream,Cotton Candy,Peach Fuzz,Lilac Morning,Soft Sorbet,Cloud Nine,Pastel Rain,Milk Tea,Pearl Pink,Sky Lullaby,Seafoam,Lemon Chiffon,Periwinkle,Blush Room,Marshmallow,Sugared Violet,Pistachio,Pastel Sunset,Dreamy Duvet,Rose Water,Ice Cream Shop,Faded Rainbow

@cutecore|Cutecore|💕|living|cute
blurb: Heart-eyed plushies, bandaids, little bows and glitter text.
garland: 💕,🎀,🧸,🩹,✨,💌,🍓,🌟
corner: 🧸,🎀,💌,🩹,🍓,💕
hangers: 💕,✨,🎀,🌟,💌,💗
furniture: 🧸,🎀,💌,🍰,🪞,🩹
icons: 💕,🧸,🎀,💌,🩹
acc: 🎀,💕,🧸,🩹
amb: musicbox,chimes,pad
defaults: ribbon,fairy,dotted,hearts,ribbon
colors: FFF0F5,FF69B4,FFB6C1,FFFFFF,C71585
mood: kawaii,blossom,sweet,pastel,rose,dreamy
styles: ribbons,fairy,dotted,hearty,ribboned,sparkly,glittery,pompoms,lace,scallops,beads,bokehy
looks: Heart Eyes,Bandaid Pink,Little Bows,Glitter Text,Plush Pile,Love Letter,Strawberry Heart,Sparkle Room,Bubblegum,Lace Socks,Cherry Charm,Teddy Hug,Pink Phone,Sweetheart,Fairy Bandage,Pastel Diary,Heart Locket,Candy Hearts,Kitty Kiss,Gloss and Glitter,Pink Mirror,Hugs and Kisses,Bow Garden,Lovebug,Cute Overload

@dreamcore|Dreamcore|☁️|living|cute
blurb: Strange soft spaces, endless clouds, glowing doors and déjà vu.
garland: ☁️,🌈,🚪,👁️,⭐,🫧,🌙,🦋
corner: 🚪,☁️,🌈,👁️,🫧,🌙
hangers: ☁️,⭐,🫧,🦋,🌙,✨
furniture: 🚪,🪞,🎠,🧸,☁️,💡
icons: ☁️,🚪,🌈,👁️,🫧
acc: ☁️,🦋,🌙,⭐
amb: pad,harp,musicbox
defaults: beads,fairy,hairline,clouds,window
colors: EEF2FF,A7C7E7,F9D5E5,FFF3B0,B39CD0
mood: dreamy,sky,pastel,lilac,frost,midnight
styles: beads,fairy,hairline,cloudy,windowed,bokehy,starry,bubbly,sparkly,flutter,calm,dotted
looks: Endless Clouds,Glowing Door,Empty Pool,Déjà Vu,Floating Stairs,Pastel Hallway,Lost Playground,Sky Room,Strange Window,Lullaby Static,Moon Carousel,Soft Void,Bubble Hall,Mirror Field,Rainbow Corridor,Old TV Glow,Nostalgia Park,Liminal Mall,Dream Bedroom,Floating Islands,Midnight Swing,Butterfly Static,Sunset Loop,Waking Up,Somewhere Else

@kidcore|Kidcore|🖍️|living|cute
blurb: Primary colours, crayons, building blocks and sticker charts.
garland: 🖍️,🧸,🎈,🪀,🚂,⭐,🌈,🧩
corner: 🧸,🧩,🪀,🚂,🎈,🖍️
hangers: 🎈,⭐,🌈,🪁,🧩,🎈
furniture: 🧸,🚂,🧩,🪀,🛝,🎨
icons: 🖍️,🧸,🧩,🎈,🌈
acc: 🧢,🎈,🧸,🖍️
amb: musicbox,birds,chimes
defaults: bunting,bulbs,zigzag,confetti,cluster
colors: FFFFFF,E63946,1D4ED8,FACC15,22C55E
mood: bold,whimsical,carnival,classic,sky,retro
styles: bunting,bulbs,zigzag,confettied,clustered,flags,pompoms,dotted,starry,emojis,streamers,sparkly
looks: Primary Colours,Crayon Box,Building Blocks,Sticker Chart,Toy Train,Balloon Party,Juice Box,Saturday Cartoons,Finger Paints,Lunch Pail,Playground,Puzzle Rug,Jump Rope,Kite Day,Lego City,Bubble Wand,Rainbow Loom,Sandbox,Story Rug,Bouncy Ball,Toy Chest,Glow Stickers,Pillow Fort,Sprinkler Day,Nap Time

@candycore|Candycore|🍭|living|cute
blurb: Lollipops, gumdrops, sprinkles and candy-striped everything.
garland: 🍭,🍬,🍫,🧁,🍩,🍦,🍪,🍰
corner: 🍭,🍬,🧁,🍩,🍦,🍰
hangers: 🍬,🍭,🍩,🍫,⭐,🍒
furniture: 🍰,🧁,🍦,🍭,🍩,🎂
icons: 🍭,🍬,🧁,🍩,🍦
acc: 🍭,🎀,🧁,🍬
amb: musicbox,chimes,birds
defaults: pompom,bulbs,scallop,confetti,cluster
colors: FFF7FB,FF4F9A,5CE1E6,FFD93D,9B5DE5
mood: sweet,kawaii,whimsical,carnival,pastel,bold
styles: pompoms,bulbs,scallops,confettied,clustered,beads,dotted,sparkly,hearty,bunting,streamers,bubbly
looks: Lollipop Lane,Gumdrop Garden,Sprinkle Shop,Candy Stripe,Chocolate River,Cotton Candy Cloud,Jelly Bean Jar,Bubblegum Pop,Taffy Pull,Rock Candy,Sour Rainbow,Marshmallow Hill,Licorice Swirl,Peppermint Twist,Candy Necklace,Fizzy Soda,Caramel Corner,Gummy Bears,Sugar Rush,Bonbon Box,Candy Castle,Popsicle Party,Frosting Flowers,Lemon Drop,Sweet Dreams

@plushie_bedroom|Plushie Bedroom|🧸|living|cute
blurb: A soft room full of plush friends, fluffy pillows and night lights.
garland: 🧸,🐰,🐻,🐱,🐶,🦄,🐼,⭐
corner: 🧸,🐻,🐰,🦄,🐼,🐱
hangers: ⭐,🌙,☁️,💤,🌟,🎀
furniture: 🧸,🛏️,🐻,🐰,🦄,🐼
icons: 🧸,🐻,🐰,🦄,🐼
acc: 🧸,🎀,💤,🌙
amb: musicbox,rain,night
defaults: pompom,fairy,stitched,stars,cluster
colors: FBF4EF,D9A5B3,A8C5DA,F6E3A1,8C7A6B
mood: cozy,pastel,kawaii,dreamy,blossom,midnight
styles: pompoms,fairy,stitched,starry,clustered,scallops,hearty,lace,beads,starlights,bokehy,cloudy
looks: Plush Pile,Teddy Shelf,Bunny Bed,Night Light,Sleepy Bear,Fluffy Pillows,Plush Parade,Cozy Blanket,Bedtime Story,Pajama Party,Dream Catcher,Unicorn Quilt,Panda Hug,Stuffed Zoo,Moon Mobile,Kitten Cushion,Lullaby,Hug Corner,Plush Tea Party,Toy Hammock,Starry Canopy,Soft Rug,Dino Friends,Little Lamb,Goodnight

@magical_garden|Magical Garden|🪄|living|cute
blurb: Glowing flowers, wishing wells, talking toadstools and sparkles.
garland: 🌷,✨,🪄,🍄,🦋,🌸,🌙,🪻
corner: 🍄,🪄,🌷,🦋,🌙,🪻
hangers: ✨,🦋,🌸,🌙,⭐,🪄
furniture: 🍄,🪴,🦔,🐇,🪺,🌷
icons: 🪄,🌷,🦋,🍄,✨
acc: 🪄,🦋,🌸,✨
amb: harp,birds,stream
defaults: vine,fairy,vine,sparkles,sprig
colors: F5F3FF,8E6BB0,F7A1C4,7CC6A4,FFD96B
mood: garden,dreamy,lilac,whimsical,midnight,moss
styles: vine,fairy,vined,sparkly,flutter,glowing,petalfall,wreathed,lace,starry,scallops,bokehy
looks: Glowing Tulips,Wishing Well,Talking Toadstools,Moonflower Path,Sparkle Pond,Hedgehog Hollow,Enchanted Gate,Crystal Bloom,Rabbit Burrow,Star Seeds,Willow Swing,Lantern Flowers,Rainbow Bridge,Secret Door,Golden Bees,Twilight Roses,Dewdrop Fountain,Butterfly Ballet,Fairy Picnic,Owl Tree,Silver Fern,Midnight Bloom,Wish Petals,Spell Garden,Ever Spring

@storybook|Storybook|📕|living|cute
blurb: Illustrated pages, castles, gentle beasts and once-upon-a-time.
garland: 📕,🏰,🐉,👑,🌟,🦊,🐺,🍎
corner: 🏰,📕,🐉,👑,🦉,🍎
hangers: 🌟,🍎,👑,🗝️,🌙,🦋
furniture: 🏰,📚,🐉,🦊,🍄,🪄
icons: 📕,🏰,🐉,👑,🦊
acc: 👑,📕,🪄,🦊
amb: harp,musicbox,birds
defaults: bunting,lanterns,ornate,sparkles,scroll
colors: F6EBD9,2A7F7F,E76F51,F4A261,264653
mood: storybook,vintage,folk,whimsical,midnight,garden
styles: bunting,lanterns,ornate,sparkly,scroll,flags,wreathed,ribboned,starry,vine,flutter,stitched
looks: Once Upon a Time,Castle Tower,Gentle Dragon,Red Riding Hood,Gingerbread House,Sleeping Castle,Fox and Crow,Glass Slipper,Beanstalk,Three Bears,Frog Prince,Enchanted Wood,Golden Goose,Mermaid Cove,Wizard's Book,Pied Piper,Snow Queen,Tortoise and Hare,Pumpkin Coach,Brave Tailor,Bremen Band,Owl's Tale,Happily Ever After,Tower Window,The End

@cloud_kingdom|Cloud Kingdom|🏰|living|cute
blurb: Castles on clouds, rainbow bridges, sky whales and sunbeams.
garland: ☁️,🌈,🏰,⭐,🕊️,🪽,🌤️,✨
corner: 🏰,☁️,🌈,🪽,🕊️,🌤️
hangers: ☁️,⭐,🕊️,🪽,🌈,✨
furniture: 🏰,🐋,☁️,🌈,🎈,🪁
icons: ☁️,🏰,🌈,🪽,🕊️
acc: 👑,🪽,☁️,🌈
amb: wind,harp,birds
defaults: beads,fairy,scallop,clouds,window
colors: F4FAFF,9AD0F5,FFE08A,F7B6D2,B8A9E8
mood: sky,dreamy,pastel,frost,golden,celestial
styles: beads,fairy,scallops,cloudy,windowed,sparkly,starry,bubbly,flutter,ribbons,sunburst,bokehy
looks: Cloud Castle,Rainbow Bridge,Sky Whales,Sunbeam Court,Cumulus Garden,Feather Palace,Wind Kites,Silver Lining,Sky Market,Dawn Towers,Balloon Harbor,Pegasus Stable,Starlight Spire,Mist Gardens,Thunder Hall,Snow Cloud,Sky Lanterns,Golden Gates,Pink Sky,Aurora Keep,Floating Isles,Cloud Library,Moon Balcony,Sky Lullaby,Above It All
@music_studio|Music Studio|🎚️|living|lifestyle
blurb: Mixing desks, foam walls, glowing meters and late-night takes.
garland: 🎚️,🎛️,🎙️,🎧,🎵,🎹,🔊,💡
corner: 🎙️,🎛️,🎧,🎹,🔊,🎸
hangers: 🎵,🎶,💡,🎧,⭐,🎼
furniture: 🎹,🎛️,🔊,🎸,🎧,🪴
icons: 🎚️,🎙️,🎧,🎛️,🎹
acc: 🎧,🎙️,🎵,🎚️
amb: pad,musicbox,rain
defaults: chain,neon,double,bokeh,frame
colors: 121212,FF3366,20C9E0,F7B32B,2E2E3A
mood: midnight,neon,gothic,amber,bold,teal
styles: chain,neonlights,double,bokehy,ornate,dotted,starry,hairline,bulbs,sparkly,stitched,nolights
looks: Mixing Desk,Foam Walls,Glowing Meters,Late Night Take,Vocal Booth,Synth Rack,Tape Machine,Beat Lab,Red Light On,Headphone Wall,Analog Warmth,Drum Room,Master Bus,Producer Den,Bedroom Studio,Sample Crate,Neon Sign Studio,Live Room,Control Room,Lo-fi Loop,Vinyl Sampling,Acoustic Session,Film Score,Final Mix,Wrap Party

@record_store|Record Store|💿|living|lifestyle
blurb: Crates of vinyl, listening booths, posters and hand-written price tags.
garland: 💿,📀,🎵,🎸,🎤,⭐,🎶,📻
corner: 💿,📻,🎸,🎤,📀,🎶
hangers: 💿,🎵,⭐,🎶,📀,💡
furniture: 📻,💿,🎸,🎧,🪴,📦
icons: 💿,📻,🎵,🎸,🎤
acc: 🎧,💿,🎵,🕶️
amb: musicbox,rain,pad
defaults: flags,bulbs,stitched,none,frame
colors: F1E3C8,C1440E,1D3557,F2A541,2B2B2B
mood: retro,vintage,amber,bold,midnight,cafe
styles: flags,bulbs,stitched,ornate,dotted,bunting,clustered,starry,calm,neonlights,double,tassels
looks: Vinyl Crates,Listening Booth,Poster Wall,Price Tags,New Arrivals,Jazz Section,Punk Bin,Soul Corner,Record Day,Crate Digging,Turntable Counter,Cassette Wall,Imports Shelf,Bargain Bin,Signed Sleeves,Indie Shelf,Classic Rock,Hip Hop Corner,Sunday Browse,Gatefold,Picture Disc,Staff Picks,Rainy Afternoon,Closing Sale,Needle Drop

@jazz_lounge|Jazz Lounge|🎷|living|lifestyle
blurb: Dim velvet booths, a stand-up bass, brass and smoky blue light.
garland: 🎷,🎺,🎹,🍸,🎶,🎩,🥃,✨
corner: 🎷,🎹,🎺,🍸,🎩,🪕
hangers: 🎶,✨,🎵,⭐,💡,🌙
furniture: 🎹,🎷,🍸,🪑,🕯️,🎙️
icons: 🎷,🎺,🎹,🍸,🎶
acc: 🎩,🎷,🍸,🎶
amb: musicbox,rain,fire
defaults: swag,candles,double,bokeh,frame
colors: 0F1B2D,C9A227,7A1F3D,3B6E8F,F2E6D0
mood: midnight,gothic,amber,elegant,indigo,golden
styles: swag,candles,double,bokehy,ornate,tassels,starlights,fans,scroll,starry,lanterns,calm
looks: Velvet Booth,Stand-up Bass,Brass Section,Smoky Blue,Piano Bar,Late Set,Speakeasy Door,Martini Hour,Trumpet Solo,Midnight Combo,Scat Singer,Candle Tables,Blue Note,Swing Night,Bebop Corner,Crooner,Cocktail Napkin,Saxophone Moon,Club Marquee,Ballad Hour,Drum Brushes,Harlem Night,Torch Song,After Hours,Last Call

@marching_band|Marching Band|🥁|living|lifestyle
blurb: Plumed hats, brass flashing in the sun, drums and field lines.
garland: 🥁,🎺,🎷,🎵,⭐,🏈,🎶,🚩
corner: 🥁,🎺,🎷,🚩,🏆,🎶
hangers: 🎵,⭐,🚩,🎶,🏆,🎊
furniture: 🥁,🎺,🎷,🏆,🚩,📯
icons: 🥁,🎺,🎷,🚩,🏆
acc: 🎩,🥁,🎺,🚩
amb: chimes,wind,birds
defaults: flags,bulbs,double,confetti,frame
colors: FFFFFF,B22234,1C3F94,FFC72C,1E1E1E
mood: bold,classic,carnival,midnight,retro,golden
styles: flags,bulbs,double,confettied,ornate,bunting,tassels,starry,streamers,dotted,sparkly,stitched
looks: Plumed Hats,Brass in the Sun,Drum Line,Field Lines,Halftime Show,Pep Rally,Homecoming,Color Guard,Parade Route,Band Camp,Drum Major,Fight Song,Sousaphone,Friday Lights,Band Room,Victory March,Flag Spin,Competition Day,Snare Cadence,Bleacher Seats,Trophy Case,Fourth Quarter,Senior Night,Rain Show,Final Formation

@arcade|Arcade|🕹️|living|lifestyle
blurb: Glowing cabinets, prize tickets, neon carpet and coin slots.
garland: 🕹️,👾,🪙,🎟️,⭐,🏆,🎯,💥
corner: 🕹️,👾,🎯,🏆,🎰,🎟️
hangers: 🪙,⭐,🎟️,💥,👾,🎈
furniture: 🕹️,🎰,🏆,🧸,🎯,🎳
icons: 🕹️,👾,🪙,🎟️,🏆
acc: 🧢,🕹️,🪙,🎟️
amb: musicbox,chimes,pad
defaults: chain,neon,zigzag,confetti,frame
colors: 0D0221,FF2A6D,05D9E8,FFE66D,7B2CBF
mood: neon,midnight,carnival,bold,retro
styles: chain,neonlights,zigzag,confettied,ornate,bulbs,starry,sparkly,dotted,flags,glittery,streamers
looks: Glowing Cabinets,Prize Tickets,Neon Carpet,Coin Slot,High Score Board,Claw Machine,Skee Ball,Racing Seat,Pinball Wizard,Dance Machine,Air Hockey,Token Cup,Fighting Game,Light Gun,Prize Counter,Retro Row,Birthday Party,Midnight Arcade,Pixel Champion,Lucky Spin,Two Player,Bonus Round,Ticket Rain,Insert Coin,Last Credit

@gaming_room|Gaming Room|🎮|living|lifestyle
blurb: RGB glow, a comfy chair, controllers, posters and snacks.
garland: 🎮,🎧,⌨️,🖱️,🏆,⚔️,🛡️,💎
corner: 🎮,🎧,🖥️,🏆,⚔️,🛡️
hangers: 💎,⭐,🏆,🎮,🪙,❤️
furniture: 🖥️,🎮,🎧,🪑,🍕,🥤
icons: 🎮,🎧,🖥️,🏆,⚔️
acc: 🎧,🎮,⚔️,🛡️
amb: pad,rain,musicbox
defaults: chain,neon,double,bokeh,frame
colors: 0B0C10,8A2BE2,00E5FF,39FF14,FF3864
mood: neon,midnight,gothic,bold,indigo
styles: chain,neonlights,double,bokehy,ornate,starry,sparkly,dotted,hairline,glittery,beads,nolights
looks: RGB Glow,Comfy Chair,Controller Wall,Poster Gallery,Snack Station,Stream Setup,Raid Night,Retro Console Shelf,Speedrun,Co-op Couch,Boss Fight,Tournament Day,Headset Hook,Collector Shelf,Purple Light,Cozy Gamer,LAN Party,Respawn,Level Up,Achievement Wall,Handheld Corner,Midnight Quest,Cable Jungle,Victory Royale,Save and Quit

@cinema|Cinema|🎬|living|lifestyle
blurb: Red curtains, marquee lights, popcorn and a silver screen.
garland: 🎬,🎞️,🍿,🎟️,⭐,🎥,🌟,📽️
corner: 🎬,🍿,🎥,🎟️,📽️,🎭
hangers: ⭐,🌟,🎞️,🎟️,✨,🎬
furniture: 🍿,🥤,🎥,🪑,📽️,🎭
icons: 🎬,🍿,🎞️,🎟️,🎥
acc: 🕶️,🍿,🎬,🎟️
amb: pad,musicbox,rain
defaults: swag,bulbs,ornate,none,frame
colors: 1A0A0A,B3001B,F2C14E,F5F5F5,2B2B2B
mood: gothic,bold,golden,midnight,retro,elegant
styles: swag,bulbs,ornate,starry,tassels,double,sparkly,calm,scroll,fans,starlights,dotted
looks: Red Curtains,Marquee Lights,Popcorn Stand,Silver Screen,Ticket Booth,Projection Room,Film Reel,Drive-in Night,Premiere,Midnight Showing,Classic Noir,Matinee,Art House,Film Festival,Velvet Seats,Concession Stand,Coming Soon,Director's Chair,Black and White,Technicolor,Indie Screen,Sci-fi Double Bill,Credits Roll,Rooftop Cinema,The End

@manga_cafe|Manga Café|📚|living|lifestyle
blurb: Tall manga shelves, cushioned booths, ramen and speech bubbles.
garland: 📚,💬,🍜,🍙,⭐,💥,🍵,🎌
corner: 📚,🍜,💬,🍙,🍵,🏮
hangers: 💬,⭐,💥,🏮,🎌,✨
furniture: 📚,🍜,🍙,🧋,🪑,🍵
icons: 📚,💬,🍜,🍙,🍵
acc: 🎧,🍙,📚,💬
amb: rain,pad,chimes
defaults: flags,lanterns,dotted,none,lantern
colors: FAF7F2,E63946,111111,F1FAEE,457B9D
mood: paper,minimal,bold,cafe,kawaii,midnight
styles: flags,lanterns,dotted,starry,bunting,stitched,clustered,zigzag,sparkly,calm,confettied,windowed
looks: Manga Shelves,Cushion Booth,Ramen Break,Speech Bubbles,Screentone,Shonen Corner,Shojo Sparkle,Volume One,Late Night Chapter,Onigiri Snack,Tankobon Stack,Ink Panels,Comic Market,Bubble Tea Read,Mecha Shelf,Slice of Life,Action Lines,Cherry Blossom Chapter,Quiet Booth,Series Finale,Chibi Doodles,Lantern Street,Black and White Page,New Release,Cliffhanger

@photo_studio|Photography Studio|📸|living|lifestyle
blurb: Softboxes, backdrops, film rolls and prints drying on a line.
garland: 📸,🎞️,📷,💡,🖼️,⭐,📽️,🔦
corner: 📸,📷,💡,🖼️,🎞️,🔦
hangers: 🖼️,🎞️,⭐,💡,📸,✨
furniture: 📷,💡,🖼️,🪴,🎞️,🪑
icons: 📸,📷,🎞️,💡,🖼️
acc: 📷,🎞️,🕶️,📸
amb: pad,chimes,rain
defaults: flags,bulbs,hairline,bokeh,frame
colors: F5F5F5,222222,E07A5F,81B29A,F2CC8F
mood: minimal,classic,vintage,midnight,retro,elegant
styles: flags,bulbs,hairline,bokehy,ornate,double,dotted,calm,clustered,stitched,windowed,sparkly
looks: Softbox Light,Paper Backdrop,Film Rolls,Drying Prints,Darkroom Red,Portrait Day,Golden Hour Shoot,Polaroid Wall,Studio Flash,Contact Sheet,Lens Collection,Black and White,Fashion Shoot,Product Table,Light Meter,Vintage Camera,Photo Booth,Bokeh Lights,Gallery Print,Instant Film,Location Scout,Tripod Corner,Retouch Desk,Model Call,Final Print

@urban_apartment|Urban Apartment|🏙️|living|lifestyle
blurb: Big windows, city lights, houseplants, records and exposed brick.
garland: 🪴,🏙️,💡,🎧,☕,📚,🌃,🕯️
corner: 🪴,🏙️,☕,📚,🎧,🖼️
hangers: 💡,🪴,⭐,🌙,🕯️,🌃
furniture: 🛋️,🪴,📚,☕,🎧,🖼️
icons: 🏙️,🪴,🛋️,☕,🌃
acc: 🎧,☕,🪴,🕶️
amb: rain,pad,wind
defaults: beads,bulbs,hairline,bokeh,window
colors: EDE7E3,8D5B4C,3D405B,81B29A,F2CC8F
mood: minimal,cafe,midnight,amber,moss,elegant
styles: beads,bulbs,hairline,bokehy,windowed,stitched,calm,starry,raining,dotted,fairy,clustered
looks: Big Windows,City Lights,Houseplants,Record Corner,Exposed Brick,Rooftop View,Loft Morning,Rainy Evening,Fire Escape,Studio Flat,Kitchen Island,Reading Nook,Night Skyline,Plant Wall,Coffee Ritual,Art Prints,Balcony Garden,Weekend Brunch,Lamp Light,Minimal Living,Subway Hum,Sunset Window,Cozy Sofa,Late Night Jazz,Home Again
''';
