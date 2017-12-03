emacs_me(){
    EMACS_I_WANT_TO_USE=${EMACS_DOCKER_IMAGE:-jare/emacs}
    BLOG_CONTENTS_INSIDE_EMACS=/home/emacs/blog_contents/
    docker run -ti --rm \
	   --name $(echo ${EMACS_I_WANT_TO_USE}|shasum |cut -d' ' -f1) \
	   -e HUGO_CONTENT_PROJECT_DIR=$BLOG_CONTENTS_INSIDE_EMACS/ \
           -e DISPLAY="unix$DISPLAY"\
           -e UNAME="emacser"\
           -e GNAME="emacsers"\
           -e UID="1000"\
           -e GID="1000"\
	   -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
           -v ~/.emacs.docker:/home/emacs/.emacs.d \
           -v ~/.gitconfig:/home/emacs/.gitconfig \
	   -v $MY_HUGO_CONTENT_PROJECT_DIR:$BLOG_CONTENTS_INSIDE_EMACS \
	   "$EMACS_I_WANT_TO_USE" emacs ${DEBUG_FLAG}
}

