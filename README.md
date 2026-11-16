# QuantEcon Actions

Composite GitHub Actions, workflow templates and container images that build, preview and publish QuantEcon's lecture sites. One weekly cache build executes every lecture, so pull-request and publish builds re-execute only the lectures that changed.

The actions are built for QuantEcon's lecture repositories, and are on 0.x, where a minor release can change what an action does. Using them elsewhere is fine, but unsupported. Releases are listed in the [CHANGELOG](CHANGELOG.md) and on the [releases page](https://github.com/QuantEcon/actions/releases); `@v0` follows the latest.

## Documentation

**The [user manual](docs/user/README.md)** covers using the actions. Its [index](docs/user/README.md#actions) lists every action, each has a chapter with every input and output, and a step uses one as `quantecon/actions/<action>@v0`. These guides cover the rest:

- [Getting started](docs/user/getting-started.md): setting up a lecture repository with the [workflow templates](templates/), and moving an existing one onto the actions.
- [How the actions compose](docs/user/composition.md): the chain from the cache build to a preview or publish.
- [Containers](docs/user/containers.md): the two images, `ghcr.io/quantecon/quantecon` and `ghcr.io/quantecon/quantecon-build`.
- [Versioning](docs/user/versioning.md): `@v0` against an exact release.
- [Security](docs/user/security.md): fork pull requests, secrets, and what each job can reach.

**The [developer docs](docs/dev/README.md)** cover how the project is designed, tested and maintained, and the work plan.

## Who uses them

The lecture repositories that use these actions are tracked in [QuantEcon/meta#321](https://github.com/QuantEcon/meta/issues/321), and the versions they pin in the [work plan](docs/dev/PLAN.md#consumers-in-production).

## Standalone actions

QuantEcon's actions outside the lecture pipeline each live in a repository of their own, as [ARCHITECTURE.md](docs/dev/ARCHITECTURE.md#which-actions-live-here) describes. This table is the place to find QuantEcon's actions, and each repository's README is the reference for its inputs.

| Action | What it does | Ref consumers use | Maintainer | Test consumer | Main consumers |
|---|---|---|---|---|---|
| [action-translation](https://github.com/QuantEcon/action-translation) | Translates the lectures a merged pull request changed and opens a pull request in each translated edition, reviews those pull requests, and rebases the open ones when one merges | `@v0` | [mmcky](https://github.com/mmcky) | [test-translation-sync](https://github.com/QuantEcon/test-translation-sync), with its `.zh-cn`, `.fa` and `.ml` targets | Sync: lecture-python-intro, lecture-python.myst, lecture-python-programming. Review and rebase: lecture-intro.zh-cn, lecture-python.zh-cn, lecture-python-programming.{fa,fr,ja,ml,zh-cn} |
| [action-style-guide](https://github.com/QuantEcon/action-style-guide) | Checks a lecture against QuantEcon's style guide when an issue comment names it | `@v0.7.3` | [mmcky](https://github.com/mmcky) | [test-action-style-guide](https://github.com/QuantEcon/test-action-style-guide) | lecture-python-advanced.myst |
| [action-link-checker](https://github.com/QuantEcon/action-link-checker) | Checks the links in a built site's HTML, and suggests a fix for each broken or redirected one | `@v1` | [mmcky](https://github.com/mmcky) | Its own CI, on the fixtures in its `tests/` | lecture-python-intro, lecture-python-advanced.myst, lecture-python-programming, continuous_time_mcs (at `@v1.2.0`) |

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) covers the development workflow, testing a change from a lecture repository, and the release steps, including the staged release and moving `v0`.

## License

MIT: see [LICENSE](LICENSE).

## Support

Open an issue in this repository. To report a security vulnerability, follow [SECURITY.md](SECURITY.md) instead.
