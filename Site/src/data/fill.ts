import { Builder, Preset } from "xeerpe";

const css = (style: Record<string, string>) =>
  Object.entries(style)
    .map(([k, v]) => `${k.replace(/[A-Z]/g, (m) => "-" + m.toLowerCase())}: ${v}`)
    .join("; ");

/** Inline CSS that fills text with a preset of the xeerpe npm library. */
export const textFill = (preset: string) => css(new Preset(preset).toTextStyle());

/** Inline CSS that paints a background with a preset of the xeerpe npm library. */
export const surface = (preset: string) => css(new Preset(preset).toStyle());

/** Brushed steel with one sharp band of light, three times as wide as the text so the band can travel across it. */
export const metalFill = css(
  new Builder()
    .linearGradient({
      angle: "105deg",
      colors: [
        { color: "#5d646c", position: "0%" },
        { color: "#8f979f", position: "38%" },
        { color: "#d9dee3", position: "46%" },
        { color: "#ffffff", position: "50%" },
        { color: "#d9dee3", position: "54%" },
        { color: "#8f979f", position: "62%" },
        { color: "#5d646c", position: "100%" },
      ],
      backgroundSize: "300% 100%",
    })
    .toTextStyle(),
);
