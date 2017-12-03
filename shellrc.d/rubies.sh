# uninstall rubyies
RUBIES_HOME=$HOME/.rubies

clean_ruby(){

    RUBY_VERSION=$1
    RUBY_TO_REMOVE=$RUBIES_HOME/$RUBY_VERSION
    test -d $RUBY_TO_REMOVE && echo "$Red Removing the old rubies $Color_Off" && rm -v $RUBY_TO_REMOVE && exit 0
    echo "No such $RUBY_VERSION to clean, or check the ruby version string"
}

