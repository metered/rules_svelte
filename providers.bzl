load("@build_bazel_rules_nodejs//:providers.bzl", _JSEcmaScriptModuleInfo = "JSEcmaScriptModuleInfo")

SvelteComponentInfo = provider(
    doc = """Svelte files.
""",
    fields = {
        "direct_sources": "Depset of direct Svelte, JavaScript files and sourcemaps",
        "sources": "Depset of direct and transitive Svelte, JavaScript files and sourcemaps",
    },
)

def svelte_component_info(sources, deps = []):
    """Constructs a SvelteComponentInfo including all transitive sources from SvelteComponentInfo providers in a list of deps.
Returns a single SvelteComponentInfo.
"""
    transitive_depsets = [sources]
    for dep in deps:
        if SvelteComponentInfo in dep:
            transitive_depsets.append(dep[SvelteComponentInfo].sources)
        elif _JSEcmaScriptModuleInfo in dep:
            transitive_depsets.append(dep[_JSEcmaScriptModuleInfo].sources)

    return SvelteComponentInfo(
        direct_sources = sources,
        sources = depset(transitive = transitive_depsets),
    )
