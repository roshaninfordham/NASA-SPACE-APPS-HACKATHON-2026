/** Scenario inputs are illustrative unless explicitly marked NASA measured. */
import observations from "../data/nasa-observations.json" with { type: "json" };
const radiation = observations.observations.find(
  (record) => record.id === "curiosity-rad-2012-2013-mean",
);
const opacity = observations.observations.find(
  (record) => record.id === "opportunity-2018-reported-opacity",
);
export const SCIENCE = Object.freeze({
  backgroundDosePerDay: radiation.value,
  reference: radiation.sourceUrl,
  stormPeakTau: opacity.value,
  stormReference: opacity.sourceUrl,
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
    subtitle: "A sky as dusty as Opportunity’s in 2018.",
    duration: 12,
    peakTau: SCIENCE.stormPeakTau - 0.25,
    eventStart: 3,
    eventEnd: 6.5,
    eventDose: 1.9,
    initialEnergy: 10.5,
    deposition: 0.055,
  },
]);
export const SYSTEM = Object.freeze({
  suitCapacity: 0.9,
  suitLifeSupportKW: 0.12,
  visorCleaningKW: 0.04,
  visorCleaningRate: 0.6,
  returnHours: 0.15,
  inspectionHours: 2.5,
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
