import { MEXICAN_ZONES } from '@/lib/models';

export interface MexicoMapZone {
  id: string;
  shortLabel: string;
  color: string;
  compact: boolean;
  states: readonly string[];
  polygon: ReadonlyArray<readonly [number, number]>;
  anchor: readonly [number, number];
}

const GEOMETRY: Record<
  string,
  Omit<MexicoMapZone, 'id' | 'states'>
> = {
  Noroeste: {
    shortLabel: 'Noroeste',
    color: '#2E85CC',
    compact: false,
    anchor: [0.12, 0.25],
    polygon: [
      [0, 0],
      [0.27, 0.03],
      [0.27, 0.35],
      [0.31, 0.52],
      [0.25, 0.63],
      [0.13, 0.65],
      [0.05, 0.58],
      [0, 0.44],
    ],
  },
  Norte: {
    shortLabel: 'Norte',
    color: '#40997A',
    compact: false,
    anchor: [0.62, 0.22],
    polygon: [
      [0.27, 0.03],
      [1, 0.14],
      [0.9, 0.44],
      [0.65, 0.5],
      [0.47, 0.52],
      [0.31, 0.52],
      [0.27, 0.35],
    ],
  },
  Bajío: {
    shortLabel: 'Bajío',
    color: '#C29426',
    compact: true,
    anchor: [0.44, 0.57],
    polygon: [
      [0.31, 0.52],
      [0.47, 0.52],
      [0.65, 0.5],
      [0.63, 0.62],
      [0.46, 0.68],
      [0.34, 0.66],
      [0.25, 0.63],
    ],
  },
  'Centro Occidente': {
    shortLabel: 'C. Occ.',
    color: '#C74D38',
    compact: true,
    anchor: [0.22, 0.74],
    polygon: [
      [0.13, 0.65],
      [0.25, 0.63],
      [0.34, 0.66],
      [0.34, 0.8],
      [0.22, 0.86],
      [0.1, 0.8],
    ],
  },
  Centro: {
    shortLabel: 'Centro',
    color: '#7542B8',
    compact: true,
    anchor: [0.43, 0.74],
    polygon: [
      [0.34, 0.66],
      [0.46, 0.68],
      [0.58, 0.73],
      [0.48, 0.8],
      [0.38, 0.84],
      [0.34, 0.8],
    ],
  },
  Sur: {
    shortLabel: 'Sur',
    color: '#33996B',
    compact: false,
    anchor: [0.29, 0.88],
    polygon: [
      [0.1, 0.8],
      [0.22, 0.86],
      [0.34, 0.8],
      [0.38, 0.84],
      [0.48, 0.8],
      [0.52, 0.9],
      [0.44, 0.98],
      [0.22, 0.98],
      [0.1, 0.9],
    ],
  },
  Sureste: {
    shortLabel: 'Sureste',
    color: '#D16B29',
    compact: false,
    anchor: [0.8, 0.72],
    polygon: [
      [0.46, 0.68],
      [0.63, 0.62],
      [0.65, 0.5],
      [0.9, 0.44],
      [1, 0.14],
      [1, 0.84],
      [0.88, 0.95],
      [0.7, 1],
      [0.55, 1],
      [0.52, 0.9],
      [0.48, 0.8],
      [0.58, 0.73],
    ],
  },
};

export const MEXICO_MAP_ZONES: MexicoMapZone[] = MEXICAN_ZONES.map((zone) => {
  const geometry = GEOMETRY[zone.id];
  if (!geometry) {
    throw new Error(`Zona sin mapa: ${zone.id}`);
  }
  return { id: zone.id, states: zone.states, ...geometry };
});

export interface UsaMapZone {
  id: string;
  shortLabel: string;
  keyStates: string;
  color: string;
  states: readonly string[];
}

/** Same groups and order as iOS USAZone. */
export const USA_MAP_ZONES: UsaMapZone[] = [
  {
    id: 'Pacífico',
    shortLabel: 'Pacífico',
    keyStates: 'CA · OR · WA',
    color: '#2685D1',
    states: ['WA', 'OR', 'CA', 'AK', 'HI'],
  },
  {
    id: 'Montaña Rocosa',
    shortLabel: 'Montaña',
    keyStates: 'CO · AZ · NV',
    color: '#389461',
    states: ['MT', 'ID', 'WY', 'CO', 'UT', 'NV', 'AZ', 'NM'],
  },
  {
    id: 'Medio Oeste',
    shortLabel: 'Medio Oeste',
    keyStates: 'IL · OH · MI',
    color: '#C28C1F',
    states: ['MN', 'WI', 'MI', 'OH', 'IN', 'IL', 'IA', 'MO', 'ND', 'SD', 'NE', 'KS'],
  },
  {
    id: 'Sur Central',
    shortLabel: 'Sur Central',
    keyStates: 'TX · OK · LA',
    color: '#D1472E',
    states: ['TX', 'OK', 'AR', 'LA'],
  },
  {
    id: 'Sureste EE.UU.',
    shortLabel: 'Sureste',
    keyStates: 'FL · GA · NC',
    color: '#2E998C',
    states: ['TN', 'KY', 'VA', 'WV', 'NC', 'SC', 'GA', 'FL', 'AL', 'MS'],
  },
  {
    id: 'Noreste EE.UU.',
    shortLabel: 'Noreste',
    keyStates: 'NY · PA · MA',
    color: '#8047BF',
    states: ['ME', 'VT', 'NH', 'MA', 'RI', 'CT', 'NY', 'NJ', 'PA', 'DE', 'MD', 'DC'],
  },
];

export type ZoneLevel = 'none' | 'partial' | 'full';

export function zoneLevel(states: readonly string[], selected: Set<string>): ZoneLevel {
  const count = states.filter((state) => selected.has(state)).length;
  if (count === 0) return 'none';
  if (count === states.length) return 'full';
  return 'partial';
}

export function polygonPoints(
  polygon: ReadonlyArray<readonly [number, number]>,
  width = 142,
  height = 100,
): string {
  return polygon
    .map(([x, y]) => `${(x * width).toFixed(2)},${(y * height).toFixed(2)}`)
    .join(' ');
}
