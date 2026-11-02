// Script D-Engine (JS). 'game' es la API: game.on(evento, fn), game.say(texto), game.health
game.on('onBeat', b => { if (b % 16 === 0 && b > 0) game.say('Beat ' + b + '!'); });
game.on('onNoteHit', (n, rating) => { if (rating === 'sick') game.health += 0.005; });
