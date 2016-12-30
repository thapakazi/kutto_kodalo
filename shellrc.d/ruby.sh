# this make little difference rae
export JRUBY_OPTS='-J-Xcompile.invokedynamic=true -J-XX:+TieredCompilation -J-XX:TieredStopAtLevel=1 -J-noverify -Xcompile.mode=OFF'
