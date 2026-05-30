# Compatibility glue for BlueBuild's justfiles module on Fedora base images.
# The module appends custom recipes to /usr/share/ublue-os/just/60-custom.just,
# while blujust reads /usr/share/bluebuild/justfiles/60-custom.just.
import "/usr/share/bluebuild/justfiles/30-secureboot.just"
import? "/usr/share/ublue-os/just/60-custom.just"
