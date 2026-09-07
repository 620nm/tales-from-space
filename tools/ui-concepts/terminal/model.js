(function () {
  'use strict';
  const initial = [
    ['host:filter', 'a', 'filter_control.disl', 'disl', '-- AIR HANDLING / FILTER CONTROL\n-- Maintenance example · not executed in this prototype\n\nlocal target_pressure = 101.3\nlocal filter_enabled = true\n\nfunction on_pressure_reading(sensor)\n    if sensor.pressure > target_pressure then\n        return { intake = false, exhaust = true }\n    end\n\n    return { intake = true, exhaust = false }\nend\n\nreturn {\n    enabled = filter_enabled,\n    on_reading = on_pressure_reading,\n}\n'],
    ['host:readme', 'a', 'readme.md', 'md', '# Engineering workstation\n\nWelcome to local storage. Files on **A:** remain with this computer.\n\n## At the start of your shift\n\n- Read the previous operator’s notes.\n- Check the air-handling record.\n- Save your changes before removing a floppy.\n\n## A note about scripts\n\nSource files are editable here. This demonstration does not execute them.\n\n> Keep a clean copy of your configuration on removable media.\n'],
    ['host:atmos', 'a', 'air_handler.atmo', 'atmo', '{\n  "label": "AIR HANDLER 02",\n  "pressure_kpa": 101.3,\n  "temperature_k": 293.15,\n  "filter": "CO2",\n  "enabled": true\n}\n'],
    ['disk:notes', 'b', 'shift_notes.md', 'md', '# The night shift\n\nThe west intake is behaving again.\n\n## Handover\n\n- Replacement filter is in the cabinet.\n- Air handler 02 is set to **101.3 kPa**.\n- Please return this disk when you are finished.\n\n— M. Reyes\n'],
    ['disk:access', 'b', 'engineering_access.pem', 'pem', '-----BEGIN FICTIONAL STATION CREDENTIAL-----\nLabel: Engineering workstation login\nHolder: M. Reyes\nDepartment: Engineering\nReference: DEMO-ENG-04\n\nFictional in-game access material.\nThis demonstration does not authenticate logins.\nNo real key or certificate is stored here.\n-----END FICTIONAL STATION CREDENTIAL-----\n'],
    ['disk:backup', 'b', 'filter_backup.disl', 'disl', '-- Known-good filter settings\nreturn {\n    enabled = true,\n    target_pressure = 101.3,\n}\n'],
    ['disk:record', 'b', 'baseline.atmo', 'atmo', '{\n  "label": "BASELINE",\n  "pressure_kpa": 101.3,\n  "temperature_k": 293.15,\n  "filter": "CO2",\n  "enabled": true\n}\n']
  ];
  const model = {
    limits: { a: { bytes: 65536, files: 16 }, b: { bytes: 737280, files: 112 }, fileBytes: 8192 },
    bytes(value) { return new TextEncoder().encode(value).length; },
    usage(side, edited) { return this.list(side).reduce((total, file) => total + this.bytes(file.name) + this.bytes(file === edited ? file.body : file.savedBody), 0); },
    state: null,
    reset(options = {}) {
      this.state = { disk: options.disk !== false, diskName: 'ENGINEERING', incarnation: 1,
        selected: options.selection || 'host:filter', serial: 0, notice: 'Local session ready.', closed: false,
        files: initial.map(([id, side, name, type, body]) => ({ id, side, name, type, body,
          savedBody: body, revision: 1, dirty: false, mode: type === 'md' ? 'preview' : type === 'atmo' ? 'custom' : 'code', diagnostic: '' })) };
      if (!this.get(this.state.selected)) this.state.selected = 'host:filter';
      const record = this.get('host:atmos');
      const data = JSON.parse(record.body);
      data.history = [101.1, 101.3, 101.2, 101.3, 101.4, 101.3, 101.2, 101.3, 101.3, 101.4, 101.3, 101.3];
      record.body = record.savedBody = JSON.stringify(data, null, 2) + '\n';
      return this.state;
    },
    list(side) { return side === 'b' && !this.state.disk ? [] : this.state.files.filter(f => f.side === side); },
    get(id = this.state.selected) { return this.state.files.find(f => f.id === id && (f.side !== 'b' || this.state.disk)); },
    change(body) { const f = this.get(); if (!f) return; f.body = body; f.dirty = f.body !== f.savedBody; f.diagnostic = ''; },
    save() {
      const f = this.get(); if (!f) return false;
      if (this.bytes(f.body) > this.limits.fileBytes) {
        f.diagnostic = 'File exceeds 8192 UTF-8 bytes. Changes are still unsaved.'; return false;
      }
      if (this.usage(f.side, f) > this.limits[f.side].bytes) {
        f.diagnostic = 'Drive capacity exceeded. Changes are still unsaved.'; return false;
      }
      if (f.type === 'atmo') {
        try { const data = JSON.parse(f.body); if (!data || typeof data !== 'object' || Array.isArray(data)) throw Error(); }
        catch (_) { f.diagnostic = 'Invalid record: expected a JSON object. Changes are still unsaved.'; return false; }
      }
      if (f.type === 'disl' && /SYNTAX_ERROR/.test(f.body)) {
        f.diagnostic = 'Simulated diagnostic: remove SYNTAX_ERROR before saving. No code was executed.'; return false;
      }
      f.savedBody = f.body; f.dirty = false; f.revision++;
      f.diagnostic = f.type === 'disl' ? 'Saved locally. Script execution is not part of this prototype.' : 'Saved locally.';
      this.state.notice = 'Saved ' + f.name + ' · revision ' + f.revision; return true;
    },
    revert() { const f = this.get(); if (f) { f.body = f.savedBody; f.dirty = false; f.diagnostic = ''; } },
    validName(side, name, except) {
      if (!/^[a-zA-Z0-9][a-zA-Z0-9 _.-]{0,47}\.(disl|md|atmo|pem)$/.test(name)) return 'Use a short filename ending in .disl, .md, .atmo, or .pem.';
      if (this.list(side).some(f => f.id !== except && f.name.toLowerCase() === name.toLowerCase())) return 'A file with that name already exists.';
      const existing = except && this.get(except);
      if (existing && this.usage(side) - this.bytes(existing.name) + this.bytes(name) > this.limits[side].bytes) return 'This drive is full.';
      return '';
    },
    create(side, name, source) {
      if (this.list(side).length >= this.limits[side].files) return 'This drive is full (' + this.limits[side].files + ' files).';
      const error = this.validName(side, name); if (error) return error;
      const type = name.split('.').pop(); const body = source ? source.savedBody : type === 'atmo' ? '{\n  "label": "NEW RECORD"\n}\n' : type === 'md' ? '# New document\n\n' : type === 'pem' ? '-----BEGIN FICTIONAL STATION CREDENTIAL-----\nLabel: New in-game login material\nDemo only; no authentication or real key.\n-----END FICTIONAL STATION CREDENTIAL-----\n' : '-- New source file\n';
      if (this.bytes(body) > this.limits.fileBytes) return 'File exceeds 8192 UTF-8 bytes.';
      if (this.usage(side) + this.bytes(name) + this.bytes(body) > this.limits[side].bytes) return 'This drive is full.';
      const f = { id: side + ':' + (++this.state.serial), side, name, type, body, savedBody: body,
        revision: 1, dirty: false, mode: type === 'md' ? 'preview' : type === 'atmo' ? 'custom' : 'code', diagnostic: '' };
      this.state.files.push(f); this.state.selected = f.id; this.state.notice = 'Created ' + name; return '';
    },
    eject() { this.state.disk = false; this.state.incarnation++; if (!this.get()) this.state.selected = 'host:filter'; this.state.notice = 'ENGINEERING ejected safely.'; },
    insert() { this.state.disk = true; this.state.incarnation++; this.state.notice = 'ENGINEERING inserted into B:.'; }
  };
  model.reset(); window.TerminalModel = model;
})();
