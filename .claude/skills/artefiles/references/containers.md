# containers: Colima, docker, buildx, lazydocker (macOS)

Docker Desktop is not allowed (`dotfiles_doctor` flags it); Colima runs the
containers instead.

- `colima start` starts the Linux VM that runs containers
  (`colima start --cpu 4 --memory 8` for more resources); `colima stop`,
  `colima status`.
- `docker` CLI works as usual once Colima runs (`docker ps`, `docker run`).
  Its completion loads on the first `docker` command.
- buildx (`docker-buildx`): `docker buildx build .`; Homebrew's docker CLI lacks it, so a script
  links the plugin into `~/.docker/cli-plugins/`. `docker buildx version`
  checks it.
- lazydocker: `lazydocker` is a terminal UI for containers, images, logs and
  volumes; the bottom bar lists the keys.
- Something fails: `scripts/containers-status.sh` checks Colima, docker,
  buildx and Docker Desktop and says what to run.
