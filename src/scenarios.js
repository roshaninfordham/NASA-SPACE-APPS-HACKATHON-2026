/** Scenario inputs are illustrative unless explicitly marked NASA measured. */
export const SCIENCE = Object.freeze({
  backgroundDosePerDay: 0.67, // mSv/day, Curiosity RAD; historical observation, not a forecast
  reference:
    "https://www.nasa.gov/news-release/nasa-rover-results-include-first-age-measurement-on-mars-and-help-for-human-exploration/",
});
export const SCENARIOS = Object.freeze([
  {
    id: "first-light",
    name: "First light",
    subtitle: "Learn to read the storm",
    duration: 12,
    peakTau: 2.8,
    eventStart: 4,
    eventEnd: 7,
    eventDose: 1.8,
    initialEnergy: 8,
    deposition: 0.035,
  },
  {
    id: "long-shadow",
    name: "Long shadow",
    subtitle: "Less reserve. A later warning.",
    duration: 12,
    peakTau: 3.4,
    eventStart: 6,
    eventEnd: 9,
    eventDose: 2.1,
    initialEnergy: 6.8,
    deposition: 0.04,
  },
  {
    id: "red-front",
    name: "Red front",
    subtitle: "Heavy dust. Narrow margins.",
    duration: 12,
    peakTau: 3.8,
    eventStart: 3,
    eventEnd: 6.5,
    eventDose: 1.9,
    initialEnergy: 7,
    deposition: 0.055,
  },
]);
export const SYSTEM = Object.freeze({
  suitCapacity: 0.9,
  suitLifeSupportKW: 0.12,
  visorCleaningKW: 0.04,
  visorCleaningRate: 0.6,
  returnHours: 0.15,
  inspectionHours: 1.5,
  capacity: 12,
  essentialKW: 0.55,
  normalKW: 0.75,
  conserveKW: 0.12,
  cleaningKW: 0.9,
  cleaningRate: 0.25,
  arrayKW: 4.8,
  shelterFactor: 0.15,
  doseLimit: 4,
  recoveryKWh: 2.4,
  hoursPerSecond: 0.05,
  stepHours: 1 / 120,
});
