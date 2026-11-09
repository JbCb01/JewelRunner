import { beforeEach, describe, expect, it } from "vitest";
import { clearRankingCache, loadRanking, saveRanking } from "./rankingCache";

describe("rankingCache", () => {
  beforeEach(() => localStorage.clear());

  it("zapamiętuje i czyści ranking", () => {
    const ranking = { items: [], me: null, generated_at: "2026-11-07T12:00:00Z" };
    saveRanking(ranking);
    expect(loadRanking()).toEqual(ranking);
    clearRankingCache();
    expect(loadRanking()).toBeNull();
  });

  it("ignoruje uszkodzone dane", () => {
    localStorage.setItem("jr_ranking", "{uszkodzone");
    expect(loadRanking()).toBeNull();
  });
});
