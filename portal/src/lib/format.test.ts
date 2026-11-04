import { describe, expect, it } from "vitest";
import { formatConditions, formatRemaining, formatReward, validatePassword } from "./format";

describe("formatReward", () => {
  it("opisuje każdy typ nagrody", () => {
    expect(formatReward({ type: "klejnoty", gems: 50, element_name: null, booster_type: null })).toBe("50 klejnotów");
    expect(formatReward({ type: "skórka", gems: null, element_name: "Złoty", booster_type: null })).toBe("Skórka: Złoty");
    expect(formatReward({ type: "wzmocnienie", gems: null, element_name: null, booster_type: "tarcza" })).toBe(
      "Wzmocnienie: tarcza",
    );
  });
});

describe("formatConditions", () => {
  it("tłumaczy znane warunki i nie ukrywa nieznanych", () => {
    expect(formatConditions({ min_wynik: 500, nowy_warunek: 3 })).toEqual([
      "Zdobądź co najmniej 500 punktów",
      "nowy_warunek: 3",
    ]);
  });
});

describe("formatRemaining", () => {
  const now = new Date("2026-11-07T12:00:00Z");
  it("pokazuje największą sensowną jednostkę", () => {
    expect(formatRemaining("2026-11-10T12:00:00Z", now)).toBe("Pozostało: 3 d");
    expect(formatRemaining("2026-11-07T15:00:00Z", now)).toBe("Pozostało: 3 godz.");
    expect(formatRemaining("2026-11-07T12:30:00Z", now)).toBe("Pozostało: 30 min");
    expect(formatRemaining("2026-11-07T11:00:00Z", now)).toBe("Czas minął");
  });
});

describe("validatePassword", () => {
  it("stosuje te same zasady co API", () => {
    expect(validatePassword("Tajne1234")).toBeNull();
    expect(validatePassword("Krótk1")).not.toBeNull();
    expect(validatePassword("samelitery")).not.toBeNull();
    expect(validatePassword("12345678")).not.toBeNull();
  });
});
