import {
  MEXICAN_ZONES,
  US_STATES,
  type AppUser,
  type CarrierRoute,
  type EquipmentType,
} from '@/lib/models';

const US_SET = new Set<string>(US_STATES);

function isUSState(state: string): boolean {
  return US_SET.has(state);
}

function zoneForState(state: string): string | null {
  const zone = MEXICAN_ZONES.find((z) => (z.states as readonly string[]).includes(state));
  return zone?.id ?? null;
}

function routeMatches(
  route: CarrierRoute,
  originState: string,
  destinationState: string,
  equipmentType: EquipmentType,
): boolean {
  let stateMatch = false;
  if (route.originState === originState && route.destinationState === destinationState) {
    stateMatch = true;
  } else if (
    route.bidirectional &&
    route.originState === destinationState &&
    route.destinationState === originState
  ) {
    stateMatch = true;
  }
  if (!stateMatch) return false;
  return route.equipmentTypes.length === 0 || route.equipmentTypes.includes(equipmentType);
}

/** Mirrors iOS AppUser.coversLoad. */
export function coversLoad(
  user: AppUser,
  originCity: string,
  originState: string,
  destinationCity: string,
  destinationState: string,
  equipmentType: EquipmentType,
): boolean {
  const originIsUSA = isUSState(originState);
  const destIsUSA = isUSState(destinationState);
  const coverageUSAStates = user.coverageUSAStates ?? [];

  if (originIsUSA || destIsUSA) {
    if (!user.coversUSA) return false;

    if (originIsUSA && destIsUSA) {
      if (coverageUSAStates.length === 0) return true;
      return (
        coverageUSAStates.includes(originState) && coverageUSAStates.includes(destinationState)
      );
    }

    const usaState = originIsUSA ? originState : destinationState;
    if (coverageUSAStates.length > 0 && !coverageUSAStates.includes(usaState)) {
      return false;
    }
    if (user.routes.length > 0) {
      return user.routes.some((r) =>
        routeMatches(r, originState, destinationState, equipmentType),
      );
    }
    return true;
  }

  if (user.routes.length > 0) {
    return user.routes.some((r) =>
      routeMatches(r, originState, destinationState, equipmentType),
    );
  }

  const isSameState = originState === destinationState;
  if (isSameState) {
    const citiesKnown = originCity.length > 0 && destinationCity.length > 0;
    const isSameCity =
      citiesKnown && originCity.toLowerCase() === destinationCity.toLowerCase();
    return isSameCity ? Boolean(user.handlesLocal) : Boolean(user.handlesIntraState);
  }

  if (user.coverageStates.length > 0) {
    if (
      !user.coverageStates.includes(originState) ||
      !user.coverageStates.includes(destinationState)
    ) {
      return false;
    }
    return (
      user.coverageEquipmentTypes.length === 0 ||
      user.coverageEquipmentTypes.includes(equipmentType)
    );
  }

  if (user.coverageZones.length > 0) {
    const originZone = zoneForState(originState);
    const destZone = zoneForState(destinationState);
    const coversOrigin = originZone ? user.coverageZones.includes(originZone) : false;
    const coversDest = destZone ? user.coverageZones.includes(destZone) : false;
    if (!coversOrigin && !coversDest) return false;
    return (
      user.coverageEquipmentTypes.length === 0 ||
      user.coverageEquipmentTypes.includes(equipmentType)
    );
  }

  return true;
}
