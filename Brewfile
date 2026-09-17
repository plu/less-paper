brew "docker"
brew "docker-compose"
# Beside imagemagick rather than in mise.toml: the two are counterparts - imagemagick frames the
# screenshots, ffmpeg conforms the preview recording - and mise only offers ffmpeg through conda,
# which pins its whole transitive graph across seven platforms and takes mise.lock from 578 lines
# to 4443 for the one binary. Six of those platforms this repository will never build on.
brew "ffmpeg"
brew "imagemagick"
