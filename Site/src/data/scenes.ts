import scenes from "../../public/frames/scenes.json";

export interface Caption {
  /** Scroll progress of the scene, 0...1, at which the caption is fully shown. */
  at: number;
  text: string;
}

export interface Chapter {
  scene: keyof typeof scenes;
  title: string;
  captions: Caption[];
  code: string;
}

export const sceneInfo = (id: keyof typeof scenes) => scenes[id];

export const chapters: Chapter[] = [
  {
    scene: "card",
    title: "Turn it in your hand.",
    captions: [
      { at: 0.2, text: "A card from the catalog, a glare and a 3D tilt." },
      { at: 0.65, text: "The light follows the phone. On a Mac, the pointer." },
    ],
    code: `card.xeerpe(.card(.holographic, .tilt, angle: 22))`,
  },
  {
    scene: "aurora",
    title: "Let it flow.",
    captions: [
      { at: 0.2, text: "Surfaces are Metal shaders, not pictures." },
      { at: 0.65, text: "A finger on the view pulls the flow toward it." },
    ],
    code: `view.xeerpe(.aurora())`,
  },
  {
    scene: "pond",
    title: "Touch the surface.",
    captions: [
      { at: 0.2, text: "Each tap sends a wave through the water." },
      { at: 0.65, text: "The wave bends the content too: text, images, controls." },
    ],
    code: `view.xeerpe(.pond())`,
  },
  {
    scene: "reveal",
    title: "Pour it in.",
    captions: [
      { at: 0.25, text: "A reveal driven by any value you own." },
      { at: 0.7, text: "Here the value is how far you scrolled." },
    ],
    code: `view.xeerpe(.fluidReveal(progress: .binding($progress)))`,
  },
];
