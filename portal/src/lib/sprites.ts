/** Grafiki z gry (assets/game) używane w portalu. Piksele skalujemy CSS-em (image-rendering: pixelated). */
import enemyBat from "../assets/game/enemy-bat.png";
import enemyCrab from "../assets/game/enemy-crab.png";
import enemySlime from "../assets/game/enemy-slime.png";
import jewelShield from "../assets/game/jewel-shield.png";
import jewelSpeed from "../assets/game/jewel-speed.png";
import jewelTeal from "../assets/game/jewel-teal.png";
import jewel from "../assets/game/jewel.png";
import logo from "../assets/game/logo.png";
import skin2077 from "../assets/game/skin-2077.png";
import skinDefault from "../assets/game/skin-default.png";
import skinNoir from "../assets/game/skin-noir.png";
import skinOffice from "../assets/game/skin-office.png";
import skinPromissed from "../assets/game/skin-promissed.png";
import skinRetro from "../assets/game/skin-retro.png";
import spikes from "../assets/game/spikes.png";
import star from "../assets/game/star.png";
import stellyHero from "../assets/game/stelly-hero.png";
import stellyJump from "../assets/game/stelly-jump.png";
import stellyRun from "../assets/game/stelly-run.png";

export const SPRITES = {
  logo,
  stellyHero,
  stellyRun,
  stellyJump,
  jewel,
  jewelTeal,
  jewelSpeed,
  jewelShield,
  star,
  spikes,
  enemySlime,
  enemyBat,
  enemyCrab,
};

const SKINS: { match: string; src: string }[] = [
  { match: "noir", src: skinNoir },
  { match: "office", src: skinOffice },
  { match: "2077", src: skin2077 },
  { match: "promis", src: skinPromissed },
  { match: "retro", src: skinRetro },
];

/** Obrazek skórki po nazwie z katalogu (np. „Noir Stelly”). Nieznana skórka: postać podstawowa. */
export function skinSprite(name: string | undefined | null): string {
  const lower = (name ?? "").toLowerCase();
  return SKINS.find((skin) => lower.includes(skin.match))?.src ?? skinDefault;
}

/** Skórki bez własnej grafiki rysujemy postacią podstawową z filtrem koloru. */
export function skinFilterClass(name: string | undefined | null): string {
  const lower = (name ?? "").toLowerCase();
  return lower.includes("złot") || lower.includes("zlot") ? "sprite-gold" : "";
}

const BOOSTERS: Record<string, string> = {
  tarcza: jewelShield,
  "podwójne punkty": jewelSpeed,
  "dodatkowe życie": star,
  magnes: jewelTeal,
};

/** Ikona nagrody za wyzwanie. */
export function rewardSprite(reward: { type: string; element_name: string | null; booster_type: string | null }): string {
  if (reward.type === "skórka") return skinSprite(reward.element_name);
  if (reward.type === "wzmocnienie") return boosterSprite(reward.booster_type ?? "");
  if (reward.type === "kolor" || reward.type === "akcesorium") return star;
  return jewel;
}

export function boosterSprite(type: string): string {
  return BOOSTERS[type] ?? jewel;
}
