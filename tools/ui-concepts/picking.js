// Pure inverse-source picking, shared by the trusted local scene and its checks.
(() => {
  function opaqueAt(primitive, x, y) {
    const {raster, width, height} = primitive;
    if (!raster || width <= 0 || height <= 0 || !Number.isFinite(x + y)) return false;
    const sx = Math.floor((x - primitive.x) * raster.width / width);
    const sy = Math.floor((y - primitive.y) * raster.height / height);
    return sx >= 0 && sy >= 0 && sx < raster.width && sy < raster.height
      && raster.alpha[sy * raster.width + sx] > 0;
  }
  function pick(primitives, x, y) {
    for (let index = primitives.length - 1; index >= 0; index--)
      if (opaqueAt(primitives[index], x, y)) return primitives[index];
    return null;
  }
  window.ConceptPicking = {opaqueAt, pick};
})();
