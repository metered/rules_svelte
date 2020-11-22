load("@build_bazel_rules_nodejs//:providers.bzl", "declaration_info", "LinkablePackageInfo", "js_ecma_script_module_info")
load("//:providers.bzl", "svelte_component_info")

def _svelte_library_impl(ctx):
  outputs = []
  declarations = []

  for src in ctx.files.srcs:
    if ctx.attr.strip_prefix and src.short_path.startswith(ctx.attr.strip_prefix):
      subpath = src.short_path[len(ctx.attr.strip_prefix):]
    else:
      if src.owner and src.owner != ctx.label:
        if src.owner.package + '/' + src.owner.name != src.path:
          subpath = src.short_path[len(src.owner.package)+len(src.owner.name)+2:]
        else:
          subpath = src.short_path[len(src.owner.package)+1:]
      else:
        subpath = src.path[len(ctx.label.package)+1:]

    if src.path.endswith(".svelte"):
      out_ssr_mjs = ctx.actions.declare_file(subpath + ".ssr.mjs")
      out_ssr_dts = ctx.actions.declare_file(subpath + ".ssr.d.ts")
      out_dom_dts = ctx.actions.declare_file(subpath + ".dom.d.ts")

      declarations.append(out_ssr_dts)
      declarations.append(out_dom_dts)

      these_outs = [
        out_ssr_mjs,
        out_ssr_dts,
        ctx.actions.declare_file(subpath + ".ssr.mjs.map"),
        ctx.actions.declare_file(subpath + ".dom.mjs"),
        out_dom_dts,
        ctx.actions.declare_file(subpath + ".dom.mjs.map"),
        ctx.actions.declare_file(subpath + ".dom.css"),
      ]
      outputs.extend(these_outs)
      args = ctx.actions.args()
      args.add(src.path)
      args.add(out_ssr_mjs.path[:-8])

      ctx.actions.run(
        mnemonic = "Svelte",
        executable = ctx.executable._svelte,
        outputs = these_outs,
        inputs = [src],
        arguments = [args],
      )
    else:
      out = ctx.actions.declare_file(subpath)
      these_outs = [out]
      outputs.extend(these_outs)
      args = ctx.actions.args()
      args.add(src.path)
      args.add(out.path)

      ctx.actions.run_shell(
        mnemonic = "Copy",
        outputs = these_outs,
        inputs = [src],
        command = 'cp "$1" "$2"',
        arguments = [args],
      )

  package_name = ctx.attr.module_name or (ctx.workspace_name + '/' + ctx.label.package)

  sci = svelte_component_info(depset(outputs), ctx.attr.deps)
  files = depset(outputs, transitive = [sci.sources])

  path = "/".join([p for p in [ctx.bin_dir.path, ctx.label.workspace_root, ctx.label.package] if p])

  providers = [
    DefaultInfo(files = files),
    sci,
    js_ecma_script_module_info(depset(outputs), ctx.attr.deps),
    declaration_info(depset(declarations), deps = ctx.attr.deps),
    LinkablePackageInfo(
      package_name = package_name,
      path = path,
      files = depset(outputs),
    ),
  ]

  return providers

_svelte_library = rule(
  implementation = _svelte_library_impl,
  attrs = {
    "module_name": attr.string(),
    "srcs": attr.label_list(
      allow_files = True,
    ),
    "strip_prefix": attr.string(),
    "deps": attr.label_list(),
    "_svelte": attr.label(
          default=Label("//internal:svelte"),
          executable=True,
          cfg="host"),
  }
)

# TODO consider emitting .ts files and a ts_library
def svelte_library(name, package_name=None, **kwargs):
  _svelte_library(
    name = name,
    module_name = package_name, # or ("metered/" + native.package_name()),
    **kwargs,
  )