/// The raw text behind every collection. One block per collection:
///
///   @id|Name|emoji|kind|approximate
///   blurb / note / pools (garland, corner, hangers, furniture, icons, acc,
///   amb), greetings, `defaults` (garland,lights,border,particle,corner) and
///   25 looks as `- Name|palette,style,style`.
///
/// Each look has its own palette, so no two looks in a collection are the
/// same colours with a different name.
library;

const seasonalSource = '''
@christmas|Christmas|🎄|holiday|false
blurb: Lights, evergreen and warm winter nights for those who celebrate Christmas.
garland: 🎄,⭐,🔔,🎁,🍬,❄️,🕯️
corner: 🎁,🎄,🕯️,🧦,🔔,⭐
hangers: 🔔,⭐,🎀,🍬,❄️,🎄
furniture: 🎁,🧦,🕯️,🎄,⛄,🍪
icons: 🎄,🎅,⛄,🎁,🔔
acc: 🎅,🧣,🎀,🧤
amb: fire,chimes,wind
greet: Merry Christmas!|Happy holidays|Wishing you a cozy, gentle season
greetEs: ¡Feliz Navidad!|Felices fiestas|Te deseo unas fiestas tranquilas
defaults: vine,fairy,hairline,snow,cluster
- Classic Christmas|classic,vine,fairy
- Cozy Cabin|cozy,candles,leafy
- Snowy Village|village,windowed,snowing
- Candy Cane Wonderland|sweet,beads,bokehy
- Gingerbread Bakery|harvest,scallops,glowing
- Victorian Christmas|vintage,ornate,wreathed
- Pastel Christmas|pastel,pompoms,sparkly
- Gothic Christmas|gothic,candles,starry
- Golden Christmas|golden,tinsel,bulbs
- Scandinavian Winter|frost,hairline,nolights
- Christmas Market|market,bunting,lanterns
- Woodland Christmas|woodland,vine,glowing
- Christmas Cottage|rustic,swag,wreathed
- Midnight Christmas|midnight,starlights,starry
- Celestial Christmas|celestial,starlights,sparkly
- Retro Christmas|retro,bulbs,confettied
- Kawaii Christmas|kawaii,pompoms,hearty
- Knitted Christmas|folk,chain,snowing
- Frosted Windows|teal,frosty,windowed
- Nutcracker Christmas|bold,ribbons,ornate
- Peppermint Café|cafe,scallops,bubbly
- Christmas Toy Workshop|workshop,chain,clustered
- Elegant Silver Christmas|elegant,tinsel,double
- Minimalist Christmas|minimal,hairline,calm
- Tropical Christmas|tropical,bulbs,flutter

@halloween|Halloween|🎃|holiday|false
blurb: Pumpkins, candlelight and friendly frights for those who love Halloween.
garland: 🎃,🦇,👻,🕸️,🍬,🕯️,🍂
corner: 🎃,🕸️,🦇,👻,🕯️,🍬
hangers: 🦇,👻,🕷️,🎃,🌙,⭐
furniture: 🎃,🕯️,🧙,🐈‍⬛,📚,🍬
icons: 🎃,👻,🦇,🕸️,🍬
acc: 🎩,🦇,🎃,🧙
amb: night,wind,chimes
greet: Happy Halloween!|Have a spooky, cozy night|Pumpkins and candlelight to you
greetEs: ¡Feliz Halloween!|Una noche espeluznante y acogedora
defaults: swag,candles,hairline,leaves,cluster
- Classic Halloween|classic,swag,candles
- Haunted Mansion|gothic,windowed,glowing
- Pumpkin Patch|harvest,emojis,leafy
- Cozy Witch Cottage|cozy,lanterns,sparkly
- Pastel Halloween|pastel,pompoms,hearty
- Gothic Victorian|vintage,ornate,wreathed
- Cute Ghosts|kawaii,bunting,bubbly
- Black Cat Café|cafe,scallops,starry
- Autumn Cemetery|moss,vined,leafy
- Enchanted Forest|forest,vine,glowing
- Spooky Carnival|carnival,bulbs,confettied
- Retro Halloween|retro,chain,embers
- Candy Corn|sweet,beads,clustered
- Moonlit Night|midnight,starlights,starry
- Vampire Castle|rose,ornate,candles
- Haunted Library|amber,scroll,glowing
- Mushroom Witch|woodland,vine,flutter
- Pumpkin Bakery|rustic,scallops,candles
- Purple Magic|lilac,fairy,sparkly
- Skeleton Parade|bold,bunting,confettied
- Ghost Town|desert,windowed,cloudy
- Kawaii Monsters|dreamy,pompoms,hearty
- Midnight Garden|garden,vined,glowing
- Halloween Village|village,windowed,snowing
- Minimalist Spooky|minimal,hairline,calm

@thanksgiving|Thanksgiving|🦃|holiday|false
blurb: Gratitude, harvest tables and gathering, for those who observe Thanksgiving.
garland: 🍂,🌽,🍁,🥧,🍎,🌾,🕯️
corner: 🍂,🌽,🥧,🍁,🕯️,🌾
hangers: 🍁,🍂,🌰,🍎,🕯️,🌾
furniture: 🥧,🌽,🕯️,🍎,🧺,🍂
icons: 🍂,🦃,🥧,🌽,🍁
acc: 🧣,🍁,🧤,🍂
amb: fire,wind,chimes
greet: Happy Thanksgiving|Grateful for you today|Wishing you a warm table
greetEs: Feliz Día de Acción de Gracias|Agradecido por ti
defaults: swag,candles,hairline,leaves,cluster
- Harvest Table|harvest,swag,candles
- Cozy Hearth|cozy,fairy,leafy
- Autumn Orchard|rustic,emojis,leafy
- Pumpkin Pie Kitchen|amber,scallops,glowing
- Golden Hour Gratitude|golden,tinsel,sparkly
- Woodland Gathering|woodland,vine,glowing
- Maple Lane|sunset,bunting,leafy
- Farmhouse Feast|paper,chain,clustered
- Cornucopia|market,beads,confettied
- Thankful Notes|vintage,scroll,hairline
- Soft Pastel Autumn|pastel,pompoms,petalfall
- Quiet Candlelight|ember,candles,calm
- Orchard Café|cafe,scallops,bubbly
- Rustic Barn|forest,bunting,windowed
- Elegant Dinner|elegant,double,fairy
- Minimal Harvest|minimal,hairline,calm
- Folk Harvest|folk,chain,wreathed
- Storybook Autumn|storybook,vined,flutter
- Cottage Autumn|garden,swag,wreathed
- Rosy Dusk|rose,ribbons,hearty
- Misty Morning|monsoon,hairline,cloudy
- Village Gathering|village,windowed,glowing
- Warm Quilt|workshop,chain,ornate
- Spiced Cider|retro,bulbs,embers
- Sunset Picnic|whimsical,bunting,confettied

@nye|New Year's Eve|🥂|holiday|false
blurb: A sparkling countdown to midnight, for those who celebrate New Year's Eve.
garland: ✨,🥂,🎆,⭐,🕛,🎉,🎈
corner: 🥂,🎆,✨,🎉,🕛,🎈
hangers: ⭐,🎈,✨,🕛,🎉,🔔
furniture: 🥂,🎈,🕛,🎆,🎉,🍾
icons: 🥂,🎆,🕛,✨,🎉
acc: 🎩,🥳,✨,🎉
amb: chimes,pad,night
greet: Happy New Year's Eve!|Here's to a fresh start|Counting down with you
greetEs: ¡Feliz Nochevieja!|Brindemos por empezar de nuevo
defaults: tinsel,bulbs,hairline,confetti,cluster
- Midnight Countdown|midnight,tinsel,starry
- Golden Fireworks|golden,bulbs,sparkly
- Silver Sparkle|elegant,tinsel,double
- Confetti Party|whimsical,bunting,confettied
- Neon City Night|neon,bulbs,bokehy
- Champagne Toast|amber,scallops,bubbly
- Starlit Rooftop|celestial,starlights,starry
- Pastel Party|pastel,pompoms,sparkly
- Retro Disco|retro,bulbs,confettied
- Kawaii Countdown|kawaii,pompoms,hearty
- Cozy Midnight|cozy,candles,calm
- Black & Gold|gothic,ornate,sparkly
- Winter Skyline|frost,windowed,snowing
- Balloon Drop|bold,bunting,confettied
- Quiet Candle Night|ember,candles,glowing
- Art Deco Gala|vintage,ornate,scroll
- Dreamy Midnight|dreamy,fairy,sparkly
- Minimal Clock|minimal,hairline,calm
- Fireside Resolution|rustic,swag,embers
- Paper Lanterns|lantern,lanterns,glowing
- Aurora Night|teal,starlights,cloudy
- Carnival Countdown|carnival,bulbs,confettied
- Jade & Gold|jade,ribbons,hairline
- Rose Gold Glow|rose,tinsel,sparkly
- Indigo Skies|indigo,starlights,starry

@newyear|New Year's Day|🎊|holiday|false
blurb: A clean page and a hopeful morning, for those who mark New Year's Day.
garland: 🌅,🎊,🌱,⭐,📅,✨,🕊️
corner: 🌅,🌱,📅,✨,🕊️,🎊
hangers: ⭐,🎈,🌱,✨,🕊️,🌅
furniture: 📅,🌱,☕,📓,🕯️,🎈
icons: 🌅,🎊,🌱,📅,✨
acc: 🧣,🌱,✨,🕶️
amb: birds,chimes,wind
greet: Happy New Year!|A fresh page is waiting|New year, gentle beginnings
greetEs: ¡Feliz Año Nuevo!|Una página nueva te espera
defaults: swag,fairy,hairline,sparkles,cluster
- First Sunrise|sunset,swag,sparkly
- Fresh Page|paper,scroll,calm
- Gentle Resolutions|pastel,pompoms,petalfall
- Golden Morning|golden,tinsel,sparkly
- Cozy Brunch|cafe,scallops,bubbly
- Snowy Reset|frost,hairline,snowing
- Clean Slate|minimal,hairline,calm
- New Leaf|garden,vine,flutter
- Bright Start|bold,bunting,confettied
- Morning Mist|monsoon,hairline,cloudy
- Hopeful Sky|sky,swag,starry
- Warm Hearth|cozy,candles,glowing
- Planner Season|vintage,scroll,dotted
- Dreamy Dawn|dreamy,fairy,sparkly
- Woodland Walk|woodland,vine,leafy
- Kawaii Fresh Start|kawaii,pompoms,hearty
- Elegant Morning|elegant,double,fairy
- Retro Calendar|retro,chain,confettied
- Storybook Chapter One|storybook,vined,flutter
- Teal Horizon|teal,starlights,cloudy
- Rose Dawn|rose,ribbons,hearty
- Lilac Light|lilac,fairy,sparkly
- Folk New Year|folk,chain,wreathed
- Jade Beginnings|jade,beads,petalfall
- Midnight to Morning|midnight,starlights,starry

@valentine|Valentine's Day|💝|holiday|false
blurb: Hearts, notes and small kindnesses, for those who celebrate Valentine's Day, Galentine's, or self-love.
garland: 💝,💌,🌹,💕,🍫,✨,🧸
corner: 💌,🌹,💕,🍫,🧸,💝
hangers: 💕,💌,🌹,✨,🎀,💝
furniture: 🌹,🍫,💌,🧸,🕯️,🎁
icons: 💝,💌,🌹,💕,🍫
acc: 🎀,💌,🧸,🌹
amb: musicbox,harp,chimes
greet: Happy Valentine's Day|Sending you a little love|Be kind to yourself today
greetEs: Feliz Día de San Valentín|Te mando un poquito de cariño
defaults: ribbon,fairy,scallop,hearts,cluster
- Classic Valentine|rose,ribbons,hearty
- Love Letters|vintage,scroll,dotted
- Candy Hearts|sweet,beads,bubbly
- Rose Garden|floral,vine,petalfall
- Pastel Crush|pastel,pompoms,sparkly
- Gothic Romance|gothic,candles,ornate
- Golden Hour Date|golden,tinsel,bulbs
- Cozy Cuddles|cozy,candles,glowing
- Kawaii Love|kawaii,pompoms,hearty
- Chocolate Box|cafe,scallops,clustered
- Midnight Dinner|midnight,starlights,starry
- Retro Diner|retro,bulbs,confettied
- Galentine's Party|whimsical,bunting,confettied
- Self-Love Spa|dreamy,fairy,sparkly
- Paper Hearts|paper,chain,hairline
- Garden Picnic|garden,swag,flutter
- Starry Serenade|celestial,starlights,starry
- Minimal Heart|minimal,hairline,calm
- Folk Love Tokens|folk,chain,wreathed
- Blossom Date|blossom,vine,petalfall
- Lilac Letters|lilac,ribbons,sparkly
- Amber Candlelight|amber,candles,glowing
- Elegant Evening|elegant,double,fairy
- Storybook Romance|storybook,vined,flutter
- Teal & Rose|teal,ribbons,bokehy

@easter|Easter|🐣|holiday|false
blurb: Spring colours, eggs and new life, for those who celebrate Easter.
garland: 🐣,🌷,🥚,🐰,🌼,🦋,🧺
corner: 🌷,🥚,🐣,🌼,🐰,🧺
hangers: 🥚,🌷,🦋,🌼,🎀,🐣
furniture: 🧺,🥚,🌷,🐰,🌼,🍫
icons: 🐣,🌷,🥚,🐰,🌼
acc: 🎀,🐰,🌷,🌼
amb: birds,stream,chimes
greet: Happy Easter|Wishing you a bright spring day|Soft sunshine and new beginnings
greetEs: Feliz Pascua|Un día de primavera lleno de luz
defaults: vine,fairy,scallop,petals,cluster
- Classic Easter|pastel,vine,petalfall
- Spring Meadow|garden,vine,flutter
- Egg Hunt|whimsical,bunting,confettied
- Bunny Burrow|woodland,vined,glowing
- Cottage Garden|floral,swag,wreathed
- Watercolor Eggs|watercolor,pompoms,sparkly
- Kawaii Chicks|kawaii,pompoms,hearty
- Sunrise Service|sunset,hairline,cloudy
- Tulip Fields|rose,vine,petalfall
- Golden Eggs|golden,tinsel,sparkly
- Cozy Brunch|cafe,scallops,bubbly
- Sky Blue Morning|sky,swag,cloudy
- Lilac Spring|lilac,ribbons,flutter
- Paper Eggs|paper,chain,dotted
- Dreamy Pastels|dreamy,fairy,sparkly
- Minimal Spring|minimal,hairline,calm
- Folk Easter|folk,chain,wreathed
- Storybook Bunny|storybook,vined,flutter
- Mossy Morning|moss,vine,glowing
- Blossom Basket|blossom,swag,petalfall
- Vintage Easter Card|vintage,scroll,ornate
- Retro Chick|retro,bulbs,confettied
- Jade Garden|jade,vine,flutter
- Teal Pond|teal,hairline,bubbly
- Elegant Spring|elegant,double,fairy

@lunarnewyear|Lunar New Year|🧧|holiday|true
blurb: Red lanterns, spring couplets and family reunion, for those who celebrate Lunar New Year.
note: Celebrated across many cultures, each with its own traditions. Seollal, Tết and others have their own collections or can be added as custom celebrations. Dates follow the lunar calendar.
garland: 🧧,🏮,🌸,🎋,🍊,✨,🪭
corner: 🏮,🧧,🌸,🍊,🎋,🪭
hangers: 🏮,🧧,🍊,🌸,🎋,✨
furniture: 🍊,🧧,🏮,🌸,🥟,🍵
icons: 🧧,🏮,🌸,🍊,🥟
acc: 🧧,🏮,🌸,🪭
amb: chimes,harp,night
greet: Happy Lunar New Year|Wishing you health and happiness|May the year bring you peace
greetEs: Feliz Año Nuevo Lunar|Salud y felicidad para ti
defaults: emoji,lanterns,hairline,petals,lantern
- Red Lantern Street|lantern,lanterns,glowing
- Spring Couplets|paper,scroll,double
- Family Reunion Table|market,swag,candles
- Plum Blossom Branch|blossom,vined,petalfall
- Golden Fortune|golden,tinsel,sparkly
- Lantern Festival Night|midnight,lanterns,starry
- Paper Cuttings|bold,chain,hairline
- Mandarin Orange Grove|harvest,vine,flutter
- Soft Pastel Spring|pastel,pompoms,petalfall
- Dumpling Kitchen|cafe,scallops,bubbly
- Fireworks Over Rooftops|indigo,bulbs,confettied
- Jade Garden|jade,vine,flutter
- Cozy Reunion|cozy,candles,calm
- Red & Gold Elegance|elegant,ornate,sparkly
- Bamboo Courtyard|forest,vine,leafy
- Kawaii Lucky Charms|kawaii,pompoms,hearty
- Ink Wash Spring|minimal,hairline,cloudy
- Folk Paper Art|folk,chain,wreathed
- Storybook Dragon Parade|storybook,bunting,confettied
- Moonlit Courtyard|celestial,starlights,starry
- Sunrise Over Hills|sunset,hairline,cloudy
- Rose Peony Garden|rose,vine,petalfall
- Teal Silk|teal,ribbons,sparkly
- Amber Lamplight|amber,lanterns,glowing
- Dreamy Spring Mist|dreamy,fairy,cloudy

@midautumn|Mid-Autumn Festival|🥮|holiday|true
blurb: Full moon, lanterns and mooncakes shared with family, for those who celebrate the Mid-Autumn Festival.
note: Celebrated in Chinese, Vietnamese and other communities; Korea's Chuseok has its own collection. Dates follow the lunar calendar.
garland: 🏮,🌕,🥮,🍊,🌸,🐇,🍵
corner: 🌕,🏮,🥮,🐇,🍵,🍊
hangers: 🏮,🌕,🍊,🐇,✨,🥮
furniture: 🥮,🍵,🏮,🍊,🌕,🐇
icons: 🌕,🏮,🥮,🐇,🍵
acc: 🏮,🐇,🥮,🌕
amb: chimes,night,harp
greet: Happy Mid-Autumn Festival|May your moon be bright|Sharing moonlight with you
greetEs: Feliz Festival del Medio Otoño|Que tu luna brille
defaults: emoji,lanterns,hairline,fireflies,lantern
- Full Moon Courtyard|midnight,lanterns,glowing
- Mooncake Table|market,swag,candles
- Lantern Parade|lantern,lanterns,glowing
- Jade Rabbit|jade,vine,flutter
- Golden Harvest Moon|golden,tinsel,sparkly
- Tea Under the Moon|cafe,scallops,calm
- Osmanthus Garden|garden,vine,petalfall
- Paper Lantern Market|paper,bunting,bulbs
- Soft Pastel Moon|pastel,pompoms,sparkly
- Cozy Family Night|cozy,candles,glowing
- Starlit Pavilion|celestial,starlights,starry
- Maple Moon|harvest,vine,leafy
- Silver Moonlight|elegant,double,fairy
- Bamboo Grove|forest,vine,leafy
- Kawaii Moon Bunny|kawaii,pompoms,hearty
- Minimal Moon|minimal,hairline,calm
- Folk Lanterns|folk,chain,wreathed
- Storybook Moon Palace|storybook,vined,flutter
- Indigo Night|indigo,starlights,starry
- Lake Reflections|teal,hairline,cloudy
- Sunset Before Moonrise|sunset,swag,cloudy
- Lilac Dusk|lilac,fairy,sparkly
- Rose Lantern Glow|rose,ribbons,hearty
- Amber Lamps|amber,lanterns,glowing
- Dreamy Night Sky|dreamy,fairy,bokehy

@chuseok|Chuseok|🌾|holiday|true
blurb: Harvest moon, ancestral remembrance and family gatherings, for those who celebrate Chuseok.
note: A Korean harvest festival. Seollal, the Korean new year, has its own collection. Dates follow the lunar calendar.
garland: 🌾,🌕,🍎,🍐,🥮,🍂,🌰
corner: 🌕,🌾,🍎,🍐,🍂,🌰
hangers: 🌕,🍎,🍐,🌾,🍂,✨
furniture: 🍎,🍐,🌾,🥮,🍵,🌕
icons: 🌕,🌾,🍎,🍐,🥮
acc: 🌾,🍎,🌕,🍂
amb: night,wind,chimes
greet: Happy Chuseok|Wishing you a bountiful harvest|Full moon, full hearts
greetEs: Feliz Chuseok|Una cosecha abundante para ti
defaults: swag,candles,hairline,leaves,cluster
- Harvest Moon|midnight,swag,glowing
- Songpyeon Table|market,scallops,candles
- Family Gathering|cozy,fairy,calm
- Golden Rice Fields|golden,vine,leafy
- Persimmon Orchard|harvest,emojis,leafy
- Hanbok Colours|bold,ribbons,hairline
- Soft Autumn Pastels|pastel,pompoms,petalfall
- Moonlit Village|village,windowed,starry
- Maple Path|sunset,vine,leafy
- Tea House|cafe,scallops,calm
- Pear Blossom Memory|blossom,vined,petalfall
- Rustic Hanok|rustic,swag,wreathed
- Silver Moon Elegance|elegant,double,fairy
- Pine Forest Walk|forest,vine,glowing
- Kawaii Harvest|kawaii,pompoms,hearty
- Minimal Full Moon|minimal,hairline,calm
- Folk Patterns|folk,chain,wreathed
- Storybook Rabbit Moon|storybook,vined,flutter
- Starry Harvest Night|celestial,starlights,starry
- Jade Mountains|jade,hairline,cloudy
- Lantern Courtyard|lantern,lanterns,glowing
- Amber Evening|amber,candles,embers
- Rose Autumn|rose,ribbons,hearty
- Indigo Night Sky|indigo,starlights,starry
- Dreamy Harvest Glow|dreamy,fairy,sparkly

@seollal|Seollal|🎎|holiday|true
blurb: Family reunions, ancestral rites and new beginnings, for those who celebrate Seollal, the Korean new year.
note: A Korean celebration of the lunar new year. It shares a date with Lunar New Year but has its own traditions and look.
garland: 🎎,🍲,🌸,🪁,🎋,🧧,✨
corner: 🎎,🪁,🌸,🍲,🎋,✨
hangers: 🪁,🎋,🌸,✨,🧧,🌕
furniture: 🍲,🎎,🪁,🍵,🌸,🥟
icons: 🎎,🪁,🍲,🌸,🎋
acc: 🎎,🪁,🌸,🧧
amb: chimes,harp,wind
greet: Happy Seollal|Wishing you health and good fortune|Peace and warmth to your family
greetEs: Feliz Seollal|Salud y buena fortuna para ti
defaults: bunting,fairy,hairline,snow,cluster
- Hanbok New Year|bold,ribbons,hairline
- Tteokguk Morning|cafe,scallops,calm
- Kite Flying|sky,bunting,flutter
- Snowy Hanok|frost,windowed,snowing
- Family Bows|folk,chain,wreathed
- Golden Blessings|golden,tinsel,sparkly
- Plum Blossom Snow|blossom,vined,petalfall
- Pastel Hanbok|pastel,pompoms,sparkly
- Cozy Ondol Room|cozy,candles,glowing
- Yut Game Night|retro,bulbs,confettied
- Pine & Bamboo|forest,vine,leafy
- Paper Window Light|paper,windowed,calm
- Silver Frost Elegance|elegant,double,fairy
- Lantern Courtyard|lantern,lanterns,glowing
- Kawaii Lucky Pouch|kawaii,pompoms,hearty
- Minimal Ink|minimal,hairline,cloudy
- Storybook Tiger|storybook,vined,flutter
- Sunrise First Day|sunset,swag,cloudy
- Jade Morning|jade,vine,petalfall
- Indigo Winter Sky|indigo,starlights,starry
- Rose Hanbok|rose,ribbons,hearty
- Amber Lamplight|amber,lanterns,embers
- Dreamy New Year Mist|dreamy,fairy,bokehy
- Teal Palace Roofs|teal,hairline,cloudy
- Starry Wishes|celestial,starlights,starry

@diwali|Diwali|🪔|holiday|true
blurb: The festival of lights: diyas, rangoli and sweets shared with family, for those who celebrate Diwali.
note: Observed by Hindus, Jains, Sikhs and Buddhists in different ways. Dates follow a lunisolar calendar and can differ by region.
garland: 🪔,🌼,✨,🪷,🎆,🍬,🏮
corner: 🪔,🪷,✨,🌼,🍬,🎆
hangers: 🏮,🪔,🌼,✨,🪷,🎆
furniture: 🪔,🍬,🪷,🕯️,🌼,🎁
icons: 🪔,🪷,✨,🌼,🎆
acc: 🪔,🪷,✨,🌼
amb: chimes,harp,pad
greet: Happy Diwali|May your home glow with light|Wishing you joy and light
greetEs: Feliz Diwali|Que tu hogar brille de luz
defaults: emoji,fairy,hairline,sparkles,cluster
- Diya Glow|lantern,candles,glowing
- Rangoli Courtyard|bold,bunting,confettied
- Marigold Garlands|harvest,vine,petalfall
- Festival of Lights|golden,bulbs,sparkly
- Lotus Pond|blossom,vine,bubbly
- Sweets Table|sweet,beads,clustered
- Fireworks Night|indigo,bulbs,starry
- Soft Pastel Diwali|pastel,pompoms,sparkly
- Cozy Family Evening|cozy,fairy,calm
- Jewel Tones|jade,ribbons,ornate
- Starry Terrace|celestial,starlights,starry
- Paper Lanterns|paper,lanterns,glowing
- Rose Gold Radiance|rose,tinsel,sparkly
- Peacock Palace|teal,scroll,ornate
- Kawaii Diyas|kawaii,pompoms,hearty
- Minimal Light|minimal,hairline,calm
- Folk Art Patterns|folk,chain,wreathed
- Storybook Night|storybook,vined,flutter
- Sunset Rooftops|sunset,swag,cloudy
- Midnight Illumination|midnight,starlights,glowing
- Amber Lamps|amber,lanterns,embers
- Saffron Morning|desert,vine,petalfall
- Elegant Gold Leaf|elegant,double,fairy
- Dreamy Glow|dreamy,fairy,bokehy
- Garden of Lamps|garden,vined,glowing

@holi|Holi|🎨|holiday|true
blurb: Colour, spring and joyful togetherness, for those who celebrate Holi.
note: A Hindu spring festival of colours, observed with community and gratitude. Dates follow a lunisolar calendar.
garland: 🌼,🎨,🌸,🪁,🌈,✨,🎶
corner: 🎨,🌸,🌼,🌈,🪁,🎶
hangers: 🪁,🌸,🎈,🌼,✨,🌈
furniture: 🎨,🌼,🍬,🥁,🌸,🪁
icons: 🎨,🌸,🌼,🌈,🪁
acc: 🎨,🌼,🌸,🪁
amb: birds,stream,chimes
greet: Happy Holi|Wishing you a day of colour|Bright joy to you and yours
greetEs: Feliz Holi|Un día lleno de color para ti
defaults: bunting,fairy,hairline,confetti,cluster
- Colour Burst|whimsical,bunting,confettied
- Spring Marigolds|harvest,vine,petalfall
- Gulal Clouds|dreamy,fairy,cloudy
- Kite Sky|sky,bunting,flutter
- Watercolor Splash|watercolor,pompoms,sparkly
- Bold Pigments|bold,chain,confettied
- Garden Party|garden,swag,flutter
- Pastel Holi|pastel,pompoms,petalfall
- Cozy Gathering|cozy,candles,calm
- Festival Drums|carnival,bulbs,confettied
- Rose & Saffron|rose,ribbons,hearty
- Paper Garlands|paper,chain,dotted
- Lilac Spring|lilac,fairy,sparkly
- Jade Fields|jade,vine,leafy
- Kawaii Colours|kawaii,pompoms,hearty
- Minimal Pigment|minimal,hairline,calm
- Folk Prints|folk,chain,wreathed
- Storybook Spring|storybook,vined,flutter
- Sunset Celebration|sunset,swag,sparkly
- Teal Lake|teal,hairline,bubbly
- Tropical Bloom|tropical,vine,flutter
- Blossom Rain|blossom,vine,petalfall
- Elegant Spring|elegant,double,fairy
- Starry Night After|celestial,starlights,starry
- Amber Glow|amber,lanterns,glowing

@ramadan|Ramadan|🌙|holiday|true
blurb: A month of fasting, reflection and community, for those who observe Ramadan.
note: Shown with calm, respectful imagery: crescents, lanterns, geometric patterns and shared meals. Dates follow the Islamic lunar calendar and depend on moon sighting.
garland: 🌙,⭐,🏮,🕌,🌴,✨,🕯️
corner: 🌙,🏮,🕌,⭐,🌴,🕯️
hangers: 🌙,🏮,⭐,✨,🕯️,🌴
furniture: 🏮,🕯️,🌴,🌙,🍵,📖
icons: 🌙,🏮,🕌,⭐,🌴
acc: 🌙,🏮,⭐,🌴
amb: chimes,night,pad
greet: Ramadan Mubarak|Wishing you a peaceful, blessed month|Peace and reflection to you
greetEs: Ramadán Mubarak|Un mes de paz y reflexión
defaults: emoji,lanterns,hairline,stars,lantern
- Crescent & Lanterns|sacred,lanterns,glowing
- Fanous Night|lantern,candles,glowing
- Iftar Table|market,swag,calm
- Moonlit Silhouette|midnight,starlights,starry
- Geometric Tiles|teal,ornate,hairline
- Calligraphy Gold|golden,scroll,sparkly
- Dates & Cups|cafe,scallops,calm
- Quiet Candlelight|amber,candles,embers
- Sunset Iftar|sunset,swag,cloudy
- Pastel Ramadan|pastel,pompoms,sparkly
- Minimal Crescent|minimal,hairline,calm
- Cozy Suhoor|cozy,fairy,glowing
- Courtyard Lanterns|desert,lanterns,glowing
- Emerald & Gold|jade,ribbons,ornate
- Arabesque Garden|garden,vined,flutter
- Lantern Market|paper,bunting,bulbs
- Night Sky Prayer|celestial,starlights,starry
- Soft Rosewater|rose,ribbons,petalfall
- Silver Moon|elegant,double,fairy
- Zellige Pattern|indigo,ornate,starry
- Palm Oasis|tropical,vine,leafy
- Dreamy Dawn|dreamy,fairy,cloudy
- Folk Textile|folk,chain,wreathed
- Storybook Night|storybook,vined,flutter
- Lilac Evening|lilac,fairy,sparkly

@eidfitr|Eid al-Fitr|🕌|holiday|true
blurb: Joy, gratitude and shared feasts at the end of Ramadan, for those who celebrate Eid al-Fitr.
note: Celebrates the end of Ramadan. Dates depend on moon sighting and can differ by a day or two.
garland: 🌙,⭐,🕌,🎈,🍬,🌸,✨
corner: 🌙,🕌,⭐,🍬,🌸,🎈
hangers: 🌙,⭐,🎈,🏮,✨,🍬
furniture: 🍬,🎁,🕌,🍵,🌸,🎈
icons: 🌙,🕌,⭐,🍬,🎈
acc: 🌙,⭐,🎈,🌸
amb: chimes,birds,harp
greet: Eid Mubarak|Wishing you joy and gratitude|Peace and blessings to you
greetEs: Eid Mubarak|Alegría y gratitud para ti
defaults: bunting,fairy,hairline,sparkles,cluster
- Festive Crescent|sacred,bunting,sparkly
- Morning Prayer Light|sunset,hairline,cloudy
- Family Feast|market,swag,candles
- Sweets & Gifts|sweet,beads,clustered
- Golden Celebration|golden,tinsel,sparkly
- Garden Gathering|garden,vine,flutter
- Soft Pastel Eid|pastel,pompoms,petalfall
- Lantern Lights|lantern,lanterns,glowing
- Henna Patterns|rose,scroll,ornate
- Jade & Gold|jade,ribbons,hairline
- Balloon Joy|whimsical,bunting,confettied
- Starlit Night|celestial,starlights,starry
- Cozy Home|cozy,candles,calm
- Silver Elegance|elegant,double,fairy
- Courtyard Fountain|teal,vine,bubbly
- Minimal Moon|minimal,hairline,calm
- Folk Embroidery|folk,chain,wreathed
- Storybook Celebration|storybook,vined,flutter
- Indigo Evening|indigo,starlights,starry
- Dreamy Mist|dreamy,fairy,bokehy
- Kawaii Eid|kawaii,pompoms,hearty
- Blossom Courtyard|blossom,vine,petalfall
- Amber Lanterns|amber,lanterns,embers
- Lilac Dusk|lilac,fairy,sparkly
- Desert Dawn|desert,swag,cloudy

@eidadha|Eid al-Adha|🐑|holiday|true
blurb: Generosity, sacrifice remembered and shared meals, for those who celebrate Eid al-Adha.
note: Honours the Hajj pilgrimage and the spirit of giving. Dates depend on moon sighting.
garland: 🌙,⭐,🕌,🕋,🤲,🌿,✨
corner: 🌙,🕌,⭐,🕋,🌿,✨
hangers: 🌙,⭐,🏮,✨,🌿,🕯️
furniture: 🕌,🍵,🕋,🌿,🎁,🕯️
icons: 🌙,🕌,🕋,⭐,🌿
acc: 🌙,⭐,🌿,🕌
amb: chimes,wind,pad
greet: Eid Mubarak|Wishing you a blessed Eid|Peace and generosity to you
greetEs: Eid Mubarak|Un Eid bendecido para ti
defaults: emoji,fairy,hairline,stars,lantern
- Blessed Morning|sacred,hairline,cloudy
- Shared Meal|market,swag,candles
- Desert Dawn|desert,swag,cloudy
- Golden Generosity|golden,tinsel,sparkly
- Olive Branch|moss,vine,leafy
- Soft Pastel Eid|pastel,pompoms,sparkly
- Lantern Courtyard|lantern,lanterns,glowing
- Geometric Pattern|teal,ornate,hairline
- Jade Garden|jade,vine,flutter
- Cozy Family Home|cozy,candles,calm
- Starlit Night|celestial,starlights,starry
- Minimal Crescent|minimal,hairline,calm
- Silver Moon|elegant,double,fairy
- Folk Textile|folk,chain,wreathed
- Storybook Journey|storybook,vined,flutter
- Indigo Sky|indigo,starlights,starry
- Rose Gift|rose,ribbons,hearty
- Amber Lamps|amber,lanterns,embers
- Dreamy Peace|dreamy,fairy,bokehy
- Oasis Palms|tropical,vine,leafy
- Sunrise Prayer|sunset,swag,cloudy
- Blossom Garden|blossom,vine,petalfall
- Lilac Evening|lilac,fairy,sparkly
- Kawaii Gifts|kawaii,pompoms,hearty
- Midnight Quiet|midnight,starlights,starry

@hanukkah|Hanukkah|🕎|holiday|true
blurb: Eight nights of candlelight, dreidels and gratitude, for those who celebrate Hanukkah.
note: Begins at sundown on the first night. Dates follow the Hebrew calendar.
garland: 🕎,⭐,🕯️,✨,🪙,💙,🍩
corner: 🕎,🕯️,⭐,🪙,🍩,💙
hangers: ⭐,🕯️,✨,💙,🪙,🕎
furniture: 🕎,🕯️,🪙,🍩,🎁,💙
icons: 🕎,🕯️,⭐,🪙,🍩
acc: 🕎,⭐,💙,🕯️
amb: fire,chimes,musicbox
greet: Happy Hanukkah|Wishing you eight nights of light|Chag Hanukkah sameach
greetEs: Feliz Hanuká|Ocho noches de luz para ti
defaults: swag,candles,hairline,sparkles,cluster
- Eight Nights|indigo,candles,sparkly
- Menorah Glow|golden,candles,glowing
- Dreidel Game|bold,bunting,confettied
- Blue & Silver|frost,tinsel,snowing
- Latke Kitchen|cafe,scallops,bubbly
- Gelt & Gold|amber,beads,clustered
- Window Candles|village,windowed,calm
- Soft Pastel Lights|pastel,pompoms,sparkly
- Cozy Family Night|cozy,fairy,glowing
- Starlit Sky|celestial,starlights,starry
- Midnight Blue|midnight,starlights,starry
- Silver Elegance|elegant,double,fairy
- Minimal Menorah|minimal,hairline,calm
- Folk Papercut|folk,chain,wreathed
- Storybook Miracle|storybook,vined,flutter
- Teal Reflections|teal,hairline,bubbly
- Rose Candlelight|rose,candles,hearty
- Dreamy Glow|dreamy,fairy,bokehy
- Retro Dreidel|retro,bulbs,confettied
- Jade & Gold|jade,ribbons,hairline
- Lilac Evening|lilac,fairy,sparkly
- Kawaii Dreidels|kawaii,pompoms,hearty
- Vintage Tin Toys|vintage,scroll,dotted
- Sacred Light|sacred,hairline,calm
- Winter Village|workshop,windowed,snowing

@kwanzaa|Kwanzaa|🕯️|holiday|false
blurb: Seven days honouring heritage, community and the seven principles, for those who celebrate Kwanzaa.
note: Celebrated December 26 to January 1 with the kinara, mishumaa saba and Nguzo Saba. Colours follow the red, black and green of the Bendera.
garland: 🕯️,🌽,🍎,🌍,✨,🥁,🌾
corner: 🕯️,🌽,🥁,🌍,🍎,🌾
hangers: 🕯️,✨,🌍,🥁,🌽,⭐
furniture: 🕯️,🌽,🥁,🍎,📖,🎁
icons: 🕯️,🌽,🥁,🌍,🍎
acc: 🕯️,🌍,🥁,🌽
amb: fire,chimes,harp
greet: Happy Kwanzaa|Harambee — pulling together|Habari gani?
greetEs: Feliz Kwanzaa|Harambee — unidos
defaults: swag,candles,hairline,sparkles,cluster
- Seven Candles|bold,candles,sparkly
- Kinara Glow|ember,candles,glowing
- Harvest Table|market,swag,calm
- Umoja Unity|forest,chain,wreathed
- Golden Heritage|golden,tinsel,sparkly
- Drum Circle|harvest,bunting,confettied
- Woven Kente|folk,beads,hairline
- Soft Pastel Light|pastel,pompoms,sparkly
- Cozy Family Gathering|cozy,fairy,calm
- Starlit Night|celestial,starlights,starry
- Minimal Candles|minimal,hairline,calm
- Elegant Evening|elegant,double,fairy
- Sunrise on the Savanna|desert,hairline,cloudy
- Storybook Ancestors|storybook,vined,flutter
- Indigo Night|indigo,starlights,starry
- Teal Reflections|teal,hairline,bubbly
- Rose Warmth|rose,ribbons,hearty
- Amber Lamps|amber,lanterns,embers
- Dreamy Evening|dreamy,fairy,bokehy
- Jade Garden|jade,vine,flutter
- Moss & Clay|moss,vine,leafy
- Sunset Gathering|sunset,swag,cloudy
- Kawaii Kinara|kawaii,pompoms,hearty
- Vintage Quilt|vintage,scroll,dotted
- Garden of Principles|garden,vined,petalfall

@diademuertos|Día de los Muertos|💀|holiday|false
blurb: Marigolds, ofrendas and loving remembrance of those who came before, for those who observe Día de los Muertos.
note: A Mexican tradition of honouring loved ones who have died, observed November 1–2. Shown with warmth and respect, not as a Halloween costume.
garland: 🌼,🕯️,💀,🦋,🌺,🍞,✨
corner: 🌼,🕯️,💀,🦋,🌺,🍞
hangers: 🌼,🕯️,✨,🦋,🌺,🪅
furniture: 🕯️,🌼,🍞,💀,🌺,📸
icons: 🌼,🕯️,💀,🦋,🌺
acc: 🌼,💀,🦋,🌺
amb: chimes,night,harp
greet: Feliz Día de los Muertos|Remembering with love|Marigolds and memories to you
greetEs: Feliz Día de los Muertos|Recordando con amor
defaults: swag,candles,hairline,petals,cluster
- Marigold Ofrenda|harvest,swag,candles
- Papel Picado|bold,bunting,confettied
- Candlelit Altar|ember,candles,glowing
- Monarch Path|sunset,vine,flutter
- Golden Remembrance|golden,tinsel,sparkly
- Sugar Skull Colours|whimsical,chain,hairline
- Soft Pastel Memory|pastel,pompoms,petalfall
- Cozy Family Table|cozy,fairy,calm
- Cempasúchil Fields|garden,vine,petalfall
- Starlit Night|celestial,starlights,starry
- Midnight Cemetery Glow|midnight,starlights,glowing
- Elegant Altar|elegant,double,fairy
- Minimal Candles|minimal,hairline,calm
- Folk Art|folk,chain,wreathed
- Storybook Ancestors|storybook,vined,flutter
- Teal Courtyard|teal,hairline,bubbly
- Rose Memory|rose,ribbons,hearty
- Amber Lamps|amber,lanterns,embers
- Dreamy Veil|dreamy,fairy,bokehy
- Jade Garden|jade,vine,leafy
- Indigo Evening|indigo,starlights,starry
- Photographs & Flowers|vintage,scroll,dotted
- Kawaii Calaveras|kawaii,pompoms,hearty
- Desert Dusk|desert,swag,cloudy
- Carnival of Colour|carnival,bulbs,confettied

@mardigras|Mardi Gras|🎭|holiday|true
blurb: Masks, beads and the last big party before Lent, for those who celebrate Mardi Gras.
garland: 🎭,⚜️,🎉,👑,🎺,🎶,✨
corner: 🎭,⚜️,👑,🎺,🎉,🎶
hangers: 🎭,⚜️,👑,✨,🎶,🎉
furniture: 🎭,🎺,👑,🍰,🎶,🎉
icons: 🎭,⚜️,👑,🎺,🎉
acc: 🎭,👑,🎩,⚜️
amb: chimes,night,musicbox
greet: Happy Mardi Gras|Laissez les bons temps rouler|Beads and brass to you
greetEs: Feliz Mardi Gras|¡Que empiece la fiesta!
defaults: beads,bulbs,hairline,confetti,cluster
- Purple, Green & Gold|carnival,beads,confettied
- Masquerade Ball|gothic,ornate,sparkly
- Second Line Parade|bold,bunting,confettied
- French Quarter Balcony|vintage,windowed,glowing
- King Cake|sweet,scallops,clustered
- Golden Beads|golden,tinsel,sparkly
- Jazz Night|midnight,starlights,starry
- Soft Pastel Parade|pastel,pompoms,sparkly
- Cozy Café du Monde|cafe,scallops,calm
- Feathers & Sequins|whimsical,ribbons,confettied
- Neon Bourbon Street|neon,bulbs,bokehy
- Elegant Masks|elegant,double,fairy
- Minimal Fleur-de-lis|minimal,hairline,calm
- Folk Costumes|folk,chain,wreathed
- Storybook Carnival|storybook,vined,flutter
- Teal Bayou|teal,hairline,bubbly
- Rose Float|rose,ribbons,hearty
- Amber Gas Lamps|amber,lanterns,embers
- Dreamy Dusk|dreamy,fairy,bokehy
- Jade Beads|jade,beads,hairline
- Indigo Night Parade|indigo,starlights,starry
- Sunset Riverboat|sunset,swag,cloudy
- Kawaii Masks|kawaii,pompoms,hearty
- Retro Floats|retro,bulbs,confettied
- Tropical Revel|tropical,vine,flutter

@carnival|Carnival|🎊|holiday|true
blurb: Colour, rhythm and costume in the days before Lent, for those who celebrate Carnival.
note: Celebrated in many places in different ways, such as Brazil, the Caribbean, Venice and Cologne. Shown generally rather than as one country's costume.
garland: 🎊,🥁,🎭,🪭,🌈,💃,✨
corner: 🥁,🎭,🪭,💃,🌈,🎊
hangers: 🎈,🎊,🪭,✨,🌈,🎭
furniture: 🥁,🎭,🪭,🎶,💃,🎉
icons: 🎊,🥁,🎭,💃,🌈
acc: 🎭,🪭,🥁,🎉
amb: chimes,birds,musicbox
greet: Happy Carnival|Dance, colour and joy to you|Enjoy the rhythm
greetEs: Feliz Carnaval|Baile, color y alegría
defaults: bunting,bulbs,hairline,confetti,cluster
- Street Parade|whimsical,bunting,confettied
- Samba Drums|bold,chain,confettied
- Venetian Masks|gothic,ornate,sparkly
- Feathers & Glitter|carnival,ribbons,sparkly
- Tropical Float|tropical,vine,flutter
- Golden Sequins|golden,tinsel,sparkly
- Night Parade|midnight,starlights,starry
- Pastel Costumes|pastel,pompoms,petalfall
- Cozy Café Terrace|cafe,scallops,calm
- Neon Street Party|neon,bulbs,bokehy
- Retro Fiesta|retro,bulbs,confettied
- Elegant Masquerade|elegant,double,fairy
- Minimal Confetti|minimal,hairline,calm
- Folk Dance|folk,chain,wreathed
- Storybook Parade|storybook,vined,flutter
- Teal Waves|teal,hairline,bubbly
- Rose Petals|rose,ribbons,petalfall
- Amber Lanterns|amber,lanterns,embers
- Dreamy Confetti|dreamy,fairy,bokehy
- Jade Feathers|jade,ribbons,hairline
- Indigo Night|indigo,starlights,starry
- Sunset Beach Party|sunset,swag,cloudy
- Kawaii Carnival|kawaii,pompoms,hearty
- Paper Streamers|paper,chain,dotted
- Rainbow Sky|sky,bunting,flutter

@stpatricks|St. Patrick's Day|☘️|holiday|false
blurb: Green, clover and a bit of luck, for those who celebrate St. Patrick's Day or Irish heritage.
garland: ☘️,🌈,🍀,🎩,🪙,🎶,✨
corner: ☘️,🍀,🌈,🪙,🎩,🎶
hangers: ☘️,🍀,🌈,🪙,✨,🎩
furniture: 🍀,🎩,🪙,🍺,🌈,🎶
icons: ☘️,🍀,🌈,🪙,🎩
acc: 🎩,☘️,🌈,🍀
amb: stream,birds,harp
greet: Happy St. Patrick's Day|Luck of the Irish to you|May your day be green and gentle
greetEs: Feliz Día de San Patricio|Que la suerte te acompañe
defaults: vine,fairy,hairline,sparkles,cluster
- Lucky Clover|garden,vine,sparkly
- Rainbow's End|whimsical,bunting,flutter
- Emerald Hills|forest,vine,cloudy
- Pot of Gold|golden,tinsel,sparkly
- Irish Pub Glow|amber,lanterns,glowing
- Soft Pastel Green|pastel,pompoms,petalfall
- Cozy Cottage|cozy,candles,calm
- Celtic Knots|jade,scroll,ornate
- Shamrock Meadow|moss,vine,leafy
- Kawaii Clovers|kawaii,pompoms,hearty
- Misty Morning|monsoon,hairline,cloudy
- Folk Fiddle|folk,chain,wreathed
- Retro Parade|retro,bulbs,confettied
- Elegant Emerald|elegant,double,fairy
- Minimal Clover|minimal,hairline,calm
- Storybook Leprechaun|storybook,vined,flutter
- Teal Loch|teal,hairline,bubbly
- Rose & Green|rose,ribbons,hearty
- Midnight Fireflies|midnight,starlights,glowing
- Dreamy Meadow|dreamy,fairy,bokehy
- Spring Rain|sky,swag,raining
- Sunset Over Fields|sunset,swag,cloudy
- Indigo Night|indigo,starlights,starry
- Paper Shamrocks|paper,chain,dotted
- Vintage Postcard|vintage,scroll,dotted

@pride|Pride Month|🏳️‍🌈|awareness|false
blurb: Colour, community and being yourself, for everyone who celebrates Pride.
note: Includes many flags and identities. Use Flag Studio for your own flags and add them anywhere.
garland: 🏳️‍🌈,💖,🌈,✨,🦄,🌸,🏳️‍⚧️
corner: 🌈,💖,🦄,🌸,✨,🏳️‍🌈
hangers: 🌈,💖,🎈,✨,🦄,🌸
furniture: 🌈,🦄,💖,🌸,🎈,🎶
icons: 🏳️‍🌈,🌈,💖,🦄,🏳️‍⚧️
acc: 🌈,🎀,🦄,✨
amb: birds,chimes,stream
greet: Happy Pride|You belong here|Be proud, be you
greetEs: Feliz Orgullo|Aquí perteneces
defaults: bunting,fairy,hairline,confetti,cluster
- Rainbow Parade|whimsical,bunting,confettied
- Prism Light|celestial,starlights,sparkly
- Pastel Pride|pastel,pompoms,petalfall
- Bold Colours|bold,chain,confettied
- Garden of Everyone|garden,vine,flutter
- Kawaii Pride|kawaii,pompoms,hearty
- Neon Night Out|neon,bulbs,bokehy
- Soft Watercolor|watercolor,ribbons,sparkly
- Cozy Community Centre|cozy,candles,calm
- Golden Hour March|golden,tinsel,sparkly
- Midnight Dance Floor|midnight,starlights,starry
- Retro Disco|retro,bulbs,confettied
- Minimal Stripes|minimal,hairline,calm
- Dreamy Skies|dreamy,fairy,cloudy
- Rose Quartz|rose,ribbons,hearty
- Lilac Light|lilac,fairy,sparkly
- Folk Quilt|folk,chain,wreathed
- Storybook Pride|storybook,vined,flutter
- Teal Waves|teal,hairline,bubbly
- Sunset Rally|sunset,swag,cloudy
- Paper Flags|paper,bunting,dotted
- Tropical Pride|tropical,vine,flutter
- Jade Calm|jade,hairline,calm
- Amber Glow|amber,lanterns,glowing
- Elegant Gala|elegant,double,fairy

@childrensday|Children's Day|🎏|holiday|false
blurb: Play, wonder and care for the young and the young at heart, for those who celebrate Children's Day.
note: Observed on different days around the world. Choose your region in Seasonal preferences, or set your own date.
garland: 🎏,🎈,🧸,🌈,🪁,✨,🎨
corner: 🎈,🧸,🪁,🎨,🌈,🎏
hangers: 🎈,🎏,🪁,✨,🌈,🧸
furniture: 🧸,🎨,🎈,🪁,🧩,🍭
icons: 🎏,🎈,🧸,🪁,🎨
acc: 🎈,🧸,🎀,🪁
amb: birds,musicbox,chimes
greet: Happy Children's Day|Stay curious and playful|Wishing you wonder today
greetEs: Feliz Día del Niño|Que sigas jugando y soñando
defaults: bunting,fairy,hairline,bubbles,cluster
- Carp Streamers|bold,bunting,flutter
- Balloon Party|whimsical,chain,confettied
- Playroom Blocks|workshop,chain,clustered
- Kite Day|sky,bunting,flutter
- Paint & Crayons|watercolor,pompoms,sparkly
- Storybook Corner|storybook,vined,glowing
- Pastel Nursery|pastel,pompoms,petalfall
- Kawaii Toys|kawaii,pompoms,hearty
- Cozy Blanket Fort|cozy,fairy,calm
- Candy Shop|sweet,beads,bubbly
- Garden Adventure|garden,vine,flutter
- Starry Bedtime|celestial,starlights,starry
- Midnight Lullaby|midnight,starlights,glowing
- Retro Cartoons|retro,bulbs,confettied
- Minimal Shapes|minimal,hairline,calm
- Folk Toys|folk,chain,wreathed
- Teal Pond|teal,hairline,bubbly
- Rose Dollhouse|rose,ribbons,hearty
- Dreamy Clouds|dreamy,fairy,cloudy
- Jade Forest|jade,vine,leafy
- Sunset Playground|sunset,swag,cloudy
- Paper Crafts|paper,chain,dotted
- Tropical Splash|tropical,vine,bubbly
- Lilac Dreams|lilac,fairy,sparkly
- Amber Lanterns|amber,lanterns,glowing

@earthday|Earth Day|🌍|awareness|false
blurb: Care for the planet: leaves, seedlings and quiet gratitude for the natural world.
garland: 🌍,🌱,🍃,🌻,🦋,🐝,💧
corner: 🌱,🍃,🌻,🦋,🐝,🌍
hangers: 🍃,🌱,🦋,💧,🌻,🐝
furniture: 🌱,🪴,🐝,🌻,💧,🌍
icons: 🌍,🌱,🍃,🦋,🌻
acc: 🌱,🦋,🍃,🐝
amb: stream,birds,wind
greet: Happy Earth Day|Be gentle with the planet|Grow something good today
greetEs: Feliz Día de la Tierra|Cuida el planeta hoy
defaults: vine,fairy,vine,leaves,sprig
- Seedling Morning|garden,vine,leafy
- Blue Marble|ocean,swag,cloudy
- Wildflower Meadow|floral,vine,flutter
- Forest Floor|forest,vined,glowing
- Pollinator Garden|whimsical,bunting,flutter
- Recycled Paper|paper,chain,dotted
- Soft Pastel Spring|pastel,pompoms,petalfall
- Kawaii Planet|kawaii,pompoms,hearty
- Cozy Greenhouse|cozy,candles,calm
- Mossy Stones|moss,vine,leafy
- River Stream|teal,hairline,bubbly
- Sunrise Fields|sunset,swag,cloudy
- Minimal Leaf|minimal,hairline,calm
- Folk Botanical|folk,chain,wreathed
- Storybook Woods|storybook,vined,flutter
- Rose Garden|rose,ribbons,petalfall
- Dreamy Dew|dreamy,fairy,bokehy
- Jade Valley|jade,vine,leafy
- Starry Camping Night|celestial,starlights,starry
- Midnight Fireflies|midnight,starlights,glowing
- Elegant Botanical|elegant,double,fairy
- Amber Harvest|harvest,swag,leafy
- Tropical Canopy|tropical,vine,flutter
- Desert Bloom|desert,swag,petalfall
- Rainy Window|monsoon,hairline,raining

@cherryblossom|Cherry Blossom Season|🌸|season|true
blurb: Petals drifting on a spring breeze, for anyone who loves hanami and cherry blossom season.
note: Peak bloom depends on where you live and the year, so dates are approximate.
garland: 🌸,🌷,🍡,🎋,🐦,✨,🏮
corner: 🌸,🍡,🎋,🏮,🐦,🌷
hangers: 🌸,🏮,🎋,✨,🐦,🍡
furniture: 🍡,🍵,🌸,🧺,🏮,🎋
icons: 🌸,🍡,🎋,🏮,🐦
acc: 🌸,🎀,🍡,🐦
amb: birds,stream,chimes
greet: Happy cherry blossom season|Petals are falling — take a breath|Hanami wishes to you
greetEs: Feliz temporada de cerezos|Los pétalos están cayendo
defaults: vine,fairy,hairline,petals,sprig
- Full Bloom|blossom,vine,petalfall
- Hanami Picnic|garden,swag,flutter
- Petal Storm|pastel,pompoms,petalfall
- Lantern-lit Blossoms|lantern,lanterns,glowing
- Riverside Walk|teal,hairline,bubbly
- Temple Garden|jade,vined,calm
- Tea & Dango|cafe,scallops,calm
- Moonlit Sakura|midnight,starlights,petalfall
- Dawn Over Blossoms|sunset,swag,cloudy
- Kawaii Sakura|kawaii,pompoms,hearty
- Watercolor Branches|watercolor,ribbons,sparkly
- Cozy Café Window|cozy,fairy,glowing
- Minimal Branch|minimal,hairline,calm
- Folk Paper Art|folk,chain,wreathed
- Storybook Spring|storybook,vined,flutter
- Rose Canopy|rose,ribbons,petalfall
- Dreamy Haze|dreamy,fairy,bokehy
- Lilac Wisteria|lilac,vine,petalfall
- Golden Hour Petals|golden,tinsel,sparkly
- Elegant Ink|elegant,double,fairy
- Sky Blue Morning|sky,swag,cloudy
- Bamboo & Blossom|forest,vine,leafy
- Starry Hanami|celestial,starlights,starry
- Amber Evening|amber,lanterns,embers
- Spring Rain Petals|monsoon,hairline,raining

@spring|Spring|🌷|season|false
blurb: New growth, soft rain and longer light.
garland: 🌷,🌼,🐝,🦋,🌱,🌈,🐣
corner: 🌷,🌼,🦋,🌱,🐝,🌈
hangers: 🦋,🌼,🌷,🌈,🐝,🌱
furniture: 🪴,🌷,🐝,🧺,🌼,🌱
icons: 🌷,🌼,🦋,🌱,🌈
acc: 🌷,🦋,🌼,🎀
amb: birds,stream,wind
greet: Happy spring|New growth is on its way|Soft light and new beginnings
greetEs: Feliz primavera|Nuevos comienzos
defaults: vine,fairy,hairline,petals,sprig
- Tulip Fields|garden,vine,petalfall
- Spring Showers|monsoon,hairline,raining
- Pollinator Meadow|whimsical,bunting,flutter
- Soft Pastel Morning|pastel,pompoms,sparkly
- Blossom Lane|blossom,vined,petalfall
- Mossy Woodland|moss,vine,leafy
- Dawn Chorus|sunset,swag,cloudy
- Watercolor Garden|watercolor,ribbons,sparkly
- Cozy Greenhouse|cozy,candles,calm
- Kawaii Sprouts|kawaii,pompoms,hearty
- Sky Blue Day|sky,swag,cloudy
- Rose Arbour|rose,ribbons,petalfall
- Lilac Dusk|lilac,fairy,sparkly
- Jade Pond|jade,hairline,bubbly
- Minimal Sprout|minimal,hairline,calm
- Folk Embroidery|folk,chain,wreathed
- Storybook Meadow|storybook,vined,flutter
- Dreamy Haze|dreamy,fairy,bokehy
- Teal Stream|teal,hairline,bubbly
- Golden Hour|golden,tinsel,sparkly
- Elegant Garden Party|elegant,double,fairy
- Woodland Fireflies|forest,starlights,glowing
- Paper Flowers|paper,chain,dotted
- Starry Spring Night|celestial,starlights,starry
- Tropical Bloom|tropical,vine,flutter

@summer|Summer|☀️|season|false
blurb: Long light, warm evenings and cool water.
garland: ☀️,🌻,🍉,🌊,🐚,🍦,🕶️
corner: ☀️,🌻,🍉,🐚,🌴,🍦
hangers: ☀️,🐚,🎈,🌻,🍉,🌊
furniture: 🍉,🍦,🕶️,🌴,🏖️,🧴
icons: ☀️,🌻,🍉,🌊,🍦
acc: 🕶️,🌻,🐚,🍦
amb: waves,birds,night
greet: Happy summer|Long light and slow evenings|Stay cool and kind
greetEs: Feliz verano|Largas tardes de luz
defaults: bunting,bulbs,hairline,bubbles,cluster
- Sunny Beach Day|sky,bunting,bubbly
- Sunflower Field|garden,vine,flutter
- Lemonade Stand|golden,scallops,clustered
- Seaside Boardwalk|ocean,bulbs,cloudy
- Tropical Getaway|tropical,vine,flutter
- Watermelon Picnic|sweet,beads,confettied
- Firefly Evenings|midnight,starlights,glowing
- Soft Pastel Shore|pastel,pompoms,sparkly
- Cozy Cabin Porch|cozy,lanterns,glowing
- Kawaii Ice Cream|kawaii,pompoms,hearty
- Retro Road Trip|retro,bulbs,confettied
- Sunset Pier|sunset,swag,cloudy
- Minimal Horizon|minimal,hairline,calm
- Folk Summer Fair|folk,chain,wreathed
- Storybook Lagoon|storybook,vined,flutter
- Rose Lemonade|rose,ribbons,hearty
- Dreamy Heat Haze|dreamy,fairy,bokehy
- Jade Rainforest|jade,vine,leafy
- Starry Camp Night|celestial,starlights,starry
- Desert Dusk|desert,swag,cloudy
- Teal Lake|teal,hairline,bubbly
- Paper Lanterns|paper,lanterns,glowing
- Carnival Night|carnival,bulbs,confettied
- Amber Evening|amber,lanterns,embers
- Elegant Garden Dinner|elegant,double,fairy

@autumn|Autumn|🍂|season|false
blurb: Turning leaves, woodsmoke and early dusk.
garland: 🍂,🍁,🌰,🍄,🍎,🕯️,🌾
corner: 🍂,🍁,🍄,🌰,🍎,🕯️
hangers: 🍁,🍂,🌰,🍎,🕯️,🍄
furniture: 🍎,🕯️,🍄,🧺,🍂,☕
icons: 🍂,🍁,🍄,🍎,🕯️
acc: 🧣,🍁,🧤,🍂
amb: wind,fire,night
greet: Happy autumn|Leaves are turning|Cozy evenings are here
greetEs: Feliz otoño|Las hojas están cambiando
defaults: swag,candles,hairline,leaves,cluster
- Maple Lane|sunset,swag,leafy
- Harvest Moon|harvest,vine,glowing
- Cozy Cabin|cozy,candles,calm
- Woodland Mushrooms|woodland,vine,glowing
- Golden Hour Park|golden,tinsel,leafy
- Orchard Baskets|rustic,emojis,leafy
- Pastel Autumn|pastel,pompoms,petalfall
- Kawaii Acorns|kawaii,pompoms,hearty
- Café Window|cafe,scallops,calm
- Misty Morning|monsoon,hairline,cloudy
- Midnight Woods|midnight,starlights,starry
- Elegant Fall Dinner|elegant,double,fairy
- Minimal Leaf|minimal,hairline,calm
- Folk Harvest|folk,chain,wreathed
- Storybook Woods|storybook,vined,flutter
- Rose Dusk|rose,ribbons,hearty
- Amber Lamps|amber,lanterns,embers
- Dreamy Fog|dreamy,fairy,bokehy
- Forest Floor|forest,vine,leafy
- Moss & Stone|moss,vine,leafy
- Teal Lake|teal,hairline,bubbly
- Paper Leaves|paper,chain,dotted
- Vintage Postcard|vintage,scroll,dotted
- Village Evening|village,windowed,glowing
- Starry Bonfire|celestial,starlights,embers

@winter|Winter|❄️|season|false
blurb: Quiet snow, warm windows and long nights.
garland: ❄️,⛄,🧣,☕,🕯️,🌲,⭐
corner: ❄️,⛄,🌲,🧣,🕯️,☕
hangers: ❄️,⭐,🕯️,🌲,🧣,☕
furniture: ☕,🧣,🕯️,⛄,🧤,📚
icons: ❄️,⛄,🌲,☕,🧣
acc: 🧣,🧤,⛄,🎿
amb: wind,fire,chimes
greet: Happy winter|Stay warm and soft|Quiet snow and warm light
greetEs: Feliz invierno|Calidez para los días fríos
defaults: swag,fairy,frost,snow,cluster
- First Snow|frost,swag,snowing
- Cozy Fireside|cozy,candles,embers
- Snowy Village|village,windowed,snowing
- Frosted Windows|teal,frosty,windowed
- Pine Forest|forest,vine,glowing
- Aurora Night|celestial,starlights,starry
- Pastel Winter|pastel,pompoms,sparkly
- Kawaii Snow Day|kawaii,pompoms,hearty
- Café Hot Cocoa|cafe,scallops,bubbly
- Midnight Snowfall|midnight,starlights,snowing
- Golden Lamplight|golden,tinsel,bulbs
- Minimal White|minimal,hairline,calm
- Knitted Folk|folk,chain,wreathed
- Storybook Cottage|storybook,vined,flutter
- Rose Dusk|rose,ribbons,hearty
- Amber Lanterns|amber,lanterns,embers
- Dreamy Frost|dreamy,fairy,bokehy
- Lilac Twilight|lilac,fairy,sparkly
- Moss Under Snow|moss,vine,leafy
- Elegant Silver|elegant,double,fairy
- Sunset on Ice|sunset,swag,cloudy
- Paper Snowflakes|paper,chain,dotted
- Indigo Night|indigo,starlights,starry
- Rustic Lodge|rustic,swag,wreathed
- Sky Blue Morning|sky,hairline,cloudy

@rainy|Rainy Season|☔|season|true
blurb: Soft rain on windows, puddles and the smell of wet earth, wherever the rains arrive for you.
note: The rainy season arrives at different times in different places. Your region in Seasonal preferences sets the dates.
garland: ☔,💧,🌧️,🐸,🍃,🌂,☁️
corner: ☔,💧,🐸,🍃,🌂,☁️
hangers: 💧,☔,🌂,🍃,☁️,🐸
furniture: ☔,🌂,☕,🐸,🪴,📚
icons: ☔,💧,🌧️,🐸,🌂
acc: ☔,🌂,🐸,🧥
amb: rain,storm,stream
greet: Happy rainy season|Listen to the rain|A cozy day for staying in
greetEs: Feliz temporada de lluvias|Escucha la lluvia
defaults: vine,fairy,hairline,rain,cluster
- Window Droplets|monsoon,hairline,raining
- Umbrella Street|village,windowed,raining
- Hydrangea Garden|lilac,vine,petalfall
- Frog Pond|forest,vine,bubbly
- Cozy Tea Window|cafe,candles,calm
- Puddle Reflections|teal,hairline,bubbly
- Pastel Umbrellas|pastel,pompoms,raining
- Kawaii Raincoats|kawaii,pompoms,hearty
- Misty Mountains|moss,hairline,cloudy
- Midnight Rain|midnight,starlights,raining
- Golden Lamplight|golden,tinsel,glowing
- Minimal Rain|minimal,hairline,calm
- Folk Raincloud|folk,chain,wreathed
- Storybook Storm|storybook,vined,flutter
- Rose Petal Rain|rose,ribbons,petalfall
- Amber Café Glow|amber,lanterns,glowing
- Dreamy Drizzle|dreamy,fairy,bokehy
- Jade Bamboo Rain|jade,vine,leafy
- Indigo Dusk|indigo,starlights,raining
- Sky Break|sky,swag,cloudy
- Paper Umbrellas|paper,bunting,dotted
- Elegant Greys|elegant,double,fairy
- Sunset After Rain|sunset,swag,cloudy
- Garden After Rain|garden,vine,flutter
- Firefly Wet Night|celestial,starlights,glowing

@monsoon|Monsoon Season|🌦️|season|true
blurb: Heavy warm rain, green growth and the relief after heat, wherever the monsoon reaches you.
note: Monsoon timing varies by region, such as South Asia, Southeast Asia and West Africa. Your region in Seasonal preferences sets the dates.
garland: 🌦️,🌧️,🌿,🐸,💧,🪷,🌈
corner: 🌿,🪷,🐸,💧,🌦️,🌈
hangers: 💧,🌿,🪷,🌦️,🌈,🐸
furniture: ☕,🌿,🪷,🐸,🌂,🍵
icons: 🌦️,🌧️,🌿,🪷,🌈
acc: 🌂,🪷,🐸,🌿
amb: storm,rain,stream
greet: Happy monsoon season|Let the rain arrive|Green after the rain
greetEs: Feliz temporada de monzones|Que llegue la lluvia
defaults: vine,fairy,hairline,rain,cluster
- First Rains|monsoon,hairline,raining
- Lotus Pond|jade,vine,bubbly
- Green After Rain|moss,vine,leafy
- Tea on the Veranda|cafe,candles,calm
- Thunder Night|midnight,starlights,raining
- Rainbow Break|whimsical,bunting,flutter
- Pastel Umbrellas|pastel,pompoms,raining
- Kawaii Raindrops|kawaii,pompoms,hearty
- Cozy Window Seat|cozy,fairy,glowing
- Marigold & Mist|harvest,swag,cloudy
- Golden Lamplight|golden,tinsel,glowing
- Minimal Rain|minimal,hairline,calm
- Folk Fabrics|folk,chain,wreathed
- Storybook Jungle|storybook,vined,flutter
- Rose Petal Puddles|rose,ribbons,petalfall
- Amber Evening|amber,lanterns,embers
- Dreamy Haze|dreamy,fairy,bokehy
- Forest Canopy|forest,vine,leafy
- Teal Waters|teal,hairline,bubbly
- Sky Clearing|sky,swag,cloudy
- Paper Boats|paper,chain,dotted
- Elegant Greys|elegant,double,fairy
- Sunset After Storm|sunset,swag,cloudy
- Tropical Downpour|tropical,vine,raining
- Indigo Dusk|indigo,starlights,raining
''';
