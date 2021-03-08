# Docker build hooks

## arch.yaml

Parameters required to build an image for any particular architecture.

Generally if the source image we're using has been built with the system the `arch.yaml` from the source image should remain compatible and usable. If we don't want to build all the architectures we built for our source image in a downstream image then `EXCLUDED_ARCHES` can be set in `repo.conf` (as an alternative to editing the `arch.yaml` and removing the architecture).

## repo.conf

This is sourced very near the top of `hooks/env` (i.e. as early as possibly in the build proceess), so any config that needs to be done early on can be done directly here.

Various functions allow more config to be done at later stages of the build process.

### Strings/Integers

* `SOURCE_REPO`			- *Required* The `<repo>/<image>` we're building from.
* `ARCH_KEYS`			- *Required* The keys in the `arch.yaml` file to use (this may be unnecessary, no real harm in reading all keys, but the code requires it to be set for now).
* `CACHE_EXPIRY`		- The time, in seconds, that cached manifests and API data will remain valid.
* `SOURCE_ARCH_PREFIX`	- Set (to anything) if the source repo is in the `<arch>/<image>` form, if unset default is `<image>-<host>`.
* `EXCLUDED_ARCHES`			- Archiectures that should not be built, even if an appropriate source and config (in `arch.yaml`) arch exist.

### Arrays

These are specified with the variable name as the key and a description as the value.

* `BUILD_ARGS`			- Environment variables to be provided to `docker build` as a `--build-arg`.
* `CHECKOUT_DISPLAY`	- Environment variables to be eachoed as the end of `hooks/post_checkout`.

### Functions

These functions exist to allow default script behaviour to be modified. They are not strictly required and can be omitted entirely if the default behaviour is adequate.

* `env_end()`				- For general config, called at the end of `hooks/env`.
* `post_checkout_end()`		- For general config, called at the end of `hooks/post_checkout`.
* `get_from_image()`		- `echo` the full `<repo>/<image>:<tag>` to use for the Dockerfile `FROM` statement.
* `get_target_tag()`		- `echo` the target image's `<tag>`
* `get_source_tag()`		- `echo` the source image's `<tag>`
* `get_base_tags()`			- `echo` additional targets tags to create as a single-arch `<tag>-<arch>`. Used by `hooks/push`.
* `get_manifest_tags()`		- `echo` additional targets to create as a multi-arch `<tag>` manifest. Used by `hooks/post_push`.

### Example
```
SOURCE_REPO='alpine'
S6_REPO="just-containers/s6-overlay"  # custom for this specific image, not used
                                      # or required by anything in 'hooks/'

ARCH_KEYS='TARGET_ARCH_TAG EXTRA_ARCH_TAGS QEMU_ARCH S6_ARCH QEMU_PREFIX DOCKER_FILE'
EXCLUDED_ARCHES='s390x'

CACHE_EXPIRY=14400

SOURCE_ARCH_PREFIX=true

declare -A BUILD_ARGS=( \
  [S6_ARCH]='S6 arch' \
  [S6_VERSION]='S6 version' \
  [ALPINE_VERSION]='Alpine version' \
)

declare -A CHECKOUT_DISPLAY=( ) # none

# custom for this specific image, not used or required by anything in 'hooks/'
get_major_latest () {
  [ -z "${MAJOR_LATEST+set}" ] \
    && echo "$(docker_api_tag_names "${SOURCE_REPO}" | grep "${ALPINE_VERSION%.*}" | sort -uV | tail -n1)" \
    || echo "${MAJOR_LATEST}"
}

## get the source tag
get_source_tag () {  echo "${TARGET_TAG}";  }

## run at the end of env
env_end () {
  true # do nothing
}

## run at the end of post_checkout
post_checkout_end () {
  add_print_param "${TARGET_TAG}" 'ALPINE_VERSION' 'Alpine target'
  add_print_param "$(docker_api_latest "library/${SOURCE_REPO}")" 'SOURCE_LATEST' 'Alpine latest'
  add_print_param "$(get_major_latest)" 'MAJOR_LATEST' 'Alpine major latest'
  add_print_param "$(git_latest_release "${S6_REPO}")" 'S6_VERSION' 'S6 latest'
}

## return extra tags to add during push
get_base_tags () {
  extra_tags=()

  # no extra base tags to add

  echo "${extra_tags[@]}"
}
  

## return extra tags to add during post_push
get_manifest_tags () {
  extra_tags=()

  # shellcheck disable=SC2053
  [[ "${TARGET_TAG}" = "$(get_major_latest)" ]] && extra_tags+=("${TARGET_TAG%.*}")

  [ "${TARGET_TAG}" = "${SOURCE_LATEST}" ] && extra_tags+=('latest')
  echo "${extra_tags[@]}"
}
```
