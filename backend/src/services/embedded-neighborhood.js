const { createHash } = require('node:crypto');
const { Types } = require('mongoose');

function embeddedNeighborhoodId(sectorId, neighborhood, index) {
  const seed = `${sectorId}:${neighborhood.pk_colonia ?? index}:${neighborhood.nombre ?? ''}`;
  const hex = createHash('md5').update(seed).digest('hex').slice(0, 24);
  return new Types.ObjectId(hex);
}

module.exports = { embeddedNeighborhoodId };
