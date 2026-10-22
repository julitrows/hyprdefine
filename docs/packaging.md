# Packaging hyprdefine for the AUR

The package is defined in [`packaging/PKGBUILD`](../packaging/PKGBUILD). It
builds from a tagged GitHub release with `make install`, and runs `make test`
in `check()`.

## What the package does and doesn't do

pacman installs files as root and can't touch anyone's home directory, so the
work splits in two:

| The package (root, once) | `hyprdefine --setup` (each user) |
| --- | --- |
| `/usr/bin/hyprdefine` | the `-- hyprdefine` line in `~/.config/hypr/hyprland.lua` |
| `/usr/lib/hyprdefine/` (scripts, language list) | `systemctl --user enable hyprdefine.service` |
| `/usr/lib/systemd/user/hyprdefine.service` | the `~/.local/bin/define` link |
| `/usr/share/hyprdefine/` (bindings, Claude skill) | the Claude Code skill link, if `~/.claude` exists |
| docs and license | moving an omarchy-dict install over |

`packaging/hyprdefine.install` tells users to run `hyprdefine --setup` after
installing, and `--teardown` before removing.

Dependencies are all in the official repos. `dict-gcide` (offline English) is
in the AUR, so it's an optional dependency rather than a hard one; without it,
English comes from dict.org.

## Releasing a version

1. Make sure `make test` passes and the README is current.
2. Set `pkgver` in `packaging/PKGBUILD` (and reset `pkgrel=1`), commit, and
   tag:

   ```bash
   git tag -a v0.1.0 -m "hyprdefine 0.1.0"
   git push origin main v0.1.0
   ```

3. Fill in the checksum of GitHub's tarball, and regenerate `.SRCINFO`:

   ```bash
   cd packaging
   updpkgsums                         # from pacman-contrib; replaces 'SKIP'
   makepkg --printsrcinfo > .SRCINFO
   ```

4. Build it clean, which also runs the tests. `extra-x86_64-build` from
   `devtools` builds in a clean chroot, which catches missing dependencies;
   plain `makepkg` is the quick check:

   ```bash
   makepkg -f
   namcap PKGBUILD hyprdefine-*.pkg.tar.zst   # optional linting
   ```

## Publishing to the AUR

The AUR keeps each package in its own git repository. The first time:

1. Create an account at https://aur.archlinux.org and add your SSH public key
   under *My Account*.
2. Clone the (empty) package repository, which creates it:

   ```bash
   git clone ssh://aur@aur.archlinux.org/hyprdefine.git ~/aur/hyprdefine
   ```

3. Copy in the package files and push:

   ```bash
   cp packaging/PKGBUILD packaging/hyprdefine.install packaging/.SRCINFO ~/aur/hyprdefine/
   cd ~/aur/hyprdefine
   git add PKGBUILD hyprdefine.install .SRCINFO
   git commit -m "hyprdefine 0.1.0"
   git push
   ```

For each later release, repeat *Releasing a version*, copy the three files
over again, and commit with the new version. The AUR rejects pushes whose
`.SRCINFO` doesn't match the PKGBUILD, so always regenerate it.

## Trying the package before a release

Without a tag there's no GitHub tarball, so build from the working tree:

```bash
version=0.1.0
dir=$(mktemp -d)
tar --exclude=.git --transform "s|^\.|hyprdefine-$version|" -czf "$dir/hyprdefine-$version.tar.gz" .
cp packaging/PKGBUILD packaging/hyprdefine.install "$dir/"
cd "$dir"
sed -i "s|^source=.*|source=(\"hyprdefine-$version.tar.gz\")|" PKGBUILD
makepkg -f
```

`sudo pacman -U hyprdefine-*.pkg.tar.zst` then installs it. If you also have
a git checkout set up, run `hyprdefine --setup` afterwards: the keys follow
whichever install ran `--setup` last.
