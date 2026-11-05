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

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) covers the development workflow, testing a change from a lecture repository, and the release steps, including the staged release and moving `v0`.

## License

MIT: see [LICENSE](LICENSE).

## Support

Open an issue in this repository. To report a security vulnerability, follow [SECURITY.md](SECURITY.md) instead.
