emacs_me(){
    EMACS_I_WANT_TO_USE=${EMACS_DOCKER_IMAGE:-jare/emacs}
    EMACS_HOME=/home/emacs
    BLOG_CONTENTS_INSIDE_EMACS=$EMACS_HOME/blog_contents/
    docker run -ti --rm \
	   --name $(echo ${EMACS_I_WANT_TO_USE}|shasum |cut -d' ' -f1) \
	   -e HUGO_CONTENT_PROJECT_DIR=$BLOG_CONTENTS_INSIDE_EMACS/ \
           -e DISPLAY="unix$DISPLAY"\
           -e UNAME="emacser"\
           -e GNAME="emacsers"\
           -e UID="1000"\
           -e GID="1000"\
	   -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
           -v ~/.emacs.docker:$EMACS_HOME/.emacs.d \
           -v ~/.gitconfig:/$EMACS_HOME/.gitconfig \
	   -v ~/.ssh/id_rsa:$EMACS_HOME/.ssh/id_rsa:ro \
	   -v $MY_HUGO_CONTENT_PROJECT_DIR:$BLOG_CONTENTS_INSIDE_EMACS \
	   "$EMACS_I_WANT_TO_USE" emacs ${DEBUG_FLAG}
}

