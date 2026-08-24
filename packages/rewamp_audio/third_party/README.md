# third_party

Vendored decoder libraries, added as git submodules and built from source.

| Library | Submodule path | Build flag |
|---|---|---|
| libopenmpt | `libopenmpt/` | `REWAMP_WITH_OPENMPT` |

Setup:

```bash
git submodule add https://github.com/OpenMPT/openmpt.git \
  packages/rewamp_audio/third_party/libopenmpt
git submodule update --init --recursive
```

See `../PLUGINS.md` for how plugins are wired into the build per platform.
