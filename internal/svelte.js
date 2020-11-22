const fs = require("fs");
const path = require("path");

const [
  input,
  output_basename,
] = process.argv.slice(2);

const svelte = require("svelte/compiler");

const source = fs.readFileSync(input, "utf8");

const {
  js: dom_js,
  css: dom_css,
  warnings: dom_warnings,

  vars: dom_vars
} = svelte.compile(source, {
  format: "esm",
  generate: "dom",
  hydratable: true,
  css: false,
  outputFilename: path.basename(`${output_basename}.dom`),
  cssOutputFilename: path.basename(`${output_basename}.dom.css`),
  filename: `${output_basename}.dom.mjs`,
});

if (dom_css.code) {
  if (dom_css.map) {
    const dom_css_source_map_comment = `/*# sourceMappingURL=${dom_css.map.toUrl()} */`;
    dom_css.code += `\n${dom_css_source_map_comment}`;
  }
  dom_js.code += `\nimport "./${path.basename(output_basename)}.dom.css";\n`;
}

fs.writeFileSync(`${output_basename}.dom.mjs`, dom_js.code);
fs.writeFileSync(`${output_basename}.dom.mjs.map`, dom_js.map.toString());
fs.writeFileSync(`${output_basename}.dom.css`, dom_css.code ? dom_css.code : '');

fs.writeFileSync(`${output_basename}.dom.d.ts`, `
/// <reference lib="dom" />

interface DOMComponentConstructorOptions<InitProps> {
  target: HTMLElement;         // An HTMLElement to render to. This option is required.
  anchor?: HTMLElement | null; // Default null; A child of target to render the component immediately before.
  props?: InitProps;           // Default {};	An object of properties to supply to the component.
  hydrate?: boolean;           // Default false
  intro?: boolean;             // Default false; If true, will play transitions on initial render, rather than waiting for subsequent state changes.
}
interface DOMComponentConstructor<InitProps, SetProps> {
  new(options: DOMComponentConstructorOptions<InitProps>): DOMComponent<SetProps>;

  ${dom_vars.filter(({module}) => module).map(({export_name}) =>
    `${export_name}: unknown;`
  ).join("\n")}
}

interface DOMComponent<SetProps> {
  $set: (data: Partial<SetProps>) => void;
  $destroy: () => void;
}

const component: DOMComponentConstructor<{
  ${dom_vars.filter(({module, }) => !module).map(({export_name}) =>
    `${export_name}?: unknown;`
  ).join("\n")}
}, {
  ${dom_vars.filter(({ module, writable }) => !module && writable).map(({ export_name }) =>
    `${export_name}?: unknown;`
  ).join("\n")}
}>

export default component
`)

const {
  js: ssr_js,
  css: ssr_css,
  warnings: ssr_warnings,
  vars: ssr_vars,
} = svelte.compile(source, {
  format: "esm",
  generate: "ssr",
  hydratable: true,
  css: false,
  outputFilename: path.basename(`${output_basename}.ssr`),
  filename: `${output_basename}.ssr.mjs`,
});


fs.writeFileSync(`${output_basename}.ssr.mjs`, ssr_js.code);
fs.writeFileSync(`${output_basename}.ssr.mjs.map`, ssr_js.map.toString());

fs.writeFileSync(`${output_basename}.ssr.d.ts`, `
interface SSRComponent<Props> {
  render(props?: Props): {
    head: string;
    html: string;
    css: string;
  }
}

const component: SSRComponent<{
  ${ssr_vars.filter(({ module }) => !module).map(({ export_name }) =>
    `${export_name}?: unknown;`
  ).join("\n")}
}>

export default component
`)