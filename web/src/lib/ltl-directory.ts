/** Static LTL carrier catalog from the iOS Tarifario directory. */

export interface LtlDirectoryCarrier {
  name: string;
  services: string[];
  contact: string;
  handlesHazmat: boolean;
}

export const LTL_DIRECTORY: LtlDirectoryCarrier[] = [
  {
    name: 'Neyno',
    services: ['Puerto (Manzanillo, Altamira, Veracruz)'],
    contact: 'customerservice@transneyno.com.mx',
    handlesHazmat: false,
  },
  {
    name: 'Paquetexpress',
    services: ['Puerto (Manzanillo, Altamira)', 'Exportación', 'Importación', 'Nacional'],
    contact: 'gaquintana@pxgl.com · icepeda@paquetexpress.com.mx',
    handlesHazmat: false,
  },
  {
    name: 'Reflemsa',
    services: ['Puerto (Manzanillo, Altamira)'],
    contact: 'cotizaciones@rfm.mx',
    handlesHazmat: false,
  },
  {
    name: 'Trane',
    services: ['Puerto (Manzanillo, Altamira)', 'Exportación', 'Importación', 'Nacional'],
    contact: 'jorgec@tranetransporte.com.mx · ventasconsol@tranetransporte.com.mx',
    handlesHazmat: false,
  },
  {
    name: 'Valera',
    services: ['Puerto (Manzanillo, Altamira, Veracruz)'],
    contact: 'pricing@valera.com.mx',
    handlesHazmat: false,
  },
  {
    name: 'Fasterrama',
    services: ['Exportación Nacional', 'Importación Nacional', 'Nacional'],
    contact: 'informacion@fasterrama.com · quotes@fasterrama.com',
    handlesHazmat: false,
  },
  {
    name: 'Rawill',
    services: ['Exportación Nacional', 'Importación Nacional', 'Nacional'],
    contact: 'informacion@rawill.com.mx',
    handlesHazmat: false,
  },
  {
    name: 'XCF',
    services: ['Exportación Nacional', 'Importación Nacional', 'Nacional'],
    contact: 'cotizacionesmtm@xcf.com.mx',
    handlesHazmat: false,
  },
  {
    name: 'Quick Express',
    services: ['Exportación', 'Importación', 'Nacional', 'Intra USA'],
    contact: 'am@quick-ex.net · info@quick-ex.net',
    handlesHazmat: true,
  },
  {
    name: 'CALOP',
    services: ['Exportación Intra USA', 'Importación Intra USA', 'Intra USA'],
    contact: 'cserna@cfs3pl.com',
    handlesHazmat: false,
  },
  {
    name: 'GLT',
    services: ['Exportación Intra USA', 'Importación Intra USA', 'Intra USA'],
    contact: 'rfuenmayor@goglt.com',
    handlesHazmat: false,
  },
  {
    name: 'UTB',
    services: ['Exportación Intra USA', 'Importación Intra USA', 'Intra USA'],
    contact: 'pricing@utblogistics.com',
    handlesHazmat: false,
  },
  {
    name: 'Master Logistics',
    services: ['Intra USA'],
    contact: 'No proporcionado',
    handlesHazmat: false,
  },
];
