// Fictional local fixtures: action capabilities are explicit, independent of held tools.
(() => {
  const fixtures = [
    ['apc', 3, 4, 'Area power controller', 'Distributes power to this room.'],
    ['apc', 3, 6, 'Area power controller', 'Lighting circuit enabled.'],
    ['apc', 3, 8, 'Area power controller', 'Equipment circuit enabled.'],
    ['door_eng_open', 10, 12, 'Engineering airlock', 'Open. Engineering access required.'],
    ['canister', 16, 4, 'Gas canister', 'A portable pressurized vessel.'],
    ['canister', 17, 4, 'Gas canister', 'Outlet valve: closed.'],
    ['vent_off', 4, 10, 'Air vent', 'Connected to the distribution network.'],
    ['scrubber_off_s', 16, 10, 'Air scrubber', 'Filters unwanted gases from the room.'],
    ['toolbox', 7, 5, 'Toolbox', 'A metal case for tools.', 'portable'],
    ['metal', 8, 5, 'Metal sheets', 'A stack of construction material.', 'portable'],
    ['glass', 8, 6, 'Glass sheets', 'Handle with care.', 'portable'],
    ['pipe_dispenser', 14, 5, 'Pipe dispenser', 'Fabricates pipe fittings.'],
    ['pipe_meter', 9, 5, 'Air sensor', 'Measures the local atmosphere.'],
    ['operating_computer', 14, 7, 'Monitoring terminal', 'Connected to local instruments.'],
    ['laptop_on', 6, 8, 'Laptop', 'The atmospheric monitor is open.', 'laptop'],
    ['wrench', 7, 6, 'Wrench', 'A sturdy adjustable wrench.', 'portable'],
    ['crowbar', 6, 6, 'Crowbar', 'Useful for prying panels open.', 'portable'],
  ].map(([sprite, x, y, title, line, kind = 'fixture']) => ({
    key: `${x},${y}`, sprite, x, y, title, kind, lines: [line], closed: false,
  }));
  fixtures.find(item => item.key === '9,5').lines.push('Pressure: 101.3 kPa · Temperature: 293.2 K');
  for (const y of [7, 8, 9]) {
    fixtures.push({key: `grille:16,${y}`, sprite: 'grille', x: 16, y, title: 'Grille', kind: 'fixture', lines: ['A rigid metal grille.']});
    fixtures.push({key: `window:16,${y}`, sprite: 'window', x: 16, y, title: 'Window', kind: 'fixture', lines: ['A pane of reinforced station glass.']});
  }
  const service = [];
  for (const y of [6, 7, 8]) service.push({key: y === 7 ? 'overlap:pipe1' : `pipe1:12,${y}`,
    sprite: 'pipe_l1_3', x: 12, y, title: 'Distribution pipe · layer 1', tint: '#6bb8e5', layer: 1});
  for (const x of [11, 12, 13]) service.push({key: x === 12 ? 'overlap:pipe3' : `pipe3:${x},7`,
    sprite: 'pipe_l3_12', x, y: 7, title: 'Return pipe · layer 3', tint: '#e4b268', layer: 3});
  for (const x of [11, 12, 13]) service.push({key: x === 12 ? 'overlap:cable' : `cable:${x},7`,
    sprite: 'cable_l1_12', x, y: 7, title: 'Power cable · layer 1', tint: '#ed5555', layer: 1});
  service.forEach(item => Object.assign(item, {kind: 'fixture', lines: [
    item.key.includes('cable') ? 'An exposed power cable, drawn above the pipes.' : `An exposed atmospheric pipe on layer ${item.layer}.`,
    'Fixed in place. This local study offers inspection only.',
  ]}));
  function tileSprite(x, y) {
    const room = x >= 2 && x <= 18 && y >= 2 && y <= 12;
    if ((room && (x === 2 || x === 18 || y === 2 || (y === 12 && x !== 10)))
      || y === 16 || (y === -2 && x !== 10)) return 'wall';
    if ((x === -2 || x === 22) && y !== 6 && y < 12) return 'reinforced_wall';
    if ((x === 0 || x === 20) && y >= 5 && y <= 9) return 'grille';
    if (x >= 11 && x <= 13 && y >= 6 && y <= 8) return 'plating';
    return (x < 0 || x > 20) && y < 12 ? 'plating' : 'floor';
  }
  window.ConceptSceneData = {fixtures, service, tileSprite};
})();
